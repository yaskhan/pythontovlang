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
	cur_type                             ?&TypeInfo
	type_stack                           []?&TypeInfo
	tvar_scope                           TypeVarLikeScope
	options                              Options
	function_stack                       []FuncItem
	progress                             bool
	deferred                             bool
	incomplete                           bool
	final_iteration                      bool
	missing_names                        []map[string]bool
	loop_depth                           []int
	cur_mod_id                           string
	is_stub_file                         bool
	is_typeshed_stub_file                bool
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
		cur_type:                             none
		type_stack:                           []?&TypeInfo{}
		tvar_scope:                           TypeVarLikeScope{}
		options:                              options
		function_stack:                       []FuncItem{}
		progress:                             false
		deferred:                             false
		incomplete:                           false
		final_iteration:                      false
		missing_names:                        [map[string]bool{}]
		loop_depth:                           [0]
		cur_mod_id:                           ''
		is_stub_file:                         false
		is_typeshed_stub_file:                false
		imports:                              map[string]bool{}
		errors:                               errors
		plugin:                               plugin
		statement:                            none
		cur_mod_node:                         none
		msg:                                  MessageBuilder{
			errors:  &errors
			options: &options
		}
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
pub fn (sa SemanticAnalyzer) type() ?&TypeInfo {
	return sa.cur_type
}

// is_stub_file checks if the file is a stub
pub fn (sa SemanticAnalyzer) is_stub_file() bool {
	return sa.is_stub_file
}

// is_typeshed_stub_file checks if the file is a stub from typeshed
pub fn (sa SemanticAnalyzer) is_typeshed_stub_file() bool {
	return sa.is_typeshed_stub_file
}

// final_iteration checks if this is the final iteration
pub fn (sa SemanticAnalyzer) final_iteration() bool {
	return sa.final_iteration
}

// prepare_file prepares a file for analysis
pub fn (mut sa SemanticAnalyzer) prepare_file(mut file_node MypyFile) {
	if 'builtins' in sa.modules {
		file_node.names.symbols['__builtins__'] = SymbolTableNode{
			kind: gdef
			node: SymbolNodeRef(sa.modules['builtins'])
		}
	}
	if file_node.fullname == 'builtins' {
		sa.prepare_builtins_namespace(mut file_node)
	}
}

// prepare_builtins_namespace adds special definitions to builtins
fn (mut sa SemanticAnalyzer) prepare_builtins_namespace(mut file_node MypyFile) {
	mut names := file_node.names

	// Add empty definitions for base classes
	for name in core_builtin_classes {
		cdef := ClassDef{
			name: name
			defs: Block{
				body: []
			}
		}
		mut info := new_type_info(mut names, cdef, 'builtins')
		info.fullname = 'builtins.${name}'
		names.symbols[name] = SymbolTableNode{
			kind: gdef
			node: SymbolNodeRef(info)
		}
	}

	// Add special variables
	bool_node := names.symbols['bool'].node or { panic('bool not found') }
	bool_info := bool_node as TypeInfo

	special_names := ['None', 'reveal_type', 'reveal_locals', 'True', 'False', '__debug__']
	special_types := [
		MypyTypeNode(NoneType{}),
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
		MypyTypeNode(AnyType{
			type_of_any: .special_form
		}),
		MypyTypeNode(Instance{
			type_:     &bool_info
			args:      []
			type_name: 'builtins.bool'
		}),
		MypyTypeNode(Instance{
			type_:     &bool_info
			args:      []
			type_name: 'builtins.bool'
		}),
		MypyTypeNode(Instance{
			type_:     &bool_info
			args:      []
			type_name: 'builtins.bool'
		}),
	]

	for i, name in special_names {
		typ := special_types[i]
		mut v := Var{
			name:     name
			fullname: 'builtins.${name}'
			type_:    typ
		}
		names.symbols[name] = SymbolTableNode{
			kind: gdef
			node: SymbolNodeRef(v)
		}
	}
}

// visit_mypy_file handles MypyFile
pub fn (mut sa SemanticAnalyzer) visit_mypy_file(mut file_node MypyFile) !string {
	sa.cur_mod_node = file_node
	sa.cur_mod_id = file_node.fullname

	sa.globals = file_node.names

	for mut defn in file_node.defs {
		defn.accept(mut sa)!
	}
	return ''
}

