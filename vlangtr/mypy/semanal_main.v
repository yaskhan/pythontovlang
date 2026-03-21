// Я Cline работаю над этим файлом. Начало: 2026-03-22 03:16
// Трансляция: mypy/mypy/semanal_main.py → vlangtr/mypy/semanal_main.v
// Статус: В процессе

module mypy

// ============================================================================
// Constants
// ============================================================================

// If we perform this many iterations, raise an exception since we are likely stuck
pub const max_iterations = 20

// Number of passes over core modules before going on to the rest of the builtin SCC
pub const core_warmup = 2
pub const core_modules = [
	'typing',
	'_collections_abc',
	'builtins',
	'abc',
	'collections',
	'collections.abc',
]

// ============================================================================
// Types
// ============================================================================

// Patches is a list of (priority, callback) tuples
pub type Patch = (int, fn ())
pub type Patches = []Patch

// Node type for targets
pub type TargetNode = MypyFile | FuncDef | OverloadedFuncDef | Decorator

// Function node type (without MypyFile and Decorator)
pub type FunctionNode = FuncDef | OverloadedFuncDef

// TargetInfo: (fullname, node, active_type)
pub struct TargetInfo {
pub:
	fullname    string
	node        TargetNode
	active_type ?TypeInfo
}

// FullTargetInfo: (module, fullname, node, active_type)
pub struct FullTargetInfo {
pub:
	module      string
	fullname    string
	node        TargetNode
	active_type ?TypeInfo
}

// ============================================================================
// Main semantic analysis functions
// ============================================================================

// semantic_analysis_for_scc performs semantic analysis for all modules in a SCC (import cycle)
pub fn semantic_analysis_for_scc(graph &Graph, scc []string, errors &Errors) {
	mut patches := Patches{}
	// Note that functions can't define new module-level attributes
	// using 'global x', since module top levels are fully processed
	// before functions. This limitation is unlikely to go away soon.
	process_top_levels(graph, scc, mut patches)
	process_functions(graph, scc, mut patches)
	// We use patch callbacks to fix up things when we expect relatively few
	// callbacks to be required
	apply_semantic_analyzer_patches(patches)
	// Run class decorator hooks (they require complete MROs and no placeholders)
	apply_class_plugin_hooks(graph, scc, errors)
	// This pass might need fallbacks calculated above and the results of hooks
	check_type_arguments(graph, scc, errors)
	calculate_class_properties(graph, scc, errors)
	check_blockers(graph, scc)
	// Clean-up builtins, so that TypeVar etc. are not accessible without importing
	if 'builtins' in scc {
		cleanup_builtin_scc(graph['builtins'])
	}

	// Report TypeForm profiling stats
	if scc.len >= 1 {
		// Get manager from any state in the SCC (they all share the same manager)
		manager := graph[scc[0]].manager
		analyzer := manager.semantic_analyzer
		manager.add_stats(
			type_expression_parse_count:              analyzer.type_expression_parse_count
			type_expression_full_parse_success_count: analyzer.type_expression_full_parse_success_count
			type_expression_full_parse_failure_count: analyzer.type_expression_full_parse_failure_count
		)
	}
}

// cleanup_builtin_scc removes imported names from builtins namespace
fn cleanup_builtin_scc(state &State) {
	assert state.tree != none
	remove_imported_names_from_symtable(state.tree.names, 'builtins')
}

// semantic_analysis_for_targets semantically analyzes only selected nodes in a given module
pub fn semantic_analysis_for_targets(state &State,
	nodes []FineGrainedDeferredNode,
	graph &Graph) {
	mut patches := Patches{}
	if nodes.any(it.node is MypyFile) {
		// Process module top level first (if needed)
		process_top_levels(graph, [state.id], mut patches)
	}
	analyzer := state.manager.semantic_analyzer
	for n in nodes {
		if n.node is MypyFile {
			// Already done above
			continue
		}
		process_top_level_function(analyzer, state, state.id, n.node.fullname, n.node,
			n.active_typeinfo, mut patches)
	}
	apply_semantic_analyzer_patches(patches)
	apply_class_plugin_hooks(graph, [state.id], state.manager.errors)
	check_type_arguments_in_targets(nodes, state, state.manager.errors)
	calculate_class_properties(graph, [state.id], state.manager.errors)
}

// ============================================================================
// Top-level processing
// ============================================================================

