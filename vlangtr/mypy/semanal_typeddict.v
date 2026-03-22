// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 04:15
module mypy

// Семантический анализ определений TypedDict.

pub const tpdict_names = ['typing.TypedDict', 'typing_extensions.TypedDict']

pub const tpdict_class_error = 'Invalid statement in TypedDict definition; expected "field_name: field_type"'

pub struct TypedDictAnalyzer {
pub mut:
	options &Options
	api     &SemanticAnalyzerInterface
}

pub fn (mut a TypedDictAnalyzer) analyze_typeddict_classdef(defn &ClassDef) (bool, ?&TypeInfo) {
	mut possible := false
	for base_expr in defn.base_type_exprs {
		mut e := base_expr
		if e is CallExpr { e = e.callee }
		// if e is IndexExpr { e = e.base_ }
		if e is NameExpr {
			a.api.accept(e)
			if e.fullname in tpdict_names || a.is_typeddict(e) {
				possible = true
				if node := e.node {
					if n := node {
						if n is TypeInfo && n.is_final {
							a.fail('Cannot inherit from final class "${n.name}"', defn.get_context(), none)
						}
					}
				}
			}
		}
	}
	if !possible { return false, none }

	if defn.base_type_exprs.len == 1 {
		base0 := defn.base_type_exprs[0]
		if base0 is NameExpr && base0.fullname in tpdict_names {
			// Building a new TypedDict
			field_types, statements, required_keys, readonly_keys := a.analyze_typeddict_classdef_fields(defn, [])
			
			mut name := defn.name
			if a.api.is_func_scope() && !name.contains('@') {
				name += '@' + defn.base.ctx.line.str()
			}
			
			info := a.build_typeddict_typeinfo(name, field_types, required_keys, readonly_keys, defn.base.ctx.line, none)
			mut mut_defn := unsafe { &ClassDef(defn) }
			mut_defn.defs.body = statements
			return true, info
		}
	}

	return true, none
}

pub fn (mut a TypedDictAnalyzer) analyze_typeddict_classdef_fields(defn &ClassDef, oldfields []string) (map[string]MypyTypeNode, []Statement, []string, []string) {
	mut fields := map[string]MypyTypeNode{}
	mut readonly_keys := []string{}
	mut required_keys := []string{}
	mut statements := []Statement{}
	
	mut total := true

	for stmt in defn.defs.body {
		if stmt is AssignmentStmt {
			if stmt.lvalues.len == 1 && stmt.lvalues[0] is NameExpr {
				name := (stmt.lvalues[0] as NameExpr).name
				statements << stmt
				
				mut field_type := MypyTypeNode(AnyType{type_of_any: .unannotated})
				if ut := stmt.unanalyzed_type {
					if analyzed := a.api.anal_type(ut, none, true, false, true, false, true, 'TypedDict item type', 'TypedDict') {
						field_type = analyzed
					}
				}
				
				typ, is_required_raw, readonly := a.extract_meta_info(field_type, stmt.get_context())
				fields[name] = typ
				
				mut is_required := total
				if ir := is_required_raw {
					is_required = ir
				}
				
				if is_required {
					required_keys << name
				}
				if readonly {
					readonly_keys << name
				}
			}
		} else if stmt is PassStmt {
			statements << stmt
		}
	}
	return fields, statements, required_keys, readonly_keys
}

pub fn (mut a TypedDictAnalyzer) extract_meta_info(typ MypyTypeNode, context Context) (MypyTypeNode, ?bool, bool) {
	mut t := typ
	mut is_required := ?bool(none)
	mut readonly := false
	
	for {
		// In V, sum-types don't support RequiredType/ReadOnlyType if not added to MypyTypeNode.
		// These are from typing_extensions.
		break
	}
	return t, is_required, readonly
}

pub fn (mut a TypedDictAnalyzer) build_typeddict_typeinfo(name string, item_types map[string]MypyTypeNode, required_keys []string, readonly_keys []string, line int, existing_info ?&TypeInfo) &TypeInfo {
	fallback := a.api.named_type_or_none('typing._TypedDict', []) 
		or { a.api.named_type('builtins.dict', [MypyTypeNode(AnyType{type_of_any: .from_another_any})]) }
	
	info := or_existing_info(existing_info, a.api.api.basic_new_typeinfo(name, fallback, line))
	mut mut_info := unsafe { &TypeInfo(info) }
	
	mut req_keys_map := map[string]bool{}
	for k in required_keys { req_keys_map[k] = true }
	
	mut ro_keys_map := map[string]bool{}
	for k in readonly_keys { ro_keys_map[k] = true }

	td_type := &TypedDictType{
		base: TypeBase{ctx: Context{line: line}}
		items: item_types
		required_keys: req_keys_map
		readonly_keys: ro_keys_map
		fallback: fallback
	}
	
	mut_info.typeddict_type = td_type
	return info
}

pub fn (mut a TypedDictAnalyzer) is_typeddict(expr Expression) bool {
	if expr is NameExpr {
		if node := expr.node {
			if n := node {
				if n is TypeInfo {
					return n.typeddict_type != none
				}
			}
		}
	}
	return false
}

pub fn (mut a TypedDictAnalyzer) fail(msg string, ctx Context, code ?&ErrorCode) {
	a.api.fail(msg, ctx, false, false, code)
}
