// I, Antigravity, am working on this file. Started: 2026-03-22 05:00
module mypy

// Main loop of semantic analysis.
// Translation: mypy/semanal_main.py → vlangtr/mypy/semanal_main.v

pub const max_iterations = 20
pub const core_warmup = 2
pub const core_modules = [
	'typing',
	'_collections_abc',
	'builtins',
	'abc',
	'collections',
	'collections.abc',
]

pub struct PatchEntry {
pub:
	priority int
	callback fn ()
}

pub type Patches = []PatchEntry

pub type TargetNode = MypyFile | FuncDef | OverloadedFuncDef | Decorator

pub struct TargetInfo {
pub:
	fullname    string
	node        TargetNode
	active_type ?&TypeInfo
}

pub struct FullTargetInfo {
pub:
	module      string
	fullname    string
	node        TargetNode
	active_type ?&TypeInfo
}

pub fn semantic_analysis_for_scc(graph &Graph, scc []string, errors &Errors) {
	mut patches := Patches{}
	process_top_levels(graph, scc, mut patches)
	process_functions(graph, scc, mut patches)
	apply_semantic_analyzer_patches(patches)
	// apply_class_plugin_hooks(graph, scc, errors)
	// check_type_arguments(graph, scc, errors)
	calculate_class_properties_scc(graph, scc, errors)
}

fn process_top_levels(graph &Graph, scc []string, mut patches Patches) {
	mut scc_rev := scc.clone()
	scc_rev.reverse_in_place()

	first_state := graph[scc_rev[0]] or { return }

	for id in scc_rev {
		state := graph[id] or { continue }
		if tree := state.tree {
			state.manager.semantic_analyzer.prepare_file(tree)
		}
	}

	for id in scc_rev {
		first_state.manager.incomplete_namespaces[id] = true
	}

	mut worklist := scc_rev.clone()
	mut iteration := 0
	mut final_iteration := false
	analyzer := first_state.manager.semantic_analyzer

	for worklist.len > 0 {
		iteration++
		if iteration > max_iterations {
			analyzer.report_hang()
			break
		}

		if final_iteration {
			first_state.manager.incomplete_namespaces.clear()
		}

		mut all_deferred := []string{}
		mut any_progress := false

		for worklist.len > 0 {
			next_id := worklist.pop()
			next_state := graph[next_id] or { continue }
			tree := next_state.tree or { continue }

			deferred, incomplete, progress := semantic_analyze_target(next_id, next_id,
				next_state, TargetNode(tree), none, final_iteration, mut patches)

			all_deferred << deferred
			any_progress = any_progress || progress
			if !incomplete {
				next_state.manager.incomplete_namespaces.delete(next_id)
			}
		}

		if final_iteration {
			break
		}

		worklist = all_deferred.clone()
		worklist.reverse_in_place()
		final_iteration = !any_progress
	}
}

fn process_functions(graph &Graph, scc []string, mut patches Patches) {
	mut all_targets := []FullTargetInfo{}
	for mod_id in scc {
		state := graph[mod_id] or { continue }
		tree := state.tree or { continue }
		// targets := get_all_leaf_targets(tree)
		// for t in targets { all_targets << FullTargetInfo{ ... } }
	}
	// order and process
}

fn semantic_analyze_target(target string,
	mod_id string,
	state &State,
	node TargetNode,
	active_type ?&TypeInfo,
	final_iteration bool,
	mut patches Patches) ([]string, bool, bool) {
	state.manager.processed_targets << [mod_id, target]
	tree := state.tree or { return [], false, false }
	analyzer := state.manager.semantic_analyzer

	analyzer.globals = tree.names
	analyzer.progress = false

	mut refresh_node := node
	if refresh_node is Decorator {
		refresh_node = TargetNode(refresh_node.func)
	}

	// analyzer.refresh_partial(refresh_node, patches, final_iteration, tree, active_type)

	if analyzer.deferred {
		return [target], analyzer.incomplete, analyzer.progress
	}
	return [], analyzer.incomplete, analyzer.progress
}

fn calculate_class_properties_scc(graph &Graph, scc []string, errors &Errors) {
	for mod_id in scc {
		state := graph[mod_id] or { continue }
		tree := state.tree or { continue }
		for _, node in tree.names.symbols {
			symnode := node.node or { continue }
			if symnode is TypeInfo {
				calculate_class_abstract_status(symnode, tree.is_stub, errors)
				check_protocol_status(symnode, errors)
				calculate_class_vars(symnode)
			}
		}
	}
}

fn apply_semantic_analyzer_patches(patches Patches) {
	mut sorted := patches.clone()
	sorted.sort_with_compare(fn (a &PatchEntry, b &PatchEntry) int {
		return a.priority - b.priority
	})
	for p in sorted {
		p.callback()
	}
}