fn process_top_levels(graph &Graph, scc []string, mut patches Patches) {
	// Process top levels until everything has been bound

	// Reverse order of the scc so the first modules in the original list will be
	// processed first. This helps with performance
	mut scc_rev := scc.reverse()

	// Initialize ASTs and symbol tables
	for id in scc_rev {
		state := graph[id]
		assert state.tree != none
		state.manager.semantic_analyzer.prepare_file(state.tree)
	}

	// Initially all namespaces in the SCC are incomplete (well they are empty)
	state := graph[scc_rev[0]]
	state.manager.incomplete_namespaces.update(scc_rev)

	mut worklist := scc_rev.clone()
	// HACK: process core stuff first. This is mostly needed to support defining
	// named tuples in builtin SCC
	if core_modules.all(it in worklist) {
		worklist << core_modules.reverse().repeat(core_warmup)
	}
	mut final_iteration := false
	mut iteration := 0
	analyzer := state.manager.semantic_analyzer
	analyzer.deferral_debug_context.clear()

	for worklist.len > 0 {
		iteration++
		if iteration > max_iterations {
			// Just pick some module inside the current SCC for error context
			assert state.tree != none
			ctx := analyzer.file_context(state.tree, state.options)
			analyzer.report_hang()
			ctx.free()
			break
		}
		if final_iteration {
			// Give up. It's impossible to bind all names
			state.manager.incomplete_namespaces.clear()
		}
		mut all_deferred := []string{}
		mut any_progress := false
		for worklist.len > 0 {
			next_id := worklist.pop()
			next_state := graph[next_id]
			assert next_state.tree != none
			deferred, incomplete, progress := semantic_analyze_target(next_id, next_id,
				next_state, next_state.tree, none, final_iteration, mut patches)
			all_deferred << deferred
			any_progress = any_progress || progress
			if !incomplete {
				next_state.manager.incomplete_namespaces.delete(next_id)
			}
		}
		if final_iteration {
			assert all_deferred.len == 0, 'Must not defer during final iteration'
		}
		// Reverse to process the targets in the same order on every iteration
		worklist = all_deferred.reverse()
		final_iteration = !any_progress
	}
	// Functions/methods that define/infer attributes are processed as part of top-levels
	// We need to clear the locals for those between fine-grained iterations
	analyzer.saved_locals.clear()
}

// ============================================================================
// Function processing
// ============================================================================

fn process_functions(graph &Graph, scc []string, mut patches Patches) {
	// Process functions
	mut all_targets := []FullTargetInfo{}
	for mod_id in scc {
		tree := graph[mod_id].tree
		assert tree != none
		// In principle, functions can be processed in arbitrary order,
		// but _methods_ must be processed in the order they are defined,
		// because some features (most notably partial types) depend on
		// order of definitions on self
		targets := get_all_leaf_targets(tree).sorted_by_key(a.fullname, a.line)
		for t in targets {
			all_targets << FullTargetInfo{
				module:      mod_id
				fullname:    t.fullname
				node:        t.node
				active_type: t.active_type
			}
		}
	}

	for target in order_by_subclassing(all_targets) {
		analyzer := graph[target.module].manager.semantic_analyzer
		assert target.node is FuncDef || target.node is OverloadedFuncDef
			|| target.node is Decorator
		process_top_level_function(analyzer, graph[target.module], target.module, target.fullname,
			target.node, target.active_type, mut patches)
	}
}

fn process_top_level_function(analyzer &SemanticAnalyzer,
	state &State,
	mod_id string,
	target string,
	node TargetNode,
	active_type ?TypeInfo,
	mut patches Patches) {
	// Analyze single top-level function or method
	// Process the body of the function (including nested functions) again and again,
	// until all names have been resolved (or iteration limit reached)

	// We need one more iteration after incomplete is False (e.g. to report errors, if any)
	mut final_iteration := false
	mut incomplete := true
	// Start in the incomplete state (no missing names will be reported on first pass)
	// Note that we use module name, since functions don't create qualified names
	mut deferred := [mod_id]
	analyzer.deferral_debug_context.clear()
	analyzer.incomplete_namespaces.add(mod_id)
	mut iteration := 0
	for deferred.len > 0 {
		iteration++
		if iteration == max_iterations {
			// Just pick some module inside the current SCC for error context
			assert state.tree != none
			ctx := analyzer.file_context(state.tree, state.options)
			analyzer.report_hang()
			ctx.free()
			break
		}
		if !(deferred.len > 0 || incomplete) || final_iteration {
			// OK, this is one last pass, now missing names will be reported
			analyzer.incomplete_namespaces.delete(mod_id)
		}
		mut new_deferred := []string{}
		new_deferred, incomplete, progress = semantic_analyze_target(target, mod_id, state,
			node, active_type, final_iteration, mut patches)
		deferred = new_deferred
		if !incomplete {
			state.manager.incomplete_namespaces.delete(mod_id)
		}
		if final_iteration {
			assert deferred.len == 0, 'Must not defer during final iteration'
		}
		if !progress {
			final_iteration = true
		}
	}

	analyzer.incomplete_namespaces.delete(mod_id)
	// After semantic analysis is done, discard local namespaces
	// to avoid memory hoarding
	analyzer.saved_locals.clear()
}