// visit_func_def handles function definition
pub fn (mut sa SemanticAnalyzer) visit_func_def(mut defn FuncDef) !string {
	sa.statement = Statement(defn)

	for arg in defn.arguments {
		if arg.initializer != none {
			// TODO: accept arg.initializer
		}
	}

	defn.is_conditional = sa.block_depth.last() > 0
	defn.fullname = sa.qualified_name(defn.name)

	if !sa.recurse_into_functions() || sa.function_stack.len > 0 {
		if !defn.is_decorated && !defn.is_overload {
			sa.add_function_to_symbol_table(mut defn)
		}
	}

	if !sa.recurse_into_functions() && !defn.def_or_infer_vars {
		return ''
	}

	sa.function_stack << defn
	sa.analyze_func_def(mut defn)!
	sa.function_stack.pop()
	return ''
}

// analyze_func_def analyzes function definition
fn (mut sa SemanticAnalyzer) analyze_func_def(mut defn FuncDef) !string {
	if sa.push_type_args(defn.type_params, defn.base) == none {
		sa.defer(defn.base)
		return ''
	}

	sa.function_stack << defn

	mut has_self_type := false
	if defn.type_ != none {
		if defn.type_ is CallableType {
			sa.update_function_type_variables(defn.type_ as CallableType, defn)
		}
	}

	sa.function_stack.pop()

	if sa.is_class_scope() {
		defn.info = sa.cur_type
	}

	// TODO: function signature analysis
	sa.analyze_function_body(mut defn)!
	sa.pop_type_args(defn.type_params)
	return ''
}

// visit_class_def handles class definition
pub fn (mut sa SemanticAnalyzer) visit_class_def(mut defn ClassDef) !string {
	sa.statement = Statement(defn)
	sa.analyze_class(mut defn)!
	return ''
}

// analyze_class analyzes class definition
fn (mut sa SemanticAnalyzer) analyze_class(mut defn ClassDef) !string {
	fullname := sa.qualified_name(defn.name)

	if defn.info == none && !sa.is_core_builtin_class(defn) {
		placeholder := PlaceholderNode{
			fullname:         fullname
			node:             SymbolNodeRef(*defn)
			becomes_typeinfo: true
		}
		sa.add_symbol(defn.name, placeholder, defn.get_context(), true, false, true)
	}

	// TODO: full class analysis implementation
	sa.prepare_class_def(mut defn)!
	sa.setup_type_vars(defn, [])

	sa.enter_class(defn.info or { return '' })
	defn.defs.accept(mut sa)!
	sa.leave_class()
	return ''
}

// visit_import handles import
pub fn (mut sa SemanticAnalyzer) visit_import(mut i Import) !string {
	sa.statement = Statement(i)
	for item in i.ids {
		id := item.name
		as_id := item.alias
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		base_id := if as_val := as_id { id } else { id.split('.')[0] }
		imported_id := if as_val := as_id { as_val } else { base_id }
		module_public := use_implicit_reexport || (as_id != none && id == (as_id or { '' }))

		if base_id in sa.modules {
			node := sa.modules[base_id]
			kind := if sa.is_func_scope() {
				ldef
			} else if sa.cur_type != none {
				mdef
			} else {
				gdef
			}
			symbol := SymbolTableNode{
				kind:          kind
				node:          SymbolNodeRef(node)
				module_public: module_public
				module_hidden: !module_public
			}
			sa.add_imported_symbol(imported_id, symbol, i, module_public, !module_public)
		} else {
			sa.add_unknown_imported_symbol(imported_id, i.base, base_id, module_public, !module_public)
		}
	}
	return ''
}

// visit_import_from handles from ... import
pub fn (mut sa SemanticAnalyzer) visit_import_from(mut imp ImportFrom) !string {
	sa.statement = Statement(imp)
	mod_id := sa.correct_relative_import(imp)
	mod := sa.modules[mod_id] or { return '' }

	for item in imp.names {
		id := item.name
		as_id := item.alias
		fullname := '${mod_id}.${id}'
		sa.set_future_import_flags(fullname)

		mut node := ?SymbolTableNode(none)
		if id in mod.names.symbols {
			node = mod.names.symbols[id]
		}

		imported_id := if as_val := as_id { as_val } else { id }
		use_implicit_reexport := !sa.is_stub_file() && sa.options.implicit_reexport
		module_public := use_implicit_reexport || (as_id != none && id == (as_id or { '' }))

		if it_node := node {
			sa.add_imported_symbol(imported_id, it_node, imp.base, module_public,
				!module_public)
		} else {
			sa.report_missing_module_attribute(mod_id, id, imported_id, imp.base)
		}
	}
	return ''
}

