// stats.v — Utilities for calculating and reporting statistics about types
// Translated from mypy/stats.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 12:30

module mypy

import os

// Точность типов
pub const type_empty = 0
pub const type_unanalyzed = 1 // тип не типизированного кода
pub const type_precise = 2
pub const type_imprecise = 3
pub const type_any = 4

pub const precision_names = ['empty', 'unanalyzed', 'precise', 'imprecise', 'any']

// ImportStmt — sum-type для импортов
pub type ImportStmt = ImportFrom | ImportAll

// StatisticsVisitor — посетитель для сбора статистики о типах
pub struct StatisticsVisitor {
pub mut:
	inferred           bool
	filename           string
	modules            map[string]MypyFile
	typemap            ?map[string]MypyTypeNode
	all_nodes          bool
	visit_untyped_defs bool

	num_precise_exprs   int
	num_imprecise_exprs int
	num_any_exprs       int

	num_simple_types   int
	num_generic_types  int
	num_tuple_types    int
	num_function_types int
	num_typevar_types  int
	num_complex_types  int
	num_any_types      int

	line     int
	line_map map[int]int

	type_of_any_counter map[int]int // Counter[int] → map[int]int
	any_line_map        map[int][]AnyType

	// Для каждой области видимости (верхний уровень/функция), была ли область
	// типизирована (аннотированная функция).
	checked_scopes []bool

	output []string

	// Внутренние поля
	cur_mod_node MypyFile
	cur_mod_id   string
}

// new_statistics_visitor создаёт новый StatisticsVisitor
pub fn new_statistics_visitor(inferred bool,
	filename string,
	modules map[string]MypyFile,
	typemap ?map[string]MypyTypeNode,
	all_nodes bool,
	visit_untyped_defs bool) StatisticsVisitor {
	mut v := StatisticsVisitor{
		inferred:            inferred
		filename:            filename
		modules:             modules
		typemap:             typemap
		all_nodes:           all_nodes
		visit_untyped_defs:  visit_untyped_defs
		line:                -1
		line_map:            map[int]int{}
		type_of_any_counter: map[int]int{}
		any_line_map:        map[int][]AnyType{}
		checked_scopes:      [true]
		output:              []string{}
	}
	return v
}

// visit_mypy_file посещает корневой узел файла
pub fn (mut v StatisticsVisitor) visit_mypy_file(o MypyFile) {
	v.cur_mod_node = o
	v.cur_mod_id = o.fullname
	// Продолжаем обход
}

// visit_import_from обрабатывает импорт from ... import ...
pub fn (mut v StatisticsVisitor) visit_import_from(imp ImportFrom) {
	v.process_import(imp)
}

// visit_import_all обрабатывает импорт import *
pub fn (mut v StatisticsVisitor) visit_import_all(imp ImportAll) {
	v.process_import(imp)
}

// process_import обрабатывает импорт и записывает точность
pub fn (mut v StatisticsVisitor) process_import(imp ImportStmt) {
	// import_id, ok := correct_relative_import(...)
	// Упрощённая версия:
	mut kind := type_precise
	if imp.id !in v.modules {
		kind = type_any
	}
	v.record_line(imp.line, kind)
}

// visit_import обрабатывает обычный import
pub fn (mut v StatisticsVisitor) visit_import(imp Import) {
	mut all_in_modules := true
	for id, _ in imp.ids {
		if id !in v.modules {
			all_in_modules = false
			break
		}
	}
	kind := type_precise
	if !all_in_modules {
		kind = type_any
	}
	v.record_line(imp.line, kind)
}