// ============================================================================
// Target utilities
// ============================================================================

fn get_all_leaf_targets(file &MypyFile) []TargetInfo {
	// Return all leaf targets in a symbol table (module-level and methods)
	mut result := []TargetInfo{}
	for def in file.local_definitions() {
		fullname, node, active_type := def
		if node.node is FuncDef || node.node is OverloadedFuncDef || node.node is Decorator {
			result << TargetInfo{
				fullname:    fullname
				node:        node.node
				active_type: active_type
			}
		}
	}
	return result
}

fn semantic_analyze_target(target string,
	mod_id string,
	state &State,
	node TargetNode,
	active_type ?TypeInfo,
	final_iteration bool,
	mut patches Patches) ([]string, bool, bool) {
	// Semantically analyze a single target
	// Return tuple: (deferred targets, was incomplete, were any new names defined)

	state.manager.processed_targets << [mod_id, target]
	tree := state.tree
	assert tree != none
	analyzer := state.manager.semantic_analyzer
	// TODO: Move initialization to somewhere else
	analyzer.global_decls = [set[string]()]
	analyzer.nonlocal_decls = [set[string]()]
	analyzer.globals = tree.names
	analyzer.imports = set[string]()
	analyzer.progress = false

	ctx := state.wrap_context(check_blockers: false)
	mut refresh_node := node
	if refresh_node is Decorator {
		// Decorator expressions will be processed as part of the module top level
		refresh_node = refresh_node.func
	}
	analyzer.refresh_partial(refresh_node, patches, final_iteration,
		file_node:   tree
		options:     state.options
		active_type: active_type
	)
	if node is Decorator {
		infer_decorator_signature_if_simple(node, analyzer)
	}
	ctx.free()

	// Clear out some stale data to avoid memory leaks and astmerge validity check confusion
	analyzer.statement = none
	unsafe {
		analyzer.cur_mod_node = none
	}
	if analyzer.deferred {
		return [target], analyzer.incomplete, analyzer.progress
	} else {
		return [], analyzer.incomplete, analyzer.progress
	}
}

// ============================================================================
// Ordering utilities
// ============================================================================

fn order_by_subclassing(targets []FullTargetInfo) []FullTargetInfo {
	// Make sure that superclass methods are always processed before subclass methods
	// This algorithm is not very optimal, but it is simple and should work well for lists
	// that are already almost correctly ordered

	// First, group the targets by their TypeInfo (since targets are sorted by line,
	// we know that each TypeInfo will appear as group key only once)
	mut grouped := [][]FullTargetInfo{}
	mut current_group := []FullTargetInfo{}
	mut current_info := none as ?TypeInfo

	for target in targets {
		info := target.active_type
		if info != current_info {
			if current_group.len > 0 {
				grouped << current_group
			}
			current_group = [target]
			current_info = info
		} else {
			current_group << target
		}
	}
	if current_group.len > 0 {
		grouped << current_group
	}

	mut remaining_infos := map[string]bool{}
	for group in grouped {
		if group[0].active_type != none {
			remaining_infos[group[0].active_type.fullname] = true
		}
	}

	mut result := []FullTargetInfo{}
	mut next_group := 0
	for grouped.len > 0 {
		if next_group >= grouped.len {
			// This should never happen, if there is an MRO cycle, it should be reported
			// and fixed during top-level processing
			panic('Cannot order method targets by MRO')
		}
		next_info := grouped[next_group][0].active_type
		if next_info == none {
			// Trivial case, not methods but functions, process them straight away
			result << grouped[next_group]
			grouped.delete(next_group)
			continue
		}
		// Check if any parent is still in remaining_infos
		mut blocked := false
		for parent in next_info.mro[1..] {
			if parent.fullname in remaining_infos {
				blocked = true
				break
			}
		}
		if blocked {
			// We cannot process this method group yet, try a next one
			next_group++
			continue
		}
		result << grouped[next_group]
		grouped.delete(next_group)
		remaining_infos.delete(next_info.fullname)
		// Each time after processing a method group we should retry from start,
		// since there may be some groups that are not blocked on parents anymore
		next_group = 0
	}
	return result
}

