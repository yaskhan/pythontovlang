// build.v — Build infrastructure for mypy
// Facilities to analyze entire programs, including imported modules
// Status: In progress (beginning of transpilation)

module mypy

// Import dependencies (will be populated as we add functionality)
import os
import time
import json

// ===== Constants =====

pub const debug_fine_grained = false

pub const core_builtin_modules = {
	'builtins':          true
	'typing':            true
	'types':             true
	'typing_extensions': true
	'mypy_extensions':   true
	'_typeshed':         true
	'_collections_abc':  true
	'collections':       true
	'collections.abc':   true
	'sys':               true
	'abc':               true
}

pub const max_gc_freeze_cycles = 1

pub const module_resolution_url = 'https://mypy.readthedocs.io/en/stable/running_mypy.html#mapping-file-paths-to-modules'

// ===== Import priorities =====

pub const pri_high = 5 // top-level "from X import blah"
pub const pri_med = 10 // top-level "import X"
pub const pri_low = 20 // either form inside a function
pub const pri_mypy = 25 // inside "if MYPY" or "if TYPE_CHECKING"
pub const pri_indirect = 30 // an indirect dependency
pub const pri_all = 99 // include all priorities

// ===== Cache constants =====

pub const deps_meta_file = '@deps.meta.json'
pub const deps_root_file = '@root.deps.json'
pub const fake_root_module = '@root'
pub const plugin_snapshot_file = '@plugins_snapshot.json'
pub const errors_file_suffix = '.err'

// ===== IPC message tags =====

pub const ack_message_tag = 101
pub const scc_request_message_tag = 102
pub const scc_response_message_tag = 103
pub const sources_data_message_tag = 104
pub const sccs_data_message_tag = 105
pub const graph_message_tag = 106

// ===== Graph type =====

pub type Graph = map[string]&State

pub struct State {
pub mut:
	id             string
	manager        &BuildManager = unsafe { nil }
	tree           ?&MypyFile
	dependencies   []string
	priorities     map[string]int
	trans_dep_hash []u8
	options        &Options = unsafe { nil }
}

pub struct BuildManager {
pub mut:
	errors                &Errors           = unsafe { nil }
	options               &Options          = unsafe { nil }
	semantic_analyzer     &SemanticAnalyzer = unsafe { nil }
	incomplete_namespaces map[string]bool
	processed_targets     [][]string
	// fg_manager &FineGrainedBuildManager
}

// ===== SuppressionReason =====

pub struct SuppressionReason {
pub:
	not_found int = 1
	skipped   int = 2
}

// ===== ModuleNotFound exception =====

pub struct ModuleNotFound {
pub:
	reason int
}

pub fn ModuleNotFound.new(reason int) ModuleNotFound {
	return ModuleNotFound{
		reason: reason
	}
}

// ===== SCC (Strongly Connected Component) =====

pub struct SCC {
pub mut:
	id                int
	mod_ids           []string
	deps              []int
	not_ready_deps    []int
	direct_dependents []int
	size_hint         int
}

pub fn SCC.new(mod_ids []string, scc_id int, deps []int) SCC {
	mut id := scc_id
	if id == -1 {
		id = 0
	}
	return SCC{
		id:      id
		mod_ids: mod_ids
		deps:    deps
	}
}

// ===== BuildResult =====

pub struct BuildResult {
pub mut:
	manager    BuildManager
	graph      Graph
	files      map[string]MypyFile
	types      map[string]MypyTypeNode
	used_cache bool
	errors     []string
}

// ===== FgDepMeta =====

pub struct FgDepMeta {
pub:
	path  string
	mtime int
}

// ===== ModuleNotFoundReason =====

pub enum ModuleNotFoundReason {
	not_found
	found_without_type_hints
	wrong_working_directory
	approved_stubs_not_installed
}

// ===== FindModuleCache =====

// Forward declaration for FindModuleCache
pub struct FindModuleCache {
pub mut:
	results map[string]string
}

pub type ModuleSearchResult = string | ModuleNotFoundReason

// ===== Graph utilities =====

pub fn graph_vertices(graph Graph) []string {
	return graph.keys()
}

pub fn graph_edges(graph Graph, vertices []string, id string, pri_max int) []string {
	mut filtered := []string{}
	if id !in vertices {
		return filtered
	}
	st := graph[id] or { return filtered }
	for dep in st.dependencies {
		if dep in vertices {
			pri := st.priorities[dep] or { pri_high }
			if pri < pri_max {
				filtered << dep
			}
		}
	}
	return filtered
}

// ===== Strongly Connected Components (SCC) =====