// visit_func_def посещает определение функции
pub fn (mut v StatisticsVisitor) visit_func_def(o FuncDef) {
	v.enter_scope(o)
	v.line = o.line

	if o.type != none {
		// if o.type {
		//     assert isinstance(o.type, CallableType)
		//     sig = o.type
		//     arg_types = sig.arg_types
		//     if sig.arg_names and sig.arg_names[0] == "self" and not self.inferred:
		//         arg_types = arg_types[1:]
		//     for arg in arg_types:
		//         self.type(arg)
		//     self.type(sig.ret_type)
		// }
	} else if v.all_nodes {
		v.record_line(v.line, type_any)
	}

	// if not o.is_dynamic() or v.visit_untyped_defs {
	//     super().visit_func_def(o)
	// }

	v.exit_scope()
}

// enter_scope входит в область видимости функции
pub fn (mut v StatisticsVisitor) enter_scope(o FuncDef) {
	checked := o.type != none && v.checked_scopes.last() or { true }
	v.checked_scopes << checked
}

// exit_scope выходит из области видимости
pub fn (mut v StatisticsVisitor) exit_scope() {
	if v.checked_scopes.len > 0 {
		v.checked_scopes.pop()
	}
}

// is_checked_scope возвращает true, если текущая область видимости типизирована
pub fn (v StatisticsVisitor) is_checked_scope() bool {
	return v.checked_scopes.last() or { true }
}

// visit_class_def посещает определение класса
pub fn (mut v StatisticsVisitor) visit_class_def(o ClassDef) {
	v.record_line(o.line, type_precise) // TODO: Look at base classes
	// While base_type_exprs are technically expressions, type analyzer does not visit them
	for d in o.decorators {
		// d.accept(self)
	}
	// o.defs.accept(self)
}

// visit_type_application посещает применение типа
pub fn (mut v StatisticsVisitor) visit_type_application(o TypeApplication) {
	v.line = o.line
	for t in o.types {
		v.type_node(t)
	}
}

// visit_assignment_stmt посещает оператор присваивания
pub fn (mut v StatisticsVisitor) visit_assignment_stmt(o AssignmentStmt) {
	v.line = o.line
	// if isinstance(o.rvalue, nodes.CallExpr) and isinstance(
	//     o.rvalue.analyzed, nodes.TypeVarExpr
	// ):
	//     # Type variable definition -- not a real assignment.
	//     return
	if o.type != none {
		// If there is an explicit type, don't visit the l.h.s. as an expression
		v.type_node(o.type or { MypyTypeNode(none) })
		// o.rvalue.accept(self)
		return
	} else if v.inferred && !v.all_nodes {
		// if self.all_nodes is set, lvalues will be visited later
		// for lvalue in o.lvalues:
		//     if isinstance(lvalue, nodes.TupleExpr):
		//         items = lvalue.items
		//     else:
		//         items = [lvalue]
		//     for item in items:
		//         if isinstance(item, RefExpr) and item.is_inferred_def:
		//             if self.typemap is not None:
		//                 self.type(self.typemap.get(item))
	}
}

// visit_expression_stmt посещает оператор выражения
pub fn (mut v StatisticsVisitor) visit_expression_stmt(o ExpressionStmt) {
	// if isinstance(o.expr, (StrExpr, BytesExpr)):
	//     # Docstring
	//     self.record_line(o.line, TYPE_EMPTY)
	// } else {
	//     super().visit_expression_stmt(o)
	// }
}