// ============================================================================
// Type argument checking
// ============================================================================

fn check_type_arguments(graph &Graph, scc []string, errors &Errors) {
	for mod_id in scc {
		state := graph[mod_id]
		assert state.tree != none
		analyzer := TypeArgumentAnalyzer{
			errors:        errors
			options:       state.options
			is_typeshed:   state.tree.is_typeshed_file(state.options)
			named_type_fn: state.manager.semantic_analyzer.named_type
		}
		ctx := state.wrap_context()
		opt_ctx := mypy_state_strict_optional_set(state.options.strict_optional)
		state.tree.accept(analyzer)
		opt_ctx.free()
		ctx.free()
	}
}

fn check_type_arguments_in_targets(targets []FineGrainedDeferredNode,
	state &State,
	errors &Errors) {
	// Check type arguments against type variable bounds and restrictions
	// This mirrors the logic in check_type_arguments() except that we process only
	// some targets. This is used in fine grained incremental mode

	assert state.tree != none
	analyzer := TypeArgumentAnalyzer{
		errors:        errors
		options:       state.options
		is_typeshed:   state.tree.is_typeshed_file(state.options)
		named_type_fn: state.manager.semantic_analyzer.named_type
	}
	ctx := state.wrap_context()
	opt_ctx := mypy_state_strict_optional_set(state.options.strict_optional)
	for target in targets {
		mut func := none as ?FunctionNode
		if target.node is FuncDef {
			func = target.node
		} else if target.node is OverloadedFuncDef {
			func = target.node
		}
		saved := SavedScope{
			module:   state.id
			class:    target.active_typeinfo
			function: func
		}
		scope_ctx := if errors.scope != none {
			errors.scope.saved_scope(saved)
		} else {
			no_context()
		}
		analyzer.recurse_into_functions = func != none
		target.node.accept(analyzer)
		scope_ctx.free()
	}
	opt_ctx.free()
	ctx.free()
}

// ============================================================================
// Class plugin hooks
// ============================================================================

fn apply_class_plugin_hooks(graph &Graph, scc []string, errors &Errors) {
	// Apply class plugin hooks within a SCC
	// We run these after the main semantic analysis so that the hooks
	// don't need to deal with incomplete definitions such as placeholder types

	mut num_passes := 0
	mut incomplete := true
	// If we encounter a base class that has not been processed, we'll run another
	// pass. This should eventually reach a fixed point
	for incomplete {
		assert num_passes < 10, 'Internal error: too many class plugin hook passes'
		num_passes++
		incomplete = false
		for mod_id in scc {
			state := graph[mod_id]
			tree := state.tree
			assert tree != none
			for def in tree.local_definitions() {
				_, node, _ := def
				if node.node is TypeInfo {
					if !apply_hooks_to_class(state.manager.semantic_analyzer, mod_id,
						node.node, state.options, tree, errors) {
						incomplete = true
					}
				}
			}
		}
	}
}

fn apply_hooks_to_class(self &SemanticAnalyzer,
	module string,
	info &TypeInfo,
	options &Options,
	file_node &MypyFile,
	errors &Errors) bool {
	// TODO: Move more class-related hooks here?
	defn := info.defn
	mut ok := true
	for decorator in defn.decorators {
		ctx := self.file_context(file_node, options, info)
		mut hook := none as ?ClassDecoratorHook

		decorator_name := self.get_fullname_for_hook(decorator)
		if decorator_name != none {
			hook = self.plugin.get_class_decorator_hook_2(decorator_name)
		}
		// Special case: if the decorator is itself decorated with
		// typing.dataclass_transform, apply the hook for the dataclasses plugin
		// TODO: remove special casing here
		if hook == none && find_dataclass_transform_spec(decorator) {
			hook = dataclass_class_maker_callback
		}

		if hook != none {
			ok = ok && hook(ClassDefContext{
				defn:   defn
				reason: decorator
				api:    self
			})
		}
		ctx.free()
	}

	// Check if the class definition itself triggers a dataclass transform (via a parent class/metaclass)
	spec := find_dataclass_transform_spec(info)
	if spec != none {
		ctx := self.file_context(file_node, options, info)
		// We can't use the normal hook because reason = defn, and ClassDefContext only accepts
		// an Expression for reason
		ok = ok && DataclassTransformer{
			defn:   defn
			reason: defn
			spec:   spec
			api:    self
		}.transform()
		ctx.free()
	}

	return ok
}

