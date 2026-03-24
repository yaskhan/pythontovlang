// stats.v — Utilities for calculating and reporting statistics about types
// Translated from mypy/stats.py to V 0.5.x
//
// I, Antigravity, am working on this file. Started: 2026-03-22 12:30

module mypy

import os

// Type precision
pub const type_empty = 0
pub const type_unanalyzed = 1 // type of untyped code
pub const type_precise = 2
pub const type_imprecise = 3
pub const type_any = 4

pub const precision_names = ['empty', 'unanalyzed', 'precise', 'imprecise', 'any']

// ImportStmt — sum-type for imports
pub type ImportStmt = ImportFrom | ImportAll

// StatisticsVisitor — visitor for gathering type statistics
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

	// For each scope (top level/function), whether the scope
	// was typed (annotated function).
	checked_scopes []bool

	output []string

	// Internal fields
	cur_mod_node MypyFile
	cur_mod_id   string
}

// new_statistics_visitor creates a new StatisticsVisitor
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

// visit_mypy_file visits the root node of the file
pub fn (mut v StatisticsVisitor) visit_mypy_file(o MypyFile) {
	v.cur_mod_node = o
	v.cur_mod_id = o.fullname
	// Continue traversal
}

// visit_import_from processes a from ... import ... import
pub fn (mut v StatisticsVisitor) visit_import_from(imp ImportFrom) {
	v.process_import(imp)
}

// visit_import_all processes an import * import
pub fn (mut v StatisticsVisitor) visit_import_all(imp ImportAll) {
	v.process_import(imp)
}

// process_import processes an import and records precision
pub fn (mut v StatisticsVisitor) process_import(imp ImportStmt) {
	// import_id, ok := correct_relative_import(...)
	// Simplified version:
	mut kind := type_precise

	match imp {
		ImportFrom {
			if imp.id !in v.modules {
				kind = type_any
			}
			v.record_line(imp.base.ctx.line, kind)
		}
		ImportAll {
			if imp.id !in v.modules {
				kind = type_any
			}
			v.record_line(imp.base.ctx.line, kind)
		}
	}
}

// visit_import processes an ordinary import
pub fn (mut v StatisticsVisitor) visit_import(imp Import) {
	mut all_in_modules := true
	for alias in imp.ids {
		if alias.name !in v.modules {
			all_in_modules = false
			break
		}
	}
	mut kind := type_precise
	if !all_in_modules {
		kind = type_any
	}
	v.record_line(imp.base.ctx.line, kind)
}

