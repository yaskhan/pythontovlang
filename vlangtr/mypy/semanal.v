// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:35
module mypy

// Семантический Анализатор (SemanticAnalyzer).
// Главный "Проход 2" (Pass 2) компилятора Mypy.
// Задача: обойти AST (узлы), разрешить все имена, собрать классы, функции в SymbolTables,
// выявить иерархическое наследование, загрузить плагины, создать TypeInfo для классов.

pub struct SemanticAnalyzer {
	NodeTraverser
pub mut:
	modules  map[string]&MypyFile
	options  &Options
	errors   &Errors
	
	// Состояние парсера модулей/прохода
	is_stub_file bool
	is_typeshed_file bool
	final_iteration_ bool
	
	// Контексты текущего обхода (Scope)
	globals ?&SymbolTable
	locals  []&SymbolTable
	
	current_class_node ?&ClassDef
	current_func_node  ?&FuncDef // FuncItem
	
	// Плагины и Анализатор типов
	plugin  PluginInterface = unsafe { nil }
	tvar_scope TypeVarLikeScope
}

// ---------------------------------------------------------------------------
// Implementation of SemanticAnalyzerCoreInterface and SemanticAnalyzerInterface
// ---------------------------------------------------------------------------

pub fn (mut s SemanticAnalyzer) lookup_qualified(name string, ctx Context, suppress_errors bool) ?&SymbolTableNode {
	// Сначала ищем в локальных переменных (в обратном порядке)
	for i := s.locals.len - 1; i >= 0; i-- {
		if node := s.locals[i].symbols[name] {
			return &node
		}
	}
	
	// Затем в глобальных переменных модуля
	if globals := s.globals {
		if node := globals.symbols[name] {
			return &node
		}
	}
	
	// TODO: поиск в builtins если не найдено
	
	if !suppress_errors {
		s.fail('Name "${name}" is not defined', ctx, false, false, none)
	}
	
	return none
}

pub fn (mut s SemanticAnalyzer) lookup_fully_qualified(fullname string) &SymbolTableNode {
	return s.lookup_fully_qualified_or_none(fullname) or {
		panic('Internal error: could not find fully qualified name ${fullname}')
	}
}

pub fn (mut s SemanticAnalyzer) lookup_fully_qualified_or_none(fullname string) ?&SymbolTableNode {
	// TODO: Реализовать глобальный поиск по всем модулям
	return none
}

pub fn (mut s SemanticAnalyzer) fail(msg string, ctx Context, serious bool, blocker bool, code ?&ErrorCode) {
	s.errors.add_error_info(&ErrorInfo{
		file: (s.globals?.symbols['__file__'] or { SymbolTableNode{} }).node?.fullname() or { '' }
		line: ctx.line
		column: ctx.column
		message: msg
		severity: 'error'
	}, code)
}

pub fn (mut s SemanticAnalyzer) note(msg string, ctx Context, code ?&ErrorCode) {
	s.errors.add_error_info(&ErrorInfo{
		file: (s.globals?.symbols['__file__'] or { SymbolTableNode{} }).node?.fullname() or { '' }
		line: ctx.line
		column: ctx.column
		message: msg
		severity: 'note'
	}, code)
}

pub fn (s SemanticAnalyzer) final_iteration() bool {
	return s.final_iteration_
}

pub fn (s SemanticAnalyzer) is_func_scope() bool {
	return s.current_func_node != none
}

pub fn (s SemanticAnalyzer) get_current_type() ?&TypeInfo {
	return s.current_class_node?.info
}

pub fn (mut s SemanticAnalyzer) anal_type(typ MypyTypeNode, tvar_scope ?&TypeVarLikeScope, allow_tuple_literal bool, allow_unbound_tvars bool, allow_typed_dict_special_forms bool, allow_placeholder bool, report_invalid_types bool, prohibit_self_type ?string, prohibit_special_class_field_types ?string) ?MypyTypeNode {
	mut ta := TypeAnalyser{
		api: s
		tvar_scope: tvar_scope or { s.tvar_scope }
		options: *s.options
		plugin: Plugin{} // TODO: plug in real plugin
		allow_tuple_literal: allow_tuple_literal
		allow_unbound_tvars: allow_unbound_tvars
		allow_placeholder: allow_placeholder
		report_invalid_types: report_invalid_types
		prohibit_self_type: prohibit_self_type
		prohibit_special_class_field_types: prohibit_special_class_field_types
	}
	return ta.anal_type(typ, false)
}

// -----------------------------------------------------
// Основные методы входа
// -----------------------------------------------------

