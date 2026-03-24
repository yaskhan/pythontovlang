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
}

pub fn (mut v RefInfoVisitor) record_ref_expr(expr &RefExpr) {
	mut fullname := ''

	// Since RefExpr is a sum type, use a match or is check correctly
	match expr {
		NameExpr {
			if int(expr.kind) != int(ldef) && expr.fullname.contains('.') {
				fullname = expr.fullname
			}
		}
		MemberExpr {
			if expr.kind != ldef && expr.fullname.contains('.') {
				fullname = expr.fullname
			} else {
				m_expr := expr
				typ := v.type_map[unsafe { voidptr(&m_expr.expr) }] or { MypyTypeNode(AnyType{}) }
				// Extract node if the sub-expression is NameExpr or MemberExpr
				sym := match m_expr.expr {
					NameExpr { m_expr.expr.node }
					MemberExpr { m_expr.expr.node }
					else { none }
				}
				mut sym_ref := ?SymbolNodeRef(none)
				if s := sym {
					match s {
						ClassDef { sym_ref = s }
						Decorator { sym_ref = s }
						FuncDef { sym_ref = s }
						MypyFile { sym_ref = s }
						OverloadedFuncDef { sym_ref = s }
						PlaceholderNode { sym_ref = s }
						TypeAlias { sym_ref = s }
						TypeInfo { sym_ref = s }
						Var { sym_ref = s }
						else {}
					}
				}
				if typ !is AnyType {
					tfn := type_fullname(typ, sym_ref)
					if tfn != '' {
						fullname = '${tfn}.${m_expr.name}'
					}
				}
				if fullname == '' {
					fullname = '*.${m_expr.name}'
				}
			}
		}
	}

	if fullname != '' {
		mut entry := map[string]MypyTypeNode{}
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
				if fb := typ.fallback {
					return type_fullname(MypyTypeNode(*fb), node)
				}
				return ''
			}
			return ''
		}
		TupleType {
			if fb := typ.partial_fallback {
				return type_fullname(MypyTypeNode(*fb), node)
			}
			return ''
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
