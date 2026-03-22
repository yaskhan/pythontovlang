// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 04:30
module mypy

// Семантический анализ определений NamedTuple.

pub const namedtuple_prohibited_names = [
	'__new__',
	'__init__',
	'__slots__',
	'__getnewargs__',
	'_fields',
	'_field_defaults',
	'_field_types',
	'_make',
	'_replace',
	'_asdict',
	'_source',
	'__annotations__',
]

pub const typed_namedtuple_names = ['typing.NamedTuple']

pub const namedtuple_class_error = 'Invalid statement in NamedTuple definition; expected "field_name: field_type [= default]"'

pub struct NamedTupleAnalyzer {
pub mut:
	options &Options
	api     &SemanticAnalyzerInterface
}

pub fn (mut a NamedTupleAnalyzer) analyze_namedtuple_classdef(defn &ClassDef, is_stub_file bool, is_func_scope bool) (bool, ?&TypeInfo) {
	for base_expr in defn.base_type_exprs {
		if base_expr is NameExpr {
			a.api.accept(base_expr)
			if base_expr.fullname in typed_namedtuple_names {
				result := a.check_namedtuple_classdef(defn, is_stub_file) or { return true, none }
				items, types, default_items, statements := result

				mut name := defn.name
				if is_func_scope && !name.contains('@') {
					name += '@' + defn.base.ctx.line.str()
				}

				info := a.build_namedtuple_typeinfo(name, items, types, default_items,
					defn.base.ctx.line, none)
				// defn.analyzed = NamedTupleExpr(info, is_typed: true)
				mut mut_defn := unsafe { &ClassDef(defn) }
				mut_defn.defs.body = statements
				return true, info
			}
		}
	}
	return false, none
}

pub fn (mut a NamedTupleAnalyzer) check_namedtuple_classdef(defn &ClassDef, is_stub_file bool) ?([]string, []MypyTypeNode, map[string]Expression, []Statement) {
	if defn.base_type_exprs.len > 1 {
		a.fail('NamedTuple should be a single base', defn.get_context())
	}

	mut items := []string{}
	mut types := []MypyTypeNode{}
	mut default_items := map[string]Expression{}
	mut statements := []Statement{}

	for stmt in defn.defs.body {
		statements << stmt
		if stmt is AssignmentStmt {
			if stmt.lvalues.len == 1 && stmt.lvalues[0] is NameExpr {
				name := (stmt.lvalues[0] as NameExpr).name
				items << name

				mut typ := MypyTypeNode(AnyType{
					type_of_any: .unannotated
				})
				// u_type is Type?
				// stmt.unanalyzed_type is ?MypyType
				if ut := stmt.unanalyzed_type {
					if analyzed := a.api.anal_type(ut, none, true, false, true, false,
						true, 'NamedTuple item type', 'NamedTuple')
					{
						typ = analyzed
					} else {
						return none // Defer
					}
				}
				types << typ

				if name.starts_with('_') {
					a.fail('NamedTuple field name cannot start with an underscore: ${name}',
						stmt.get_context())
				}

				// Simplified check for rvalue
				// if stmt.rvalue !is TempNode {
				//	default_items[name] = stmt.rvalue
				// }
			} else {
				statements.delete_last()
				a.fail(namedtuple_class_error, stmt.get_context())
			}
		} else if stmt is PassStmt {
			// allow pass
		} else if stmt is FuncDef {
			// allow methods
		} else {
			statements.delete_last()
			a.fail(namedtuple_class_error, stmt.get_context())
		}
	}
	return items, types, default_items, statements
}

pub fn (mut a NamedTupleAnalyzer) build_namedtuple_typeinfo(name string, items []string, types []MypyTypeNode, default_items map[string]Expression, line int, existing_info ?&TypeInfo) &TypeInfo {
	fallback := Instance{
		typ:  &TypeInfo{
			name:     'tuple'
			fullname: 'builtins.tuple'
		}
		args: [MypyTypeNode(AnyType{
			type_of_any: .special_form
		})]
	}

	info := or_existing_info(existing_info, a.api.basic_new_typeinfo(name, fallback, line))
	mut mut_info := unsafe { &TypeInfo(info) }

	mut_info.is_named_tuple = true

	tuple_base := &TupleType{
		base:             TypeBase{
			ctx: Context{
				line: line
			}
		}
		items:            types
		partial_fallback: fallback
	}
	mut_info.tuple_type = tuple_base

	for i, item in items {
		mut v := &Var{
			name:        item
			type_:       types[i]
			info:        info
			is_property: true
		}
		v.fullname = '${info.fullname}.${item}'
		mut_info.names.symbols[item] = SymbolTableNode{
			kind: .mdef
			node: SymbolNodeRef(v)
		}
	}

	return info
}

fn or_existing_info(existing ?&TypeInfo, fallback &TypeInfo) &TypeInfo {
	if e := existing {
		return e
	}
	return fallback
}

pub fn (mut a NamedTupleAnalyzer) fail(msg string, ctx Context) {
	a.api.fail(msg, ctx, false, false, none)
}