// Tarjan's algorithm for finding SCCs
pub fn strongly_connected_components(vertices []string, edges map[string][]string) [][]string {
	mut scc_ctx := SCCContext{
		index:    0
		stack:    []string{}
		on_stack: map[string]bool{}
		indices:  map[string]int{}
		lowlinks: map[string]int{}
		sccs:     [][]string{}
	}

	for v in vertices {
		if v !in scc_ctx.indices {
			scc_ctx.strong_connect(v, edges)
		}
	}
	return scc_ctx.sccs
}

// SCCContext holds state for Tarjan's algorithm
struct SCCContext {
pub mut:
	index    int
	stack    []string
	on_stack map[string]bool
	indices  map[string]int
	lowlinks map[string]int
	sccs     [][]string
}

fn (mut ctx SCCContext) strong_connect(v string, edges map[string][]string) {
	ctx.indices[v] = ctx.index
	ctx.lowlinks[v] = ctx.index
	ctx.index++
	ctx.stack << v
	ctx.on_stack[v] = true

	for w in edges[v] or { []string{} } {
		if w !in ctx.indices {
			ctx.strong_connect(w, edges)
			ctx.lowlinks[v] = if ctx.lowlinks[w] < ctx.lowlinks[v] {
				ctx.lowlinks[w]
			} else {
				ctx.lowlinks[v]
			}
		} else if ctx.on_stack[w] or { false } {
			ctx.lowlinks[v] = if ctx.indices[w] < ctx.lowlinks[v] {
				ctx.indices[w]
			} else {
				ctx.lowlinks[v]
			}
		}
	}

	if ctx.lowlinks[v] == ctx.indices[v] {
		mut scc := []string{}
		for {
			w := ctx.stack.pop()
			ctx.on_stack[w] = false
			scc << w
			if w == v {
				break
			}
		}
		ctx.sccs << scc
	}
}

// ===== Topological sort =====

pub fn topsort(deps map[string][]string) []string {
	mut in_degree := map[string]int{}
	mut result := []string{}
	mut queue := []string{}

	// Initialize in-degrees
	for node in deps.keys() {
		if node !in in_degree {
			in_degree[node] = 0
		}
		for dep in deps[node] or { []string{} } {
			in_degree[dep] = (in_degree[dep] or { 0 }) + 1
		}
	}

	// Find nodes with no incoming edges
	for node, degree in in_degree {
		if degree == 0 {
			queue << node
		}
	}

	// Process queue
	for queue.len > 0 {
		node := queue.pop()
		result << node
		for dep in deps[node] or { []string{} } {
			in_degree[dep] = (in_degree[dep] or { 1 }) - 1
			if in_degree[dep] == 0 {
				queue << dep
			}
		}
	}

	return result
}

// ===== Transitive dependency hash =====

pub fn transitive_dep_hash(scc SCC, graph Graph) []u8 {
	mut all_direct_deps := []string{}
	for id in scc.mod_ids {
		st := graph[id] or { continue }
		for dep in st.dependencies {
			pri := st.priorities[dep] or { pri_high }
			if pri != pri_indirect {
				if dep !in all_direct_deps {
					all_direct_deps << dep
				}
			}
		}
	}
	// Sort for stability
	all_direct_deps.sort()

	mut buf := []u8{}
	for dep_id in all_direct_deps {
		// Write dependency id
		buf << dep_id.bytes()
		if dep_id !in scc.mod_ids {
			dep_st := graph[dep_id] or { continue }
			buf << dep_st.trans_dep_hash
		}
	}
	return buf
}

// ===== Cache utilities =====

pub fn get_errors_name(meta_name string) string {
	mut parts := meta_name.split('.')
	if parts.len >= 3 {
		parts[1] = 'err'
		return parts.join('.')
	}
	return meta_name + errors_file_suffix
}

pub fn compute_hash(text string) string {
	return hash_digest(text.bytes())
}

pub fn hash_digest(data []u8) string {
	// Simple hash - in production this would be a proper hash
	return data.hex()
}

pub fn hash_digest_bytes(data []u8) []u8 {
	// Return raw bytes of hash
	return data
}

// ===== File system utilities =====

pub fn is_sub_path_normabs(path string, base string) bool {
	// Check if path is under base
	normalized_path := os.abs_path(path)
	normalized_base := os.abs_path(base)
	return normalized_path.starts_with(normalized_base)
}

pub fn os_path_join(parts ...string) string {
	return os.join_path(...parts)
}

// ===== JSON utilities =====

pub fn json_dumps(data map[string]string) []u8 {
	// Simplified JSON serialization
	return json.encode(data).bytes()
}

pub fn json_loads(data []u8) ?map[string]string {
	// Simplified JSON deserialization
	return json.decode(map[string]string, data.bytestr()) or { return none }
}

// ===== Time utilities =====

pub fn time_ref() f64 {
	return f64(time.now().unix_milli()) / 1000.0
}

pub fn time_spent_us(start f64) int {
	return int((time_ref() - start) * 1_000_000)
}