// visit_assignment_stmt handles assignment
pub fn (mut sa SemanticAnalyzer) visit_assignment_stmt(mut s AssignmentStmt) !string {
	sa.statement = Statement(s)

	if sa.analyze_identity_global_assignment(s) {
		return ''
	}

	tag := sa.track_incomplete_refs()
	// TODO: analyze rvalue
	s.rvalue.accept(mut sa)!

	if sa.found_incomplete_ref(tag) {
		for expr in sa.names_modified_by_assignment(s) {
			sa.mark_incomplete(expr.name, expr.base)
		}
		return ''
	}

	// TODO: check special forms (type alias, TypeVar, etc.)
	s.is_final_def = sa.unwrap_final(s)
	for mut lv_expr in s.lvalues {
		if mut lv := lv_expr.as_lvalue() {
			sa.analyze_lvalue(mut lv, false, false)!
		}
	}
	// TODO: additional checks
	return ''
}

// visit_if_stmt handles if
pub fn (mut sa SemanticAnalyzer) visit_if_stmt(mut s IfStmt) !string {
	sa.statement = Statement(s)
	// TODO: infer_reachability_of_if_statement
	for i in 0 .. s.expr.len {
		s.expr[i].accept(mut sa)!
		sa.visit_block(mut s.body[i])!
	}
	sa.visit_block_maybe(mut s.else_body)!
	return ''
}

// visit_block handles block
pub fn (mut sa SemanticAnalyzer) visit_block(mut b Block) !string {
	if b.is_unreachable {
		return ''
	}
	sa.block_depth[sa.block_depth.len - 1]++
	for mut s in b.body {
		sa.accept(mut s)!
	}
	sa.block_depth[sa.block_depth.len - 1]--
	return ''
}

// visit_block_maybe handles optional block
pub fn (mut sa SemanticAnalyzer) visit_block_maybe(mut b ?Block) !string {
	if mut it_b := b {
		sa.visit_block(mut it_b)!
	}
	return ''
}

// visit_while_stmt handles while
pub fn (mut sa SemanticAnalyzer) visit_while_stmt(mut s WhileStmt) !string {
	sa.statement = Statement(s)
	s.expr.accept(mut sa)!
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(mut s.body)!
	sa.visit_block_maybe(mut s.else_body)!
	sa.loop_depth[sa.loop_depth.len - 1]--
	return ''
}

// visit_for_stmt handles for
pub fn (mut sa SemanticAnalyzer) visit_for_stmt(mut s ForStmt) !string {
	if s.is_async {
		// TODO: async check
	}
	sa.statement = Statement(s)
	s.expr.accept(mut sa)!
	sa.analyze_lvalue(mut s.index, false, s.index_type != none)
	sa.loop_depth[sa.loop_depth.len - 1]++
	sa.visit_block(mut s.body)!
	sa.loop_depth[sa.loop_depth.len - 1]--
	sa.visit_block_maybe(mut s.else_body)!
	return ''
}

// visit_return_stmt handles return
pub fn (mut sa SemanticAnalyzer) visit_return_stmt(mut s ReturnStmt) !string {
	if !sa.is_func_scope() {
		sa.fail('"return" outside function', s.get_context(), false, false, none)
	}
	if s.expr != none {
		s.expr.accept(mut sa)!
	}
	return ''
}

// visit_break_stmt handles break
pub fn (mut sa SemanticAnalyzer) visit_break_stmt(mut s BreakStmt) !string {
	sa.statement = Statement(s)
	if sa.loop_depth.last() == 0 {
		sa.fail('"break" outside loop', s.get_context(), true, true, none)
	}
	return ''
}

// visit_continue_stmt handles continue
pub fn (mut sa SemanticAnalyzer) visit_continue_stmt(mut s ContinueStmt) !string {
	sa.statement = Statement(s)
	if sa.loop_depth.last() == 0 {
		sa.fail('"continue" outside loop', s.get_context(), true, true, none)
	}
	return ''
}