// visit_pass_stmt посещает оператор pass
pub fn (mut v StatisticsVisitor) visit_pass_stmt(o PassStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_break_stmt посещает оператор break
pub fn (mut v StatisticsVisitor) visit_break_stmt(o BreakStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_continue_stmt посещает оператор continue
pub fn (mut v StatisticsVisitor) visit_continue_stmt(o ContinueStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_name_expr посещает имя
pub fn (mut v StatisticsVisitor) visit_name_expr(o NameExpr) {
	if o.fullname in ['builtins.None', 'builtins.True', 'builtins.False', 'builtins.Ellipsis'] {
		v.record_precise_if_checked_scope(o)
	} else {
		v.process_node(o)
	}
}

// visit_yield_from_expr посещает yield from
pub fn (mut v StatisticsVisitor) visit_yield_from_expr(o YieldFromExpr) {
	if o.expr != none {
		// o.expr.accept(self)
	}
}

// visit_call_expr посещает вызов функции
pub fn (mut v StatisticsVisitor) visit_call_expr(o CallExpr) {
	v.process_node(o)
	if o.analyzed != none {
		// o.analyzed.accept(self)
	} else {
		// o.callee.accept(self)
		// for a in o.args:
		//     a.accept(self)
		v.record_call_target_precision(o)
	}
}

// record_call_target_precision записывает точность аргументов вызова
pub fn (mut v StatisticsVisitor) record_call_target_precision(o CallExpr) {
	// if not self.typemap or o.callee not in self.typemap:
	//     # Type not available.
	//     return
	// callee_type = get_proper_type(self.typemap[o.callee])
	// if isinstance(callee_type, CallableType):
	//     self.record_callable_target_precision(o, callee_type)
}

// record_callable_target_precision записывает точность формальных аргументов
pub fn (mut v StatisticsVisitor) record_callable_target_precision(o CallExpr, callee CallableType) {
	// Упрощённая версия
}

// visit_member_expr посещает доступ к атрибуту
pub fn (mut v StatisticsVisitor) visit_member_expr(o MemberExpr) {
	v.process_node(o)
}

// visit_op_expr посещает оператор
pub fn (mut v StatisticsVisitor) visit_op_expr(o OpExpr) {
	v.process_node(o)
}

// visit_comparison_expr посещает оператор сравнения
pub fn (mut v StatisticsVisitor) visit_comparison_expr(o ComparisonExpr) {
	v.process_node(o)
}

// visit_index_expr посещает индексацию
pub fn (mut v StatisticsVisitor) visit_index_expr(o IndexExpr) {
	v.process_node(o)
}

// visit_assignment_expr посещает оператор присваивания (:=)
pub fn (mut v StatisticsVisitor) visit_assignment_expr(o AssignmentExpr) {
	v.process_node(o)
}

// visit_unary_expr посещает унарный оператор
pub fn (mut v StatisticsVisitor) visit_unary_expr(o UnaryExpr) {
	v.process_node(o)
}

// visit_str_expr посещает строковый литерал
pub fn (mut v StatisticsVisitor) visit_str_expr(o StrExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_bytes_expr посещает байтовый литерал
pub fn (mut v StatisticsVisitor) visit_bytes_expr(o BytesExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_int_expr посещает целочисленный литерал
pub fn (mut v StatisticsVisitor) visit_int_expr(o IntExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_float_expr посещает литерал float
pub fn (mut v StatisticsVisitor) visit_float_expr(o FloatExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_complex_expr посещает литерал complex
pub fn (mut v StatisticsVisitor) visit_complex_expr(o ComplexExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_ellipsis посещает Ellipsis
pub fn (mut v StatisticsVisitor) visit_ellipsis(o EllipsisExpr) {
	v.record_precise_if_checked_scope(o)
}

// process_node обрабатывает узел
pub fn (mut v StatisticsVisitor) process_node(node Expression) {
	if v.all_nodes {
		if v.typemap != none {
			v.line = node.line
			// self.type(self.typemap.get(node))
		}
	}
}

// record_precise_if_checked_scope записывает точность если в типизированной области
pub fn (mut v StatisticsVisitor) record_precise_if_checked_scope(node Node) {
	mut kind := type_precise
	if v.is_checked_scope() {
		kind = type_precise
	} else {
		kind = type_any
	}
	v.record_line(node.line, kind)
}

// type_node анализирует тип и записывает статистику
pub fn (mut v StatisticsVisitor) type_node(t MypyTypeNode) {
	if t == MypyTypeNode(none) {
		// If an expression does not have a type, it is often due to dead code.
		v.record_line(v.line, type_unanalyzed)
		return
	}

	// if isinstance(t, AnyType) and is_special_form_any(t):
	//     # TODO: What if there is an error in special form definition?
	//     self.record_line(self.line, TYPE_PRECISE)
	//     return

	match t {
		AnyType {
			// self.log("  !! Any type around line %d" % self.line)
			v.num_any_exprs++
			v.record_line(v.line, type_any)
			v.num_any_types++
		}
		Instance {
			if t.args.len > 0 {
				mut is_complex := false
				for arg in t.args {
					if v.is_complex_type(arg) {
						is_complex = true
						break
					}
				}
				if is_complex {
					v.num_complex_types++
				} else {
					v.num_generic_types++
				}
			} else {
				v.num_simple_types++
			}
		}
		CallableType {
			v.num_function_types++
		}
		TupleType {
			mut is_complex := false
			for item in t.items {
				if v.is_complex_type(item) {
					is_complex = true
					break
				}
			}
			if is_complex {
				v.num_complex_types++
			} else {
				v.num_tuple_types++
			}
		}
		TypeVarType {
			v.num_typevar_types++
		}
		else {
			v.num_precise_exprs++
			v.record_line(v.line, type_precise)
		}
	}
}

// is_complex_type проверяет, является ли тип сложным
pub fn (v StatisticsVisitor) is_complex_type(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		CallableType { true }
		TupleType { true }
		TypeVarType { true }
		else { false }
	}
}

// log записывает сообщение в output
pub fn (mut v StatisticsVisitor) log(msg string) {
	v.output << msg
}

// record_line записывает точность для строки
pub fn (mut v StatisticsVisitor) record_line(line int, precision int) {
	existing := v.line_map[line] or { type_empty }
	v.line_map[line] = max(precision, existing)
}

// dump_type_stats выводит статистику по дереву
pub fn dump_type_stats(tree MypyFile,
	path string,
	modules map[string]MypyFile,
	inferred bool,
	typemap ?map[string]MypyTypeNode) {
	if is_special_module(path) {
		return
	}
	println(path)
	mut visitor := new_statistics_visitor(inferred, tree.fullname, modules, typemap, false,
		true)
	visitor.visit_mypy_file(tree)
	for line in visitor.output {
		println(line)
	}
	println('  ** precision **')
	println('  precise  ${visitor.num_precise_exprs}')
	println('  imprecise${visitor.num_imprecise_exprs}')
	println('  any      ${visitor.num_any_exprs}')
	println('  ** kinds **')
	println('  simple   ${visitor.num_simple_types}')
	println('  generic  ${visitor.num_generic_types}')
	println('  function ${visitor.num_function_types}')
	println('  tuple    ${visitor.num_tuple_types}')
	println('  TypeVar  ${visitor.num_typevar_types}')
	println('  complex  ${visitor.num_complex_types}')
	println('  any      ${visitor.num_any_types}')
}

// is_special_module проверяет, является ли модуль специальным
pub fn is_special_module(path string) bool {
	basename := os.base(path)
	return basename in ['abc.pyi', 'typing.pyi', 'builtins.pyi']
}

// is_imprecise проверяет, содержит ли тип Any (кроме special_form)
pub fn is_imprecise(t MypyTypeNode) bool {
	return match t {
		AnyType { !is_special_form_any(t) }
		else { false }
	}
}

// is_imprecise2 проверяет имprecise без проверки CallableType
pub fn is_imprecise2(t MypyTypeNode) bool {
	return match t {
		AnyType { !is_special_form_any(t) }
		CallableType { false }
		else { false }
	}
}

// is_generic проверяет, является ли тип generic Instance
pub fn is_generic(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		else { false }
	}
}

// is_complex проверяет, является ли тип сложным
pub fn is_complex(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		CallableType { true }
		TupleType { true }
		TypeVarType { true }
		else { false }
	}
}

// is_special_form_any проверяет, является ли Any special_form
pub fn is_special_form_any(t AnyType) bool {
	return t.type_of_any == int(TypeOfAny.special_form)
}