// visit_func_def visits a function definition
pub fn (mut v StatisticsVisitor) visit_func_def(o FuncDef) {
	v.enter_scope(o)
	v.line = o.base.ctx.line

	if o.type_ != none {
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

// enter_scope enters a function scope
pub fn (mut v StatisticsVisitor) enter_scope(o FuncDef) {
	checked := o.type_ != none && v.checked_scopes.last()
	v.checked_scopes << checked
}

// exit_scope exits a scope
pub fn (mut v StatisticsVisitor) exit_scope() {
	if v.checked_scopes.len > 0 {
		v.checked_scopes.pop()
	}
}

// is_checked_scope returns true if the current scope is typed
pub fn (v StatisticsVisitor) is_checked_scope() bool {
	return v.checked_scopes.last()
}

// visit_class_def visits a class definition
pub fn (mut v StatisticsVisitor) visit_class_def(o ClassDef) {
	v.record_line(o.base.ctx.line, type_precise) // TODO: Look at base classes
	// While base_type_exprs are technically expressions, type analyzer does not visit them
	for d in o.decorators {
		// d.accept(self)
	}
	// o.defs.accept(self)
}

// visit_type_application visits a type application
pub fn (mut v StatisticsVisitor) visit_type_application(o TypeApplication) {
	v.line = o.base.ctx.line
	for t in o.types {
		v.type_node(t)
	}
}

// visit_assignment_stmt visits an assignment statement
pub fn (mut v StatisticsVisitor) visit_assignment_stmt(o AssignmentStmt) {
	v.line = o.base.ctx.line
	if o.type_annotation != none {
		// If there is an explicit type, don't visit the l.h.s. as an expression
		v.type_node(o.type_annotation)
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

// visit_expression_stmt visits an expression statement
pub fn (mut v StatisticsVisitor) visit_expression_stmt(o ExpressionStmt) {
	// if isinstance(o.expr, (StrExpr, BytesExpr)):
	//     # Docstring
	//     self.record_line(o.line, TYPE_EMPTY)
	// } else {
	//     super().visit_expression_stmt(o)
	// }
}

// visit_pass_stmt visits a pass statement
pub fn (mut v StatisticsVisitor) visit_pass_stmt(o PassStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_break_stmt visits a break statement
pub fn (mut v StatisticsVisitor) visit_break_stmt(o BreakStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_continue_stmt visits a continue statement
pub fn (mut v StatisticsVisitor) visit_continue_stmt(o ContinueStmt) {
	v.record_precise_if_checked_scope(o)
}

// visit_name_expr visits a name
pub fn (mut v StatisticsVisitor) visit_name_expr(o NameExpr) {
	if o.fullname in ['builtins.None', 'builtins.True', 'builtins.False', 'builtins.Ellipsis'] {
		v.record_precise_if_checked_scope(o)
	} else {
		v.process_node(o)
	}
}

// visit_yield_from_expr visits yield from
pub fn (mut v StatisticsVisitor) visit_yield_from_expr(o YieldFromExpr) {
	// o.expr.accept(self)
}

// visit_call_expr visits a function call
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

// record_call_target_precision records precision of call arguments
pub fn (mut v StatisticsVisitor) record_call_target_precision(o CallExpr) {
	// if not self.typemap or o.callee not in self.typemap:
	//     # Type not available.
	//     return
	// callee_type = get_proper_type(self.typemap[o.callee])
	// if isinstance(callee_type, CallableType):
	//     self.record_callable_target_precision(o, callee_type)
}

// record_callable_target_precision records precision of formal arguments
pub fn (mut v StatisticsVisitor) record_callable_target_precision(o CallExpr, callee CallableType) {
	// Simplified version
}

// visit_member_expr visits attribute access
pub fn (mut v StatisticsVisitor) visit_member_expr(o MemberExpr) {
	v.process_node(o)
}

// visit_op_expr visits an operator
pub fn (mut v StatisticsVisitor) visit_op_expr(o OpExpr) {
	v.process_node(o)
}

// visit_comparison_expr visits a comparison operator
pub fn (mut v StatisticsVisitor) visit_comparison_expr(o ComparisonExpr) {
	v.process_node(o)
}

// visit_index_expr visits indexing
pub fn (mut v StatisticsVisitor) visit_index_expr(o IndexExpr) {
	v.process_node(o)
}

// visit_assignment_expr visits an assignment expression (:=)
pub fn (mut v StatisticsVisitor) visit_assignment_expr(o AssignmentExpr) {
	v.process_node(o)
}

// visit_unary_expr visits a unary operator
pub fn (mut v StatisticsVisitor) visit_unary_expr(o UnaryExpr) {
	v.process_node(o)
}

// visit_str_expr visits a string literal
pub fn (mut v StatisticsVisitor) visit_str_expr(o StrExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_bytes_expr visits a bytes literal
pub fn (mut v StatisticsVisitor) visit_bytes_expr(o BytesExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_int_expr visits an integer literal
pub fn (mut v StatisticsVisitor) visit_int_expr(o IntExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_float_expr visits a float literal
pub fn (mut v StatisticsVisitor) visit_float_expr(o FloatExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_complex_expr visits a complex literal
pub fn (mut v StatisticsVisitor) visit_complex_expr(o ComplexExpr) {
	v.record_precise_if_checked_scope(o)
}

// visit_ellipsis visits Ellipsis
pub fn (mut v StatisticsVisitor) visit_ellipsis(o EllipsisExpr) {
	v.record_precise_if_checked_scope(o)
}

// process_node processes a node
pub fn (mut v StatisticsVisitor) process_node(node Expression) {
	if v.all_nodes {
		if v.typemap != none {
			match node {
				AssignmentExpr { v.line = node.base.ctx.line }
				AwaitExpr { v.line = node.base.ctx.line }
				BytesExpr { v.line = node.base.ctx.line }
				CallExpr { v.line = node.base.ctx.line }
				CastExpr { v.line = node.base.ctx.line }
				ComparisonExpr { v.line = node.base.ctx.line }
				ComplexExpr { v.line = node.base.ctx.line }
				ConditionalExpr { v.line = node.base.ctx.line }
				DictExpr { v.line = node.base.ctx.line }
				DictionaryComprehension { v.line = node.base.ctx.line }
				EllipsisExpr { v.line = node.base.ctx.line }
				EnumCallExpr { v.line = node.base.ctx.line }
				FloatExpr { v.line = node.base.ctx.line }
				FormatStringExpr { v.line = node.base.ctx.line }
				GeneratorExpr { v.line = node.base.ctx.line }
				IndexExpr { v.line = node.base.ctx.line }
				IntExpr { v.line = node.base.ctx.line }
				LambdaExpr { v.line = node.base.ctx.line }
				ListComprehension { v.line = node.base.ctx.line }
				ListExpr { v.line = node.base.ctx.line }
				MemberExpr { v.line = node.base.ctx.line }
				NameExpr { v.line = node.base.ctx.line }
				NamedTupleExpr { v.line = node.base.ctx.line }
				NewTypeExpr { v.line = node.base.ctx.line }
				OpExpr { v.line = node.base.ctx.line }
				ParamSpecExpr { v.line = node.base.ctx.line }
				PromoteExpr { v.line = node.base.ctx.line }
				RevealExpr { v.line = node.base.ctx.line }
				SetComprehension { v.line = node.base.ctx.line }
				SetExpr { v.line = node.base.ctx.line }
				SliceExpr { v.line = node.base.ctx.line }
				StarExpr { v.line = node.base.ctx.line }
				StrExpr { v.line = node.base.ctx.line }
				SuperExpr { v.line = node.base.ctx.line }
				TempNode { v.line = node.base.ctx.line }
				TemplateStrExpr { v.line = node.base.ctx.line }
				TupleExpr { v.line = node.base.ctx.line }
				TypeAliasExpr { v.line = node.base.ctx.line }
				TypeApplication { v.line = node.base.ctx.line }
				TypeVarExpr { v.line = node.base.ctx.line }
				TypeVarTupleExpr { v.line = node.base.ctx.line }
				UnaryExpr { v.line = node.base.ctx.line }
				YieldExpr { v.line = node.base.ctx.line }
				YieldFromExpr { v.line = node.base.ctx.line }
				TypedDictExpr { v.line = node.base.ctx.line }
				AssertTypeExpr { v.line = node.base.ctx.line }
			}
			// self.type(self.typemap.get(node))
		}
	}
}

// record_precise_if_checked_scope records precision if in a typed scope
pub fn (mut v StatisticsVisitor) record_precise_if_checked_scope(node Node) {
	mut kind := type_precise
	if v.is_checked_scope() {
		kind = type_precise
	} else {
		kind = type_any
	}
	v.record_line(node.get_context().line, kind)
}

// type_node analyzes a type and records statistics
pub fn (mut v StatisticsVisitor) type_node(t ?MypyTypeNode) {
	node_t := t or {
		// If an expression does not have a type, it is often due to dead code.
		v.record_line(v.line, type_unanalyzed)
		return
	}

	// if isinstance(t, AnyType) and is_special_form_any(t):
	//     # TODO: What if there is an error in special form definition?
	//     self.record_line(self.line, TYPE_PRECISE)
	//     return

	match node_t {
		AnyType {
			// self.log("  !! Any type around line %d" % self.line)
			v.num_any_exprs++
			v.record_line(v.line, type_any)
			v.num_any_types++
		}
		Instance {
			if node_t.args.len > 0 {
				mut is_complex := false
				for arg in node_t.args {
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
			for item in node_t.items {
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

// is_complex_type checks if a type is complex
pub fn (v StatisticsVisitor) is_complex_type(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		CallableType { true }
		TupleType { true }
		TypeVarType { true }
		else { false }
	}
}

// log records a message into output
pub fn (mut v StatisticsVisitor) log(msg string) {
	v.output << msg
}

// record_line records precision for a line
pub fn (mut v StatisticsVisitor) record_line(line int, precision int) {
	existing := v.line_map[line] or { type_empty }
	v.line_map[line] = if precision > existing { precision } else { existing }
}

// dump_type_stats outputs tree statistics
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

// is_special_module checks if a module is special
pub fn is_special_module(path string) bool {
	basename := os.base(path)
	return basename in ['abc.pyi', 'typing.pyi', 'builtins.pyi']
}

// is_imprecise checks if a type contains Any (except special_form)
pub fn is_imprecise(t MypyTypeNode) bool {
	return match t {
		AnyType { !is_special_form_any(t) }
		else { false }
	}
}

// is_imprecise2 checks imprecise without checking CallableType
pub fn is_imprecise2(t MypyTypeNode) bool {
	return match t {
		AnyType { !is_special_form_any(t) }
		CallableType { false }
		else { false }
	}
}

// is_generic checks if a type is a generic Instance
pub fn is_generic(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		else { false }
	}
}

// is_complex checks if a type is complex
pub fn is_complex(t MypyTypeNode) bool {
	return match t {
		Instance { t.args.len > 0 }
		CallableType { true }
		TupleType { true }
		TypeVarType { true }
		else { false }
	}
}

// is_special_form_any checks if Any is a special_form
pub fn is_special_form_any(t AnyType) bool {
	return t.type_of_any == TypeOfAny.special_form
}
