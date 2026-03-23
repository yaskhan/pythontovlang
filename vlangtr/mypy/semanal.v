// I, Cline, am working on this file. Started: 2026-03-22 20:31
// semanal.v — The semantic analyzer
// Translated from mypy/semanal.py
// Note: this is a very large file (~3000 lines), translated main structures and key functions

module mypy

// Scope constants
pub const scope_global = 0
pub const scope_class = 1
pub const scope_func = 2
pub const scope_comprehension = 3
pub const scope_annotation = 4

// FUTURE_IMPORTS — mapping of future imports to flags
pub const future_imports = {
	'__future__.nested_scopes':    'nested_scopes'
	'__future__.generators':       'generators'
	'__future__.division':         'division'
	'__future__.absolute_import':  'absolute_import'
	'__future__.with_statement':   'with_statement'
	'__future__.print_function':   'print_function'
	'__future__.unicode_literals': 'unicode_literals'
	'__future__.barry_as_FLUFL':   'barry_as_FLUFL'
	'__future__.generator_stop':   'generator_stop'
	'__future__.annotations':      'annotations'
}

// CORE_BUILTIN_CLASSES — basic builtins classes
pub const core_builtin_classes = ['object', 'bool', 'function']

// SemanticAnalyzer — mypy semantic analyzer
pub struct SemanticAnalyzer {
pub mut:
	modules                              map[string]MypyFile
	globals                              SymbolTable
	global_decls                         []map[string]bool
	nonlocal_decls                       []map[string]bool
	locals                               []?SymbolTable
	scope_stack                          []int
	block_depth                          []int
	_type                                ?TypeInfo
	type_stack                           []?TypeInfo
	tvar_scope                           TypeVarLikeScope
	options                              Options
	function_stack                       []FuncItem
	progress                             bool
	deferred                             bool
	incomplete                           bool
	_final_iteration                     bool
	missing_names                        []map[string]bool
	loop_depth                           []int
	cur_mod_id                           string
	_is_stub_file                        bool
	_is_typeshed_stub_file               bool
	imports                              map[string]bool
	errors                               Errors
	plugin                               Plugin
	statement                            ?Statement
	cur_mod_node                         ?MypyFile
	msg                                  MessageBuilder
	scope                                Scope
	incomplete_type_stack                []bool
	allow_unbound_tvars                  bool
	basic_type_applications              bool
	current_overload_item                ?int
	inside_except_star_block             bool
	return_stmt_inside_except_star_block bool
	all_exports                          []string
	saved_locals                         map[string]SymbolTable
	incomplete_namespaces                map[string]bool
	deferral_debug_context               [][]string
	transitive_submodule_imports         map[string]map[string]bool
}

// new_semantic_analyzer creates a new SemanticAnalyzer
pub fn new_semantic_analyzer(modules map[string]MypyFile, errors Errors, plugin Plugin, options Options) SemanticAnalyzer {
	return SemanticAnalyzer{
		modules:                              modules
		globals:                              SymbolTable{}
		global_decls:                         [map[string]bool{}]
		nonlocal_decls:                       [map[string]bool{}]
		locals:                               [?SymbolTable(none)]
		scope_stack:                          [scope_global]
		block_depth:                          [0]
		_type:                                none
		type_stack:                           []?TypeInfo{}
		tvar_scope:                           TypeVarLikeScope{}
		options:                              options
		function_stack:                       []FuncItem{}
		progress:                             false
		deferred:                             false
		incomplete:                           false
		_final_iteration:                     false
		missing_names:                        [map[string]bool{}]
		loop_depth:                           [0]
		cur_mod_id:                           ''
		_is_stub_file:                        false
		_is_typeshed_stub_file:               false
		imports:                              map[string]bool{}
		errors:                               errors
		plugin:                               plugin
		statement:                            none
		cur_mod_node:                         none
		msg:                                  MessageBuilder{}
		scope:                                Scope{}
		incomplete_type_stack:                []bool{}
		allow_unbound_tvars:                  false
		basic_type_applications:              false
		current_overload_item:                none
		inside_except_star_block:             false
		return_stmt_inside_except_star_block: false
		all_exports:                          []string{}
		saved_locals:                         map[string]SymbolTable{}
		incomplete_namespaces:                map[string]bool{}
		deferral_debug_context:               [][]string{}
		transitive_submodule_imports:         map[string]map[string]bool{}
	}
}