// visit_try_stmt handles try
pub fn (mut sa SemanticAnalyzer) visit_try_stmt(mut s TryStmt) !string {
	sa.statement = Statement(s)
	s.body.accept(mut sa)!
	for mut handler in s.handlers {
		sa.visit_block(mut handler)!
	}
	if mut else_body := s.else_body {
		sa.visit_block(mut else_body)!
	}
	if mut finally_body := s.finally_body {
		sa.visit_block(mut finally_body)!
	}
	return ''
}

// visit_decorator handles decorator
pub fn (mut sa SemanticAnalyzer) visit_decorator(mut dec Decorator) !string {
	sa.statement = Statement(dec)
	// dec.decorators is initialized already
	dec.func.is_conditional = sa.block_depth.last() > 0

	if !dec.is_overload {
		sa.add_symbol(dec.func.name, SymbolNodeRef(*dec), dec.get_context(), true, false, true)
	}

	dec.func.fullname = sa.qualified_name(dec.func.name)
	dec.var_.fullname = sa.qualified_name(dec.func.name)

	for mut d in dec.decorators {
		d.accept(mut sa)!
	}

	// TODO: handle special decorators (abstractmethod, staticmethod, etc.)
	return ''
}

// visit_expression_stmt handles expression statement
pub fn (mut sa SemanticAnalyzer) visit_expression_stmt(mut s ExpressionStmt) !string {
	sa.statement = Statement(s)
	s.expr.accept(mut sa)!
	return ''
}

// visit_name_expr handles name
pub fn (mut sa SemanticAnalyzer) visit_name_expr(mut expr NameExpr) !string {
	n := sa.lookup(expr.name, expr.base)
	if n != none {
		sa.bind_name_expr(mut expr, n)
	}
	return ''
}

// visit_member_expr handles member access
pub fn (mut sa SemanticAnalyzer) visit_member_expr(mut expr MemberExpr) !string {
	expr.expr.accept(mut sa)!
	// TODO: handle member access
	return ''
}

// visit_call_expr handles call
pub fn (mut sa SemanticAnalyzer) visit_call_expr(mut expr CallExpr) !string {
	expr.callee.accept(mut sa)!
	// TODO: handle special calls (cast, reveal_type, etc.)
	for mut a in expr.args {
		a.accept(mut sa)!
	}
	return ''
}

// visit_int_expr handles int literal
pub fn (mut sa SemanticAnalyzer) visit_int_expr(mut expr IntExpr) !string {
	// Do nothing
	return ''
}

// visit_str_expr handles string literal
pub fn (mut sa SemanticAnalyzer) visit_str_expr(mut expr StrExpr) !string {
	// Do nothing
	return ''
}

// visit_var handles variable
pub fn (mut sa SemanticAnalyzer) visit_var(mut o Var) !string {
	// TODO: visit_var
	return ''
}

// visit_type_alias handles type alias
pub fn (mut sa SemanticAnalyzer) visit_type_alias(mut o TypeAlias) !string {
	// TODO: visit_type_alias
	return ''
}

// visit_placeholder_node handles placeholder node
pub fn (mut sa SemanticAnalyzer) visit_placeholder_node(mut o PlaceholderNode) !string {
	// TODO: visit_placeholder_node
	return ''
}