pub fn (mut s SemanticAnalyzer) visit_file(mut file_node &MypyFile, fnam string, options &Options) {
	s.options = options
	s.is_stub_file = file_node.is_stub
	s.is_typeshed_file = file_node.is_stub // Упрощенно
	
	s.globals = &file_node.names

	s.locals = []
	
	// Для каждого выражения/оператора (Statement) в модуле
	for mut stmt in file_node.defs {
		s.accept(mut stmt)
	}
}

pub fn (mut s SemanticAnalyzer) accept(mut node Node) {
	node.accept(mut s) or {
		s.errors.add_error_info(&ErrorInfo{message: err.msg()}, none)
		return
	}
}

// -----------------------------------------------------
// Переопределение визиторов
// -----------------------------------------------------

pub fn (mut s SemanticAnalyzer) visit_class_def(mut defn &ClassDef) !string {
	// Подготовка TypeInfo для класса
	if defn.info == none {
		defn.info = &TypeInfo{
			fullname: defn.fullname
			names: SymbolTable{symbols: map[string]SymbolTableNode{}}
			module_name: defn.fullname.rsplit('.', 1)[0]
		}
	}
	info := defn.info?
	
	// Привязываем класс к текущей таблице символов
	s.add_symbol(defn.name, SymbolTableNode{
		kind: .type_info
		node: info
	})
	
	// Анализируем базовые классы
	mut analyzed_bases := []Instance{}
	for base_expr in defn.base_type_exprs {
		if base_expr is NameExpr {
			unbound := UnboundType{
				name: base_expr.name
				base: TypeBase{ctx: base_expr.base.ctx}
			}
			if res := s.anal_type(MypyTypeNode(unbound), none, false, false, false, false, true, none, none) {
				if res is Instance {
					analyzed_bases << res
				}
			}
		}
	}
	info.bases = analyzed_bases
	
	s.current_class_node = defn
	s.locals << &info.names
	
	// Обход тела класса
	for mut stmt in defn.defs.body {
		s.accept(mut stmt)
	}
	
	s.locals.pop()
	s.current_class_node = none
	
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_func_def(mut defn &FuncDef) !string {
	s.add_symbol(defn.name, SymbolTableNode{
		kind: .node
		node: defn
	})
	
	s.current_func_node = defn
	
	// Анализ сигнатуры
	for mut arg in defn.arguments {
		if ann := arg.type_annotation {
			arg.variable.type_ = s.anal_type(ann, none, false, false, false, false, true, none, none)
		}
	}
	
	// Символы внутри функции
	func_locals := &SymbolTable{symbols: map[string]SymbolTableNode{}}
	s.locals << func_locals
	
	// Заносим аргументы в scope
	for mut arg in defn.arguments {
		s.add_symbol(arg.variable.name, SymbolTableNode{
			kind: .node
			node: arg.variable
		})
	}
	
	// Обрабатываем тело
	for mut stmt in defn.body.body {
		s.accept(mut stmt)
	}
	
	s.locals.pop()
	s.current_func_node = none
	
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_assignment_stmt(mut stmt &AssignmentStmt) !string {
	for lvalue in stmt.lvalues {
		if lvalue is NameExpr {
			if !s.is_defined_in_scope(lvalue.name) {
				mut var_node := Var{
					name: lvalue.name
					is_ready: false
				}
				if ann := stmt.type_annotation {
					var_node.type_ = s.anal_type(ann, none, false, false, false, false, true, none, none)
				}
				s.add_symbol(lvalue.name, SymbolTableNode{
					kind: .node
					node: var_node
				})
			}
		}
	}
	s.accept(mut stmt.rvalue)
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_name_expr(mut expr &NameExpr) !string {
	if sym := s.lookup_qualified(expr.name, expr.base.ctx, true) {
		expr.node = sym.node
	}
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_member_expr(mut expr &MemberExpr) !string {
	// Сначала обрабатываем внутреннее выражение (напр. 'os' в 'os.path')
	mut inner_expr := expr.expr
	s.accept(mut inner_expr)
	
	// Если внутреннее выражение разрешилось
	if inner_expr is NameExpr {
		if node := inner_expr.node {
			match node {
				MypyFile {
					if sym := node.names.symbols[expr.name] {
						expr.node = sym.node
					}
				}
				TypeInfo {
					if sym := node.names.symbols[expr.name] {
						expr.node = sym.node
					}
				}
				else {}
			}
		}
	}
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_call_expr(mut expr &CallExpr) !string {
	// Анализируем то, что вызывается
	s.accept(mut expr.callee)
	
	// Анализируем аргументы
	for mut arg in expr.args {
		s.accept(mut arg)
	}
	return ''
}
pub fn (mut s SemanticAnalyzer) visit_import(mut o &Import) !string {
	for id in o.ids {
		local_name := id.alias or { id.name }
		if mod := s.modules[id.name] {
			s.add_symbol(local_name, SymbolTableNode{
				kind: .node
				node: mod
			})
		}
	}
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_import_from(mut o &ImportFrom) !string {
	if mod := s.modules[o.id] {
		for alias in o.names {
			if sym := mod.names.symbols[alias.name] {
				local_name := alias.alias or { alias.name }
				s.add_symbol(local_name, sym)
			}
		}
	}
	return ''
}

pub fn (mut s SemanticAnalyzer) visit_import_all(mut o &ImportAll) !string {
	if mod := s.modules[o.id] {
		for name, sym in mod.names.symbols {
			if !name.starts_with('_') { // Python convention for import *
				s.add_symbol(name, sym)
			}
		}
	}
	return ''
}


pub fn (mut s SemanticAnalyzer) add_symbol(name string, node SymbolTableNode) {
	if s.locals.len > 0 {
		s.locals.last().symbols[name] = node
	} else {
		if mut globals := s.globals {
			globals.symbols[name] = node
		}
	}
}

pub fn (mut s SemanticAnalyzer) is_defined_in_scope(name string) bool {
	if s.locals.len > 0 {
		if name in s.locals.last().symbols { return true }
	} else {
		if globals := s.globals {
			if name in globals.symbols { return true }
		}
	}
	return false
}

// Заглушки для визиторов
pub fn (mut s SemanticAnalyzer) visit_int_expr(mut expr &IntExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_str_expr(mut expr &StrExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_list_expr(mut expr &ListExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_dict_expr(mut expr &DictExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_return_stmt(mut stmt &ReturnStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_if_stmt(mut stmt &IfStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_for_stmt(mut stmt &ForStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_while_stmt(mut stmt &WhileStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_break_stmt(mut stmt &BreakStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_continue_stmt(mut stmt &ContinueStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_pass_stmt(mut stmt &PassStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_expression_stmt(mut stmt &ExpressionStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_unary_expr(mut expr &UnaryExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_op_expr(mut expr &OpExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_comparison_expr(mut expr &ComparisonExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_bool_expr(mut expr &BoolExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_float_expr(mut expr &FloatExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_none_expr(mut expr &NoneExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_ellipsis(mut expr &EllipsisExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_tuple_expr(mut expr &TupleExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_slice_expr(mut expr &SliceExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_index_expr(mut expr &IndexExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_bin_expr(mut expr &BinExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_mypy_file(mut o &MypyFile) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_var(mut o &Var) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_type_alias(mut o &TypeAlias) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_placeholder_node(mut o &PlaceholderNode) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_block(mut o &Block) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_operator_assignment_stmt(mut o &OperatorAssignmentStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_assert_stmt(mut o &AssertStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_global_decl(mut o &GlobalDecl) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_nonlocal_decl(mut o &NonlocalDecl) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_overloaded_func_def(mut o &OverloadedFuncDef) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_decorator(mut o &Decorator) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_with_stmt(mut o &WithStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_del_stmt(mut o &DelStmt) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_bytes_expr(mut o &BytesExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_complex_expr(mut o &ComplexExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_star_expr(mut o &StarExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_yield_expr(mut o &YieldExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_yield_from_expr(mut o &YieldFromExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_super_expr(mut o &SuperExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_assignment_expr(mut o &AssignmentExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_template_str_expr(mut o &TemplateStrExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_set_expr(mut o &SetExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_list_comprehension(mut o &ListComprehension) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_set_comprehension(mut o &SetComprehension) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_dictionary_comprehension(mut o &DictionaryComprehension) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_generator_expr(mut o &GeneratorExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_conditional_expr(mut o &ConditionalExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_type_var_expr(mut o &TypeVarExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_paramspec_expr(mut o &ParamSpecExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_type_var_tuple_expr(mut o &TypeVarTupleExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_type_alias_expr(mut o &TypeAliasExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_namedtuple_expr(mut o &NamedTupleExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_enum_call_expr(mut o &EnumCallExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_typeddict_expr(mut o &TypedDictExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_newtype_expr(mut o &NewTypeExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_promote_expr(mut o &PromoteExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_await_expr(mut o &AwaitExpr) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_as_pattern(mut o &AsPattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_or_pattern(mut o &OrPattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_value_pattern(mut o &ValuePattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_singleton_pattern(mut o &SingletonPattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_sequence_pattern(mut o &SequencePattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_starred_pattern(mut o &StarredPattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_mapping_pattern(mut o &MappingPattern) !string { return '' }
pub fn (mut s SemanticAnalyzer) visit_class_pattern(mut o &ClassPattern) !string { return '' }