// type returns the current TypeInfo
pub fn (sa SemanticAnalyzer) type() ?TypeInfo {
	return sa._type
}

// is_stub_file checks if the file is a stub
pub fn (sa SemanticAnalyzer) is_stub_file() bool {
	return sa._is_stub_file
}

// is_typeshed_stub_file checks if the file is a stub from typeshed
pub fn (sa SemanticAnalyzer) is_typeshed_stub_file() bool {
	return sa._is_typeshed_stub_file
}

// final_iteration checks if this is the final iteration
pub fn (sa SemanticAnalyzer) final_iteration() bool {
	return sa._final_iteration
}

// prepare_file prepares a file for analysis
pub fn (mut sa SemanticAnalyzer) prepare_file(file_node MypyFile) {
	if 'builtins' in sa.modules {
		file_node.names['__builtins__'] = SymbolTableNode{
			kind: 0 // GDEF
			node: sa.modules['builtins']
		}
	}
	if file_node.fullname == 'builtins' {
		sa.prepare_builtins_namespace(file_node)
	}
}

// prepare_builtins_namespace adds special definitions to builtins
fn (mut sa SemanticAnalyzer) prepare_builtins_namespace(file_node MypyFile) {
	names := file_node.names

	// Add empty definitions for base classes
	for name in core_builtin_classes {
		cdef := ClassDef{
			name: name
			defs: Block{
				body: []
			}
		}
		info := new_type_info(names, cdef, 'builtins')
		info._fullname = 'builtins.${name}'
		names[name] = SymbolTableNode{
			kind: 0
			node: info
		}
	}

	// Add special variables
	bool_info := names['bool'].node
	assert bool_info is TypeInfoNode

	special_names := ['None', 'reveal_type', 'reveal_locals', 'True', 'False', '__debug__']
	special_types := [
		NoneTypeNode{},
		AnyTypeNode{
			reason: TypeOfAny.special_form
		},
		AnyTypeNode{
			reason: TypeOfAny.special_form
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
		InstanceNode{
			typ:  bool_info
			args: []
		},
	]

	for i, name in special_names {
		typ := special_types[i]
		v := Var{
			name:            name
			type_annotation: typ
		}
		v._fullname = 'builtins.${name}'
		names[name] = SymbolTableNode{
			kind: 0
			node: v
		}
	}
}

// visit_mypy_file handles MypyFile
pub fn (mut sa SemanticAnalyzer) visit_mypy_file(file_node MypyFile) {
	sa.cur_mod_node = file_node
	sa.cur_mod_id = file_node.fullname
	sa.globals = file_node.names

	for defn in file_node.defs {
		sa.accept(defn)
	}
}

// visit_func_def handles function definition
pub fn (mut sa SemanticAnalyzer) visit_func_def(defn FuncDef) {
	sa.statement = defn

	for arg in defn.arguments {
		if arg.initializer != none {
			// TODO: accept arg.initializer
		}
	}

	defn.is_conditional = sa.block_depth.last() > 0
	defn._fullname = sa.qualified_name(defn.name)

	if !sa.recurse_into_functions() || sa.function_stack.len > 0 {
		if !defn.is_decorated && !defn.is_overload {
			sa.add_function_to_symbol_table(defn)
		}
	}

	if !sa.recurse_into_functions() && !defn.def_or_infer_vars {
		return
	}

	sa.function_stack << defn
	sa.analyze_func_def(defn)
	sa.function_stack.pop()
}

// analyze_func_def analyzes function definition
fn (mut sa SemanticAnalyzer) analyze_func_def(defn FuncDef) {
	if sa.push_type_args(defn.type_args, defn) == none {
		sa.defer(defn)
		return
	}

	sa.function_stack << defn

	mut has_self_type := false
	if defn.type != none {
		has_self_type = sa.update_function_type_variables(defn.type as CallableTypeNode,
			defn)
	}

	sa.function_stack.pop()

	if sa.is_class_scope() {
		defn.info = sa._type
	}

	// TODO: function signature analysis
	sa.analyze_function_body(defn)
	sa.pop_type_args(defn.type_args)
}

// visit_class_def handles class definition
pub fn (mut sa SemanticAnalyzer) visit_class_def(defn ClassDef) {
	sa.statement = defn
	sa.incomplete_type_stack << (defn.info == none)

	namespace := sa.qualified_name(defn.name)
	if sa.push_type_args(defn.type_args, defn) == none {
		sa.mark_incomplete(defn.name, defn)
		return
	}

	sa.analyze_class(defn)
	sa.pop_type_args(defn.type_args)
	sa.incomplete_type_stack.pop()
}

// analyze_class analyzes class definition
fn (mut sa SemanticAnalyzer) analyze_class(defn ClassDef) {
	fullname := sa.qualified_name(defn.name)

	if defn.info == none && !sa.is_core_builtin_class(defn) {
		placeholder := PlaceholderNode{
			fullname:         fullname
			node:             defn
			line:             defn.line
			becomes_typeinfo: true
		}
		sa.add_symbol(defn.name, placeholder, defn)
	}

	// TODO: full class analysis implementation
	sa.prepare_class_def(defn)
	sa.setup_type_vars(defn, [])

	sa.enter_class(defn.info or { return })
	defn.defs.accept(sa)
	sa.leave_class()
}

// visit_import handles import
pub fn (mut sa SemanticAnalyzer) visit_import(i Import) {
	sa.statement = i
	for id, as_id in i.ids {
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		base_id := if as_id != none { id } else { id.split('.')[0] }
		imported_id := if as_id != none { as_id } else { base_id }
		module_public := use_implicit_reexport || (as_id != none && id == as_id)

		if base_id in sa.modules {
			node := sa.modules[base_id]
			kind := if sa.is_func_scope() {
				2
			} else if sa._type != none {
				1
			} else {
				0
			}
			symbol := SymbolTableNode{
				kind:          kind
				node:          node
				module_public: module_public
				module_hidden: !module_public
			}
			sa.add_imported_symbol(imported_id, symbol, i, module_public, !module_public)
		} else {
			sa.add_unknown_imported_symbol(imported_id, i, base_id, module_public, !module_public)
		}
	}
}

// visit_import_from handles from ... import
pub fn (mut sa SemanticAnalyzer) visit_import_from(imp ImportFrom) {
	sa.statement = imp
	mod_id := sa.correct_relative_import(imp)
	mod := sa.modules[mod_id] or { none }

	for id, as_id in imp.names {
		fullname := '${mod_id}.${id}'
		sa.set_future_import_flags(fullname)

		mut node := ?SymbolTableNode(none)
		if mod != none {
			node = (mod as MypyFile).names[id] or { none }
		}

		imported_id := if as_id != none { as_id } else { id }
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		module_public := use_implicit_reexport || (as_id != none && id == as_id)

		if node != none {
			sa.add_imported_symbol(imported_id, node, imp, module_public, !module_public)
		} else if mod != none {
			sa.report_missing_module_attribute(mod_id, id, imported_id, imp)
		} else {
			sa.add_unknown_imported_symbol(imported_id, imp, fullname, module_public,
				!module_public)
		}
	}
}

// visit_assignment_stmt handles assignment
pub fn (mut sa SemanticAnalyzer) visit_assignment_stmt(s AssignmentStmt) {
	sa.statement = s

	if sa.analyze_identity_global_assignment(s) {
		return
	}

	tag := sa.track_incomplete_refs()
	// TODO: analyze rvalue
	s.rvalue.accept(sa)

	if sa.found_incomplete_ref(tag) {
		for expr in sa.names_modified_by_assignment(s) {
			sa.mark_incomplete(expr.name, expr)
		}
		return
	}

	// TODO: check special forms (type alias, TypeVar, etc.)
	s.is_final_def = sa.unwrap_final(s)
	sa.analyze_lvalues(s)
	// TODO: additional checks
}

// visit_if_stmt handles if
pub fn (mut sa SemanticAnalyzer) visit_if_stmt(s IfStmt) {
	sa.statement = s
	// TODO: infer_reachability_of_if_statement
	for i in 0 .. s.expr.len {
		s.expr[i].accept(sa)
		sa.visit_block(s.body[i])
	}
	sa.visit_block_maybe(s.else_body)
}

// visit_block handles block
pub fn (mut sa SemanticAnalyzer) visit_block(b Block) {
	if b.is_unreachable {
		return
	}
	sa.block_depth[sa.block_depth.len - 1]++
	for s in b.body {
		sa.accept(s)
	}
	sa.block_depth[sa.block_depth.len - 1]--
}

// visit_block_maybe handles optional block
pub fn (mut sa SemanticAnalyzer) visit_block_maybe(b ?Block) {
	if b != none {
		sa.visit_block(b)
	}
}

// visit_while_stmt handles while
pub fn (mut sa SemanticAnalyzer) visit_while_stmt(s WhileStmt) {
	sa.statement = s
	s.expr.accept(sa)
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(s.body)
	sa.loop_depth[sa.loop_depth.len - 1]--
	sa.visit_block_maybe(s.else_body)
}

// visit_for_stmt handles for
pub fn (mut sa SemanticAnalyzer) visit_for_stmt(s ForStmt) {
	if s.is_async {
		// TODO: async check
	}
	sa.statement = s
	s.expr.accept(sa)
	sa.analyze_lvalue(s.index, false, s.index_type != none)
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(s.body)
	sa.loop_depth[sa.loop_depth.len - 1]--
	sa.visit_block_maybe(s.else_body)
}

// visit_return_stmt handles return
pub fn (mut sa SemanticAnalyzer) visit_return_stmt(s ReturnStmt) {
	if !sa.is_func_scope() {
		sa.fail('"return" outside function', s)
	}
	if s.expr != none {
		s.expr.accept(sa)
	}
}

// visit_break_stmt handles break
pub fn (mut sa SemanticAnalyzer) visit_break_stmt(s BreakStmt) {
	if sa.loop_depth.last() == 0 {
		sa.fail('"break" outside loop', s, serious: true, blocker: true)
	}
}

// visit_continue_stmt handles continue
pub fn (mut sa SemanticAnalyzer) visit_continue_stmt(s ContinueStmt) {
	if sa.loop_depth.last() == 0 {
		sa.fail('"continue" outside loop', s, serious: true, blocker: true)
	}
}

// visit_try_stmt handles try
pub fn (mut sa SemanticAnalyzer) visit_try_stmt(s TryStmt) {
	sa.statement = s
	s.body.accept(sa)
	for i in 0 .. s.types.len {
		if s.types[i] != none {
			s.types[i].accept(sa)
		}
		if s.vars[i] != none {
			sa.analyze_lvalue(s.vars[i], false, false)
		}
		s.handlers[i].accept(sa)
	}
	sa.visit_block_maybe(s.else_body)
	sa.visit_block_maybe(s.finally_body)
}

// visit_decorator handles decorator
pub fn (mut sa SemanticAnalyzer) visit_decorator(dec Decorator) {
	sa.statement = dec
	dec.decorators = dec.original_decorators.clone()
	dec.func.is_conditional = sa.block_depth.last() > 0

	if !dec.is_overload {
		sa.add_symbol(dec.name, dec, dec)
	}

	dec.func._fullname = sa.qualified_name(dec.name)
	dec.var._fullname = sa.qualified_name(dec.name)

	for d in dec.decorators {
		d.accept(sa)
	}

	// TODO: handle special decorators (abstractmethod, staticmethod, etc.)
}

// visit_expression_stmt handles expression statement
pub fn (mut sa SemanticAnalyzer) visit_expression_stmt(s ExpressionStmt) {
	sa.statement = s
	s.expr.accept(sa)
}

// visit_name_expr handles name
pub fn (mut sa SemanticAnalyzer) visit_name_expr(expr NameExpr) {
	n := sa.lookup(expr.name, expr)
	if n != none {
		sa.bind_name_expr(expr, n)
	}
}

// visit_member_expr handles member access
pub fn (mut sa SemanticAnalyzer) visit_member_expr(expr MemberExpr) {
	expr.expr.accept(sa)
	// TODO: handle member access
}

// visit_call_expr handles call
pub fn (mut sa SemanticAnalyzer) visit_call_expr(expr CallExpr) {
	expr.callee.accept(sa)
	// TODO: handle special calls (cast, reveal_type, etc.)
	for a in expr.args {
		a.accept(sa)
	}
}

// visit_int_expr handles int literal
pub fn (sa SemanticAnalyzer) visit_int_expr(expr IntExpr) {
	// Do nothing
}

// visit_str_expr handles string literal
pub fn (sa SemanticAnalyzer) visit_str_expr(expr StrExpr) {
	// Do nothing
}

// visit_pass_stmt handles pass
pub fn (sa SemanticAnalyzer) visit_pass_stmt(s PassStmt) {
	// Do nothing
}

// accept accepts a node
pub fn (mut sa SemanticAnalyzer) accept(node Node) {
	if node is FuncDef {
		sa.visit_func_def(node)
	} else if node is ClassDef {
		sa.visit_class_def(node)
	} else if node is AssignmentStmt {
		sa.visit_assignment_stmt(node)
	} else if node is IfStmt {
		sa.visit_if_stmt(node)
	} else if node is WhileStmt {
		sa.visit_while_stmt(node)
	} else if node is ForStmt {
		sa.visit_for_stmt(node)
	} else if node is ReturnStmt {
		sa.visit_return_stmt(node)
	} else if node is BreakStmt {
		sa.visit_break_stmt(node)
	} else if node is ContinueStmt {
		sa.visit_continue_stmt(node)
	} else if node is TryStmt {
		sa.visit_try_stmt(node)
	} else if node is Decorator {
		sa.visit_decorator(node)
	} else if node is ExpressionStmt {
		sa.visit_expression_stmt(node)
	} else if node is PassStmt {
		sa.visit_pass_stmt(node)
	} else if node is Import {
		sa.visit_import(node)
	} else if node is ImportFrom {
		sa.visit_import_from(node)
	} else if node is Block {
		sa.visit_block(node)
	} else if node is NameExpr {
		sa.visit_name_expr(node)
	} else if node is MemberExpr {
		sa.visit_member_expr(node)
	} else if node is CallExpr {
		sa.visit_call_expr(node)
	} else if node is IntExpr {
		sa.visit_int_expr(node)
	} else if node is StrExpr {
		sa.visit_str_expr(node)
	}
}

// lookup looks up a name
pub fn (sa SemanticAnalyzer) lookup(name string, ctx NodeBase) ?SymbolTableNode {
	// Search in local scopes (innermost first)
	for i := sa.locals.len - 1; i >= 0; i-- {
		if locals := sa.locals[i] {
			if name in locals {
				return locals[name]
			}
		}
	}

	// Search in global scope
	if name in sa.globals {
		return sa.globals[name]
	}

	// Search in builtins
	if 'builtins' in sa.modules {
		builtins := sa.modules['builtins']
		if name in builtins.names {
			return builtins.names[name]
		}
	}

	return none
}

// lookup_qualified looks up a qualified name
pub fn (sa SemanticAnalyzer) lookup_qualified(name string, ctx NodeBase, suppress_errors bool) ?SymbolTableNode {
	if '.' !in name {
		return sa.lookup(name, ctx)
	}

	parts := name.split('.')
	if parts.len < 2 {
		return none
	}

	// Lookup first part
	first := parts[0]
	sym := sa.lookup(first, ctx) or { return none }

	// Navigate through remaining parts
	mut current := sym
	for i in 1 .. parts.len {
		part := parts[i]
		if current.node is TypeInfo {
			info := current.node as TypeInfo
			if part in info.names {
				current = info.names[part]
			} else {
				if !suppress_errors {
					sa.fail('Name "${part}" not found in "${parts[..i].join('.')}"', ctx,
						false, false)
				}
				return none
			}
		} else if current.node is MypyFile {
			file := current.node as MypyFile
			if part in file.names {
				current = file.names[part]
			} else {
				if !suppress_errors {
					sa.fail('Name "${part}" not found in module "${parts[..i].join('.')}"',
						ctx, false, false)
				}
				return none
			}
		} else {
			return none
		}
	}

	return current
}

// bind_name_expr binds a name
fn (mut sa SemanticAnalyzer) bind_name_expr(expr NameExpr, sym SymbolTableNode) {
	expr.kind = sym.kind
	expr.node = sym.node
	expr.fullname = sym.fullname or { '' }
}

// analyze_lvalue analyzes lvalue
pub fn (mut sa SemanticAnalyzer) analyze_lvalue(lval Lvalue, nested bool, explicit_type bool) {
	if lval is NameExpr {
		// TODO: analyze lvalue
	} else if lval is MemberExpr {
		lval.accept(sa)
	} else if lval is TupleExpr {
		for item in lval.items {
			sa.analyze_lvalue(item, true, explicit_type)
		}
	}
}

// names_modified_by_assignment returns names modified in assignment
fn (sa SemanticAnalyzer) names_modified_by_assignment(s AssignmentStmt) []NameExpr {
	mut result := []NameExpr{}
	for lval in s.lvalues {
		result << sa.names_modified_in_lvalue(lval)
	}
	return result
}

// names_modified_in_lvalue returns NameExpr in lvalue
fn (sa SemanticAnalyzer) names_modified_in_lvalue(lval Lvalue) []NameExpr {
	if lval is NameExpr {
		return [lval]
	} else if lval is TupleExpr {
		mut result := []NameExpr{}
		for item in lval.items {
			result << sa.names_modified_in_lvalue(item)
		}
		return result
	}
	return []
}

// unwrap_final handles Final
fn (mut sa SemanticAnalyzer) unwrap_final(s AssignmentStmt) bool {
	// Check if assignment is wrapped in Final[]
	for lval in s.lvalues {
		if lval is NameExpr {
			// Check if type annotation contains Final
			if s.type_ != none {
				typ := s.type_
				if typ is UnboundTypeNode {
					if typ.name == 'Final' {
						return true
					}
				}
			}
		}
	}
	return false
}

// analyze_identity_global_assignment checks X = X
fn (sa SemanticAnalyzer) analyze_identity_global_assignment(s AssignmentStmt) bool {
	// Check if this is a self-assignment like X = X
	if s.lvalues.len != 1 {
		return false
	}

	lval := s.lvalues[0]
	if lval !is NameExpr {
		return false
	}

	if s.rvalue !is NameExpr {
		return false
	}

	lval_name := (lval as NameExpr).name
	rval_name := (s.rvalue as NameExpr).name

	// Check if it's the same name and already exists in global scope
	if lval_name == rval_name && lval_name in sa.globals {
		return true
	}

	return false
}

// qualified_name returns the qualified name
fn (sa SemanticAnalyzer) qualified_name(name string) string {
	if sa._type != none {
		return (sa._type or { return '' })._fullname + '.' + name
	} else if sa.is_func_scope() {
		return name
	}
	return sa.cur_mod_id + '.' + name
}

// is_func_scope checks if we are in a function
fn (sa SemanticAnalyzer) is_func_scope() bool {
	scope_type := sa.scope_stack.last()
	return scope_type in [scope_func, scope_comprehension]
}

// is_class_scope checks if we are in a class
fn (sa SemanticAnalyzer) is_class_scope() bool {
	return sa._type != none && !sa.is_func_scope()
}

// is_module_scope checks if we are in a module
fn (sa SemanticAnalyzer) is_module_scope() bool {
	return !sa.is_class_scope() && !sa.is_func_scope()
}

// is_core_builtin_class checks if the class is a basic builtin
fn (sa SemanticAnalyzer) is_core_builtin_class(defn ClassDef) bool {
	return sa.cur_mod_id == 'builtins' && defn.name in core_builtin_classes
}

// recurse_into_functions checks if we should recursively traverse functions
fn (sa SemanticAnalyzer) recurse_into_functions() bool {
	return true // TODO: proper implementation
}

// enter_class enters a class
fn (mut sa SemanticAnalyzer) enter_class(info TypeInfo) {
	sa.type_stack << sa._type
	sa.locals << none
	sa.scope_stack << scope_class
	sa.block_depth << -1
	sa.loop_depth << 0
	sa._type = info
	sa.missing_names << map[string]bool{}
}

// leave_class exits a class
fn (mut sa SemanticAnalyzer) leave_class() {
	sa.block_depth.pop()
	sa.loop_depth.pop()
	sa.locals.pop()
	sa.scope_stack.pop()
	sa._type = sa.type_stack.pop()
	sa.missing_names.pop()
}

// add_function_to_symbol_table adds a function to the symbol table
fn (mut sa SemanticAnalyzer) add_function_to_symbol_table(func_def FuncDef) {
	if sa.is_class_scope() {
		func_def.info = sa._type
	}
	func_def._fullname = sa.qualified_name(func_def.name)
	sa.add_symbol(func_def.name, func_def, func_def)
}

// add_symbol adds a symbol
pub fn (mut sa SemanticAnalyzer) add_symbol(name string, node SymbolNode, context NodeBase) bool {
	// Check if symbol already exists in current scope
	if sa.locals.len > 0 {
		if locals := sa.locals.last() {
			if name in locals {
				// Symbol already defined in current scope
				existing := locals[name]
				if !sa.is_none_node(existing.node) {
					sa.fail('Name "${name}" already defined', context, false, false)
					return false
				}
			}
			// Add to current scope
			mut new_locals := locals.clone()
			new_locals[name] = SymbolTableNode{
				kind: 0 // LDEF for local
				node: node
			}
			sa.locals[sa.locals.len - 1] = new_locals
			return true
		}
	}

	// Add to global scope
	if name in sa.globals {
		existing := sa.globals[name]
		if !sa.is_none_node(existing.node) {
			sa.fail('Name "${name}" already defined', context, false, false)
			return false
		}
	}

	sa.globals[name] = SymbolTableNode{
		kind: 0 // GDEF for global
		node: node
	}
	return true
}

// add_imported_symbol adds an imported symbol
fn (mut sa SemanticAnalyzer) add_imported_symbol(name string, node SymbolTableNode, context ImportBase, module_public bool, module_hidden bool) {
	// Set module visibility flags
	mut sym := node
	sym.module_public = module_public
	sym.module_hidden = module_hidden

	// Add to current scope
	if sa.locals.len > 0 {
		if locals := sa.locals.last() {
			mut new_locals := locals.clone()
			new_locals[name] = sym
			sa.locals[sa.locals.len - 1] = new_locals
			return
		}
	}

	// Add to global scope
	sa.globals[name] = sym
}

// add_unknown_imported_symbol adds an unknown imported symbol
fn (mut sa SemanticAnalyzer) add_unknown_imported_symbol(name string, context NodeBase, target_name string, module_public bool, module_hidden bool) {
	// Create a placeholder for unknown import
	any_type := AnyType{
		type_of_any: TypeOfAny.from_error
	}

	// Create a Var node with Any type
	mut var := Var{
		name:            name
		type_annotation: any_type
	}
	var._fullname = target_name

	sym := SymbolTableNode{
		kind:          0
		node:          var
		module_public: module_public
		module_hidden: module_hidden
	}

	// Add to current scope
	if sa.locals.len > 0 {
		if locals := sa.locals.last() {
			mut new_locals := locals.clone()
			new_locals[name] = sym
			sa.locals[sa.locals.len - 1] = new_locals
			return
		}
	}

	// Add to global scope
	sa.globals[name] = sym
}

// report_missing_module_attribute reports a missing module attribute
fn (mut sa SemanticAnalyzer) report_missing_module_attribute(module_id string, source_id string, imported_id string, context NodeBase) {
	sa.fail('Module "${module_id}" has no attribute "${source_id}"', context, false, false)
}

// correct_relative_import corrects a relative import
fn (sa SemanticAnalyzer) correct_relative_import(node ImportFrom) string {
	// Handle relative imports
	mut mod_id := node.id
	if node.relative > 0 {
		// Relative import - prepend current module path
		parts := sa.cur_mod_id.split('.')
		if node.relative <= parts.len {
			base_parts := parts[..parts.len - node.relative + 1]
			if mod_id.len > 0 {
				mod_id = base_parts.join('.') + '.' + mod_id
			} else {
				mod_id = base_parts.join('.')
			}
		}
	}
	return mod_id
}

// set_future_import_flags sets future import flags
fn (mut sa SemanticAnalyzer) set_future_import_flags(fullname string) {
	if fullname in future_imports {
		sa.cur_mod_node.future_import_flags << future_imports[fullname]
	}
}

// push_type_args adds type args
fn (mut sa SemanticAnalyzer) push_type_args(type_args []TypeParam, context NodeBase) ?[]string {
	if type_args.len == 0 {
		return []string{}
	}

	mut names := []string{}
	for ta in type_args {
		names << ta.name

		// Add type variable to scope
		mut tvar := TypeVarType{
			name:     ta.name
			fullname: sa.qualified_name(ta.name)
		}

		if ta.upper_bound != none {
			tvar.upper_bound = ta.upper_bound
		}

		if ta.values.len > 0 {
			tvar.values = ta.values
		}

		sa.tvar_scope.bind(ta.name, tvar)
	}

	return names
}

// pop_type_args removes type args
fn (mut sa SemanticAnalyzer) pop_type_args(type_args []TypeParam) {
	for ta in type_args {
		sa.tvar_scope.unbind(ta.name)
	}
}

// update_function_type_variables updates function type variables
fn (mut sa SemanticAnalyzer) update_function_type_variables(fun_type CallableTypeNode, defn FuncItem) bool {
	// Process type variables from function signature
	if fun_type.variables.len > 0 {
		for tvar in fun_type.variables {
			if tvar is TypeVarType {
				sa.tvar_scope.bind(tvar.name, tvar)
			}
		}
		return true
	}
	return false
}

// analyze_function_body analyzes a function body
fn (mut sa SemanticAnalyzer) analyze_function_body(defn FuncItem) {
	// Enter function scope
	sa.scope_stack << scope_func
	sa.block_depth << 0
	sa.loop_depth << 0
	sa.locals << map[string]SymbolTableNode{}
	sa.missing_names << map[string]bool{}

	// Add function arguments to scope
	if defn is FuncDef {
		for arg in defn.arguments {
			mut var := Var{
				name:            arg.variable.name
				type_annotation: arg.variable.typ
			}
			var._fullname = sa.qualified_name(arg.variable.name)
			sa.add_symbol(arg.variable.name, var, defn)
		}
	}

	// Analyze function body
	defn.body.accept(sa)

	// Leave function scope
	sa.scope_stack.pop()
	sa.block_depth.pop()
	sa.loop_depth.pop()
	sa.locals.pop()
	sa.missing_names.pop()
}

// prepare_class_def prepares a class definition
fn (mut sa SemanticAnalyzer) prepare_class_def(defn ClassDef) {
	// Create TypeInfo if not exists
	if defn.info == none {
		fullname := sa.qualified_name(defn.name)
		mut info := new_type_info(sa.globals, defn, sa.cur_mod_id)
		info._fullname = fullname
		defn.info = info
	}

	// Process base classes
	for base_expr in defn.base_type_exprs {
		base_expr.accept(sa)
	}

	// Process decorators
	for dec in defn.decorators {
		dec.accept(sa)
	}
}

// setup_type_vars sets up type variables
fn (mut sa SemanticAnalyzer) setup_type_vars(defn ClassDef, tvar_defs []TypeVarLikeType) {
	// Add type variables from class definition to scope
	for tvar_def in tvar_defs {
		if tvar_def is TypeVarType {
			sa.tvar_scope.bind(tvar_def.name, tvar_def)
		}
	}
}

// mark_incomplete marks an incomplete definition
fn (mut sa SemanticAnalyzer) mark_incomplete(name string, node NodeBase) {
	sa.defer(node)
	sa.missing_names.last()[name] = true
}

// defer defers analysis
pub fn (mut sa SemanticAnalyzer) defer(debug_context NodeBase) {
	sa.deferred = true
}

// track_incomplete_refs tracks incomplete references
fn (mut sa SemanticAnalyzer) track_incomplete_refs() int {
	// Return current count of missing names
	return sa.missing_names.last().len
}

// found_incomplete_ref checks for the presence of incomplete references
fn (sa SemanticAnalyzer) found_incomplete_ref(tag int) bool {
	// Check if new incomplete refs were added
	return sa.missing_names.last().len > tag
}

// fail reports an error
pub fn (mut sa SemanticAnalyzer) fail(msg string, ctx NodeBase, serious bool, blocker bool) {
	sa.errors.report(ctx.line, ctx.column, msg, serious, blocker)
}

// Helper types
type FuncItem = FuncDef | LambdaExpr | Decorator
type SymbolNode = FuncDef
	| Var
	| TypeInfo
	| Decorator
	| TypeAlias
	| PlaceholderNode
	| OverloadedFuncDef
type Lvalue = NameExpr | MemberExpr | TupleExpr | StarExpr | ListExpr
type Statement = FuncDef
	| ClassDef
	| AssignmentStmt
	| IfStmt
	| WhileStmt
	| ForStmt
	| ReturnStmt
	| Import
	| ImportFrom
	| Block
type Expression = NameExpr | MemberExpr | CallExpr | IntExpr | StrExpr | OpExpr
type NodeBase = Context | Statement | Expression | FuncDef | ClassDef