// visit_type_info handles type info
pub fn (mut sa SemanticAnalyzer) visit_type_info(mut o TypeInfo) !string {
	// TODO: visit_type_info
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_bytes_expr(mut o BytesExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_float_expr(mut o FloatExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_complex_expr(mut o ComplexExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_ellipsis(mut o EllipsisExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_star_expr(mut o StarExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_yield_from_expr(mut o YieldFromExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_yield_expr(mut o YieldExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_op_expr(mut o OpExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_comparison_expr(mut o ComparisonExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_cast_expr(mut o CastExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_assert_type_expr(mut o AssertTypeExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_reveal_expr(mut o RevealExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_super_expr(mut o SuperExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_unary_expr(mut o UnaryExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_assignment_expr(mut o AssignmentExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_index_expr(mut o IndexExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_application(mut o TypeApplication) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_lambda_expr(mut o LambdaExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_list_comprehension(mut o ListComprehension) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_set_comprehension(mut o SetComprehension) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_dictionary_comprehension(mut o DictionaryComprehension) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_generator_expr(mut o GeneratorExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_list_expr(mut o ListExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_dict_expr(mut o DictExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_template_str_expr(mut o TemplateStrExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_tuple_expr(mut o TupleExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_set_expr(mut o SetExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_slice_expr(mut o SliceExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_conditional_expr(mut o ConditionalExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_var_expr(mut o TypeVarExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_paramspec_expr(mut o ParamSpecExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_var_tuple_expr(mut o TypeVarTupleExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_alias_expr(mut o TypeAliasExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_namedtuple_expr(mut o NamedTupleExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_enum_call_expr(mut o EnumCallExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_typeddict_expr(mut o TypedDictExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_newtype_expr(mut o NewTypeExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_promote_expr(mut o PromoteExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_temp_node(mut o TempNode) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_await_expr(mut o AwaitExpr) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_with_stmt(mut o WithStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_del_stmt(mut o DelStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_overloaded_func_def(mut o OverloadedFuncDef) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_global_decl(mut o GlobalDecl) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_nonlocal_decl(mut o NonlocalDecl) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_import_all(mut o ImportAll) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_operator_assignment_stmt(mut o OperatorAssignmentStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_assert_stmt(mut o AssertStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_raise_stmt(mut o RaiseStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_alias_stmt(mut o TypeAliasStmt) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_match_stmt(mut o MatchStmt) !string {
	return ''
}

// Patterns
pub fn (mut sa SemanticAnalyzer) visit_as_pattern(mut o AsPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_or_pattern(mut o OrPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_value_pattern(mut o ValuePattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_singleton_pattern(mut o SingletonPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_sequence_pattern(mut o SequencePattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_starred_pattern(mut o StarredPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_mapping_pattern(mut o MappingPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_class_pattern(mut o ClassPattern) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_argument(mut o Argument) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_type_param(mut o TypeParam) !string {
	return ''
}

pub fn (mut sa SemanticAnalyzer) visit_lvalue(mut o Lvalue) !string {
	match mut o {
		ListExpr { sa.visit_list_expr(mut o)! }
		MemberExpr { sa.visit_member_expr(mut o)! }
		NameExpr { sa.visit_name_expr(mut o)! }
		StarExpr { sa.visit_star_expr(mut o)! }
		TupleExpr { sa.visit_tuple_expr(mut o)! }
	}
	return ''
}

// visit_pass_stmt handles pass
pub fn (sa SemanticAnalyzer) visit_pass_stmt(mut s PassStmt) !string {
	// Do nothing
	return ''
}

// accept accepts a node
pub fn (mut sa SemanticAnalyzer) accept(mut node Node) {
	node.accept(mut sa) or {}
}

// lookup looks up a name
pub fn (mut sa SemanticAnalyzer) lookup(name string, context NodeBase) ?SymbolTableNode {
	// Search in local scopes
	for i := sa.locals.len - 1; i >= 0; i-- {
		if locals := sa.locals[i] {
			if name in locals.symbols {
				return locals.symbols[name]
			}
		}
	}

	// Search in global scope
	if name in sa.globals.symbols {
		return sa.globals.symbols[name]
	}

	// Search in builtins
	if 'builtins' in sa.modules {
		builtins := sa.modules['builtins']
		if name in builtins.names.symbols {
			return builtins.names.symbols[name]
		}
	}

	return none
}

// lookup_qualified looks up a qualified name
pub fn (mut sa SemanticAnalyzer) lookup_qualified(name string, ctx NodeBase, suppress_errors bool) ?SymbolTableNode {
	if !name.contains('.') {
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
		current_node := current.node or { return none }
		if current_node is TypeInfo {
			if part in current_node.names.symbols {
				current = current_node.names.symbols[part]
			} else {
				return none
			}
		} else if current_node is MypyFile {
			if part in current_node.names.symbols {
				current = current_node.names.symbols[part]
			} else {
				return none
			}
		} else {
			return none
		}
	}

	return current
}

fn (mut sa SemanticAnalyzer) bind_name_expr(mut expr NameExpr, sym SymbolTableNode) {
	expr.kind = sym.kind
	if node := sym.node {
		expr.node = node.as_mypy_node()
		// expr.fullname = node.fullname() // fullname() is currently removed to avoid panic
	}
}

// analyze_lvalue analyzes lvalue
pub fn (mut sa SemanticAnalyzer) analyze_lvalue(mut lval Lvalue, nested bool, explicit_type bool) !string {
	if mut lval is NameExpr {
		// TODO: analyze lvalue
	} else if mut lval is MemberExpr {
		lval.accept(mut sa)!
	} else if mut lval is TupleExpr {
		for mut item in lval.items {
			if mut l := item.as_lvalue() {
				sa.analyze_lvalue(mut l, true, explicit_type)!
			}
		}
	}
	return ''
}

// names_modified_by_assignment returns names modified in assignment
fn (mut sa SemanticAnalyzer) names_modified_by_assignment(s AssignmentStmt) []NameExpr {
	mut result := []NameExpr{}
	for lval_expr in s.lvalues {
		if l := lval_expr.as_lvalue() {
			for name in sa.names_modified_in_lvalue(l) {
				result << name
			}
		}
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
			if l := item.as_lvalue() {
				result << sa.names_modified_in_lvalue(l)
			}
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
			if ann := s.type_annotation {
				if ann is UnboundType {
					if ann.name == 'Final' {
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
	if lval_name == rval_name && lval_name in sa.globals.symbols {
		return true
	}

	return false
}

// qualified_name returns the qualified name
fn (sa SemanticAnalyzer) qualified_name(name string) string {
	if cur_type := sa.cur_type {
		return cur_type.fullname + '.' + name
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
	return sa.cur_type != none && !sa.is_func_scope()
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
fn (mut sa SemanticAnalyzer) enter_class(info &TypeInfo) {
	sa.type_stack << sa.cur_type
	sa.locals << none
	sa.scope_stack << scope_class
	sa.block_depth << -1
	sa.loop_depth << [0]
	sa.cur_type = info
	sa.missing_names << map[string]bool{}
}

// leave_class exits a class
fn (mut sa SemanticAnalyzer) leave_class() {
	sa.block_depth.pop()
	sa.loop_depth.pop()
	sa.locals.pop()
	sa.scope_stack.pop()
	sa.cur_type = sa.type_stack.pop()
	sa.missing_names.pop()
}

// add_function_to_symbol_table adds a function to the symbol table
fn (mut sa SemanticAnalyzer) add_function_to_symbol_table(mut func_def FuncDef) {
	if sa.is_class_scope() {
		func_def.info = sa.cur_type
	}
	func_def.fullname = sa.qualified_name(func_def.name)
	sa.add_symbol(func_def.name, SymbolNodeRef(*func_def), func_def.get_context(), true, false, true)
}

// add_symbol adds a symbol
pub fn (mut sa SemanticAnalyzer) add_symbol(name string, node SymbolNodeRef, context Context, module_public bool, module_hidden bool, can_defer bool) bool {
	// Check if symbol already exists in current scope
	if sa.locals.len > 0 {
		if mut locals := sa.locals.last() {
			if name in locals.symbols {
				// Symbol already defined in current scope
				return false
			}
			locals.symbols[name] = SymbolTableNode{
				kind: 0 // LDEF for local
				node: node
			}
			return true
		}
	}

	// Add to global scope
	if name in sa.globals.symbols {
		existing := sa.globals.symbols[name]
		if existing.node != none {
			sa.fail('Name "${name}" already defined', context, false, false, none)
			return false
		}
	}

	sa.globals.symbols[name] = SymbolTableNode{
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
		if mut locals := sa.locals.last() {
			locals.symbols[name] = sym
			return
		}
	}

	// Add to global scope
	sa.globals.symbols[name] = sym
}

// add_unknown_imported_symbol adds an unknown imported symbol
fn (mut sa SemanticAnalyzer) add_unknown_imported_symbol(name string, context NodeBase, target_name string, module_public bool, module_hidden bool) {
	// Create a placeholder for unknown import
	any_type := AnyType{
		type_of_any: TypeOfAny.from_error
	}

	// Create a Var node with Any type
	mut var := Var{
		name:  name
		type_: any_type
	}
	var.fullname = target_name

	sym := SymbolTableNode{
		kind:          0
		node:          var
		module_public: module_public
		module_hidden: module_hidden
	}

	// Add to current scope
	if sa.locals.len > 0 {
		if locals := sa.locals.last() {
			return
		}
	}

	// Add to global scope
	sa.globals.symbols[name] = sym
}

// report_missing_module_attribute reports a missing module attribute
fn (mut sa SemanticAnalyzer) report_missing_module_attribute(module_id string, source_id string, imported_id string, context NodeBase) {
	sa.fail('Module "${module_id}" has no attribute "${source_id}"', context.get_context(), false, false, none)
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
	// TODO: handle future imports if field is added to MypyFile
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
		// Add type variable to scope
		tvar := TypeVarType{
			name:        ta.name
			upper_bound: ta.upper_bound or { AnyType{type_of_any: TypeOfAny.unannotated} }
		}

		sa.tvar_scope.bind_existing(tvar)
	}

	return names
}

// pop_type_args removes type args
fn (mut sa SemanticAnalyzer) pop_type_args(type_args []TypeParam) {
	for ta in type_args {
		sa.tvar_scope.scope.delete(ta.name)
	}
}

// update_function_type_variables updates function type variables
fn (mut sa SemanticAnalyzer) update_function_type_variables(fun_type CallableType, defn FuncItem) bool {
	// Process type variables from function signature
	if fun_type.variables.len > 0 {
		for tvar in fun_type.variables {
			if tvar is TypeVarType {
				sa.tvar_scope.bind_existing(tvar)
			}
		}
		return true
	}
	return false
}

// analyze_function_body analyzes a function body
fn (mut sa SemanticAnalyzer) analyze_function_body(mut defn FuncItem) ! {
	// Enter function scope
	sa.scope_stack << scope_func
	sa.block_depth << 0
	sa.loop_depth << 0
	sa.locals << SymbolTable{
		symbols: map[string]SymbolTableNode{}
	}
	sa.missing_names << map[string]bool{}

	// Add function arguments to scope
	match mut defn {
		FuncDef {
			for mut arg in defn.arguments {
				mut var := Var{
					name:  arg.variable.name
					type_: arg.variable.type_
				}
				var.fullname = sa.qualified_name(arg.variable.name)
				sa.add_symbol(arg.variable.name, SymbolNodeRef(var), arg.variable.get_context(), true, false, true)
			}
		}
		else {}
	}

	// Analyze function body
	match mut defn {
		FuncDef {
			defn.body.accept(mut sa)!
		}
		Decorator {
			defn.func.body.accept(mut sa)!
		}
		OverloadedFuncDef {
			// No body
		}
		LambdaExpr {
			defn.body.accept(mut sa)!
		}
	}

	// Leave function scope
	sa.scope_stack.pop()
	sa.locals.pop()
	sa.missing_names.pop()
	sa.block_depth.pop()
	sa.loop_depth.pop()
}

// prepare_class_def prepares a class definition
fn (mut sa SemanticAnalyzer) prepare_class_def(mut defn ClassDef) ! {
	// Create TypeInfo if not exists
	if defn.info == none {
		fullname := sa.qualified_name(defn.name)
		mut info := new_type_info(mut sa.globals, defn, sa.cur_mod_id)
		info.fullname = fullname
		defn.info = info
	}

	// Process base classes
	for mut base_expr in defn.base_type_exprs {
		base_expr.accept(mut sa)!
	}

	// Process decorators
	for mut dec in defn.decorators {
		dec.accept(mut sa)!
	}
}

// setup_type_vars sets up type variables
fn (mut sa SemanticAnalyzer) setup_type_vars(defn ClassDef, tvar_defs []TypeVarLikeType) {
	// Add type variables from class definition to scope
	for tvar_def in tvar_defs {
		if tvar_def is TypeVarType {
			sa.tvar_scope.bind_existing(tvar_def)
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
pub fn (mut sa SemanticAnalyzer) fail(msg string, ctx Context, serious bool, blocker bool, code ?&ErrorCode) {
	mut severity := 'error'
	if !serious {
		severity = 'note'
	}
	sa.errors.report(ctx.line, ctx.column, msg, none, severity, blocker, false)
}

pub fn (mut sa SemanticAnalyzer) report_hang() {
	// TODO: implement hang reporting
}

// Helper types
// new_type_info — helper for creating TypeInfo
pub fn new_type_info(mut names SymbolTable, defn ClassDef, module_name string) &TypeInfo {
	return &TypeInfo{
		name:        defn.name
		fullname:    module_name + '.' + defn.name
		module_name: module_name
		names:       names
		defn:        &defn
	}
}
