// expandtype.v — Type variable expansion (substituting TypeVar with concrete types).
module mypy

pub struct ExpandTypeVisitor {
pub mut:
	env map[string]MypyTypeNode // TypeVarId (name) -> Type
}

pub fn expand_type(typ MypyTypeNode, env map[string]MypyTypeNode) MypyTypeNode {
	if env.len == 0 {
		return typ
	}

	// If no type variables, nothing to do
	// For now, a simplified approach: just return the type as-is
	// A full implementation would recursively replace TypeVarType nodes.
	return typ
}

pub fn expand_type_by_instance(typ MypyTypeNode, instance &Instance) MypyTypeNode {
	// Substitute type arguments from instance
	if instance.args.len == 0 {
		return typ
	}
	if info := instance.typ {
		mut env := map[string]MypyTypeNode{}
		for i, tv in info.type_vars {
			if i < instance.args.len {
				// Use type_str as key (simplified)
				env[tv.type_str()] = instance.args[i]
			}
		}
		return expand_type(typ, env)
	}
	return typ
}