// ============================================================================
// Class properties calculation
// ============================================================================

fn calculate_class_properties(graph &Graph, scc []string, errors &Errors) {
	builtins := graph['builtins'].tree
	assert builtins != none
	for mod_id in scc {
		state := graph[mod_id]
		tree := state.tree
		assert tree != none
		for def in tree.local_definitions() {
			_, node, _ := def
			if node.node is TypeInfo {
				ctx := state.manager.semantic_analyzer.file_context(tree, state.options,
					node.node)
				calculate_class_abstract_status(node.node, tree.is_stub, errors)
				check_protocol_status(node.node, errors)
				calculate_class_vars(node.node)
				add_type_promotion(node.node, tree.names, graph[mod_id].options, builtins.names)
				ctx.free()
			}
		}
	}
}

// ============================================================================
// Blocker checking
// ============================================================================

fn check_blockers(graph &Graph, scc []string) {
	for mod_id in scc {
		graph[mod_id].check_blockers()
	}
}

// ============================================================================
// Helper functions
// ============================================================================

fn apply_semantic_analyzer_patches(patches Patches) {
	// Apply patches in priority order
	sorted_patches := patches.sorted_by_key(a[0], b[0])
	for _, callback in sorted_patches {
		callback()
	}
}

fn remove_imported_names_from_symtable(names map[string]SymbolTableNode, mod_name string) {
	// Remove names that were imported from the specified module
	mut to_delete := []string{}
	for name, node in names {
		if node.node != none && node.node is MypyFile && node.node.fullname == mod_name {
			to_delete << name
		}
	}
	for name in to_delete {
		names.delete(name)
	}
}

// ============================================================================
// Forward declarations (to be defined in other modules)
// ============================================================================

pub interface Graph {
	get(id string) State
	keys() []string
}

pub interface State {
	id      string
	tree    ?MypyFile
	manager SemanticAnalyzerManager
	options Options
	wrap_context(check_blockers bool) StateContext
}

pub interface SemanticAnalyzerManager {
	semantic_analyzer     SemanticAnalyzer
	incomplete_namespaces map[string]bool
	processed_targets     [](string, string)
	errors                Errors
	add_stats(type_expression_parse_count int,
	type_expression_full_parse_success_count int,
	type_expression_full_parse_failure_count int)
}

pub interface SemanticAnalyzer {
	global_decls                             []set[string]
	nonlocal_decls                           []set[string]
	globals                                  map[string]SymbolTableNode
	imports                                  set[string]
	progress                                 bool
	deferred                                 bool
	incomplete                               bool
	statement                                ?Statement
	cur_mod_node                             ?MypyFile
	deferral_debug_context                   []string
	saved_locals                             map[string]map[string]SymbolTableNode
	incomplete_namespaces                    set[string]
	type_expression_parse_count              int
	type_expression_full_parse_success_count int
	type_expression_full_parse_failure_count int
	plugin                                   Plugin
	named_type(name string) Type
	prepare_file(file &MypyFile)
	refresh_partial(node TargetNode,
	patches Patches,
	final_iteration bool,
	file_node MypyFile,
	options Options,
	active_type ?TypeInfo)
	file_context(file &MypyFile, options &Options, info ?TypeInfo) FileContext
	report_hang()
	get_fullname_for_hook(expr &Expression) ?string
}

pub interface TypeArgumentAnalyzer {
	recurse_into_functions bool
}

pub interface FineGrainedDeferredNode {
	node            TargetNode
	active_typeinfo ?TypeInfo
}

pub interface ClassDefContext {
	defn   ClassDef
	reason Expression
	api    SemanticAnalyzer
}

pub interface ClassDecoratorHook {
	fn(ctx ClassDefContext) bool
}

pub interface DataclassTransformer {
	transform fn () bool
}

pub interface Plugin {
	get_class_decorator_hook_2(name string) ?ClassDecoratorHook
}

pub interface FileContext {
	// Context manager for file-level operations
}

pub interface StateContext {
	// Context manager for state operations
}

pub interface SavedScope {
	module   string
	class    ?TypeInfo
	function ?FunctionNode
}

pub interface ErrorScope {
	saved_scope(scope SavedScope) ErrorScopeContext
}

pub interface ErrorScopeContext {
	// Context manager for error scope
}

fn no_context() NoContext {
	return NoContext{}
}

pub interface NoContext {
	// Empty context manager
}

fn mypy_state_strict_optional_set(value bool) StrictOptionalContext {
	return StrictOptionalContext{
		value: value
	}
}

pub struct StrictOptionalContext {
	value bool
}
