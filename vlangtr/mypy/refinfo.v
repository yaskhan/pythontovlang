// refinfo.v — Find line-level reference information from a mypy AST (undocumented feature)
// Translated from mypy/refinfo.py to V 0.5.x

module mypy

// ---------------------------------------------------------------------------
// RefInfoVisitor
// ---------------------------------------------------------------------------

// RefInfoVisitor collects reference information from AST
pub struct RefInfoVisitor {
pub mut:
	// Use voidptr for Expression keys as V maps only support basic types as keys
	type_map map[voidptr]MypyTypeNode
	data     []map[string]MypyTypeNode
}

pub fn new_ref_info_visitor(type_map map[voidptr]MypyTypeNode) RefInfoVisitor {
	return RefInfoVisitor{
		type_map: type_map
		data:     []map[string]MypyTypeNode{}
	}
}

pub fn (mut v RefInfoVisitor) visit_name_expr(expr &NameExpr) {
	v.record_ref_expr(expr)
}

pub fn (mut v RefInfoVisitor) visit_member_expr(expr &MemberExpr) {
	v.record_ref_expr(expr)
}

pub fn (mut v RefInfoVisitor) visit_func_def(func &FuncDef) {
	// Simple traversal
	for item in func.expanded {
		if item is FuncDef {
			v.visit_func_def(item)
		}
	}
}

pub fn (mut v RefInfoVisitor) record_ref_expr(expr &RefExpr) {
	mut fullname := ''

	if expr.kind != .ldef && expr.fullname.contains('.') {
		fullname = expr.fullname
	} else if expr is MemberExpr {
		m_expr := expr as MemberExpr
		typ := v.type_map[voidptr(m_expr.expr)] or { MypyTypeNode(AnyType{}) }
		// node from SymbolNodeRef is ?SymbolNodeRef
		sym := if m_expr.expr is RefExpr { (m_expr.expr as RefExpr).node } else { none }
		if typ !is AnyType {
			tfn := type_fullname(typ, sym)
			if tfn != '' {
				fullname = '${tfn}.${m_expr.name}'
			}
		}
		if fullname == '' {
			fullname = '*.${m_expr.name}'
		}
	}

	if fullname != '' {
		mut entry := map[string]MypyTypeNode{}
		// Placeholder for line/column/target info using LiteralType
		// Actually, in V it might be better to use a specific struct for RefInfoEntry
		// but we follow Python's map approach for now.
		v.data << entry
	}
}

// ---------------------------------------------------------------------------
// type_fullname
// ---------------------------------------------------------------------------

// type_fullname gets fullname of a type
pub fn type_fullname(typ MypyTypeNode, node ?SymbolNodeRef) string {
	match typ {
		Instance {
			return typ.type_name
		}
		CallableType {
			if typ.is_type_obj() {
				if n := node {
					if n is TypeInfo {
						return n.fullname
					}
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
pub fn get_undocumented_ref_info_json(tree &MypyFile, type_map map[voidptr]MypyTypeNode) []map[string]MypyTypeNode {
	mut visitor := new_ref_info_visitor(type_map)
	// Traverse the tree...
	return visitor.data
}
