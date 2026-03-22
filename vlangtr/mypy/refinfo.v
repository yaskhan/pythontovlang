// refinfo.v — Find line-level reference information from a mypy AST (undocumented feature)
// Translated from mypy/refinfo.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 08:16
//
// Translation notes:
//   - RefInfoVisitor: collects reference information from AST
//   - type_fullname: gets fullname of a type
//   - get_undocumented_ref_info_json: main entry point

module mypy

// ---------------------------------------------------------------------------
// RefInfoVisitor
// ---------------------------------------------------------------------------

// RefInfoVisitor collects reference information from AST
pub struct RefInfoVisitor {
pub mut:
	type_map map[Expression]MypyTypeNode
	data     []map[string]MypyTypeNode
}

pub fn RefInfoVisitor.new(type_map map[Expression]MypyTypeNode) RefInfoVisitor {
	return RefInfoVisitor{
		type_map: type_map
		data:     []map[string]MypyTypeNode{}
	}
}

pub fn (mut v RefInfoVisitor) visit_name_expr(expr NameExpr) {
	v.record_ref_expr(expr)
}

pub fn (mut v RefInfoVisitor) visit_member_expr(expr MemberExpr) {
	v.record_ref_expr(expr)
}

pub fn (mut v RefInfoVisitor) visit_func_def(func FuncDef) {
	// Note: In V, we don't have the same traversal mechanism
	// This is a simplified version
	if func.expanded.len > 0 {
		for item in func.expanded {
			if item is FuncDef {
				v.visit_func_def(item)
			}
		}
	}
}

pub fn (mut v RefInfoVisitor) record_ref_expr(expr RefExpr) {
	mut fullname := ''

	if expr.kind != LDEF && '.' in expr.fullname {
		fullname = expr.fullname
	} else if expr is MemberExpr {
		typ := v.type_map[expr.expr] or { MypyTypeNode(AnyType{}) }
		sym := if expr.expr is RefExpr { expr.expr.node } else { none }
		if typ !is AnyType {
			tfn := type_fullname(typ, sym)
			if tfn != '' {
				fullname = '${tfn}.${expr.name}'
			}
		}
		if fullname == '' {
			fullname = '*.${expr.name}'
		}
	}

	if fullname != '' {
		mut entry := map[string]MypyTypeNode{}
		entry['line'] = MypyTypeNode(LiteralType{
			value:    i64(expr.line)
			fallback: Instance{}
		})
		entry['column'] = MypyTypeNode(LiteralType{
			value:    i64(expr.column)
			fallback: Instance{}
		})
		entry['target'] = MypyTypeNode(LiteralType{
			value:    fullname
			fallback: Instance{}
		})
		v.data << entry
	}
}

// ---------------------------------------------------------------------------
// type_fullname
// ---------------------------------------------------------------------------

// type_fullname gets fullname of a type
pub fn type_fullname(typ MypyTypeNode, node ?SymbolNode) string {
	match typ {
		Instance {
			return typ.type_name
		}
		TypeType {
			return type_fullname(typ.item, node)
		}
		CallableType {
			if typ.is_type_obj() {
				if node is TypeInfo {
					return node.fullname
				}
				return type_fullname(MypyTypeNode(typ.fallback), node)
			}
			return ''
		}
		TupleType {
			return type_fullname(MypyTypeNode(typ.partial_fallback), node)
		}
		else {
			return ''
		}
	}
}

// ---------------------------------------------------------------------------
// get_undocumented_ref_info_json
// ---------------------------------------------------------------------------

// get_undocumented_ref_info_json is the main entry point
pub fn get_undocumented_ref_info_json(tree MypyFile, type_map map[Expression]MypyTypeNode) []map[string]MypyTypeNode {
	mut visitor := RefInfoVisitor.new(type_map)
	// Note: In a full implementation, we would traverse the tree
	// For now, return the collected data
	return visitor.data
}
