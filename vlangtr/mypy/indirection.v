// indirection.v — Type indirection visitor for module dependency analysis
module mypy

// TypeIndirectionVisitor finds all module references within a type.
pub struct TypeIndirectionVisitor {
	TypeTraverserVisitor
pub mut:
	modules    map[string]bool // set of module names
	seen_types map[string]bool // recursive type tracking
}

// find_modules finds all modules in a set of types.
pub fn (mut v TypeIndirectionVisitor) find_modules(typs []MypyTypeNode) map[string]bool {
	v.modules = map[string]bool{}
	v.seen_types = map[string]bool{}
	for typ in typs {
		v.visit(typ)
	}
	return v.modules
}

// visit visits a type, avoiding infinite recursion for recursive types.
pub fn (mut v TypeIndirectionVisitor) visit(typ MypyTypeNode) {
	mut type_key := typ.type_str()
	if typ is Instance {
		type_key = 'Instance:${typ.type_name}'
	}
	if typ is TypeAliasType {
		type_key = 'TypeAliasType:${typ.type_ref or { "" }}'
	}

	if v.seen_types[type_key] {
		return
	}
	v.seen_types[type_key] = true

	typ.accept(mut v) or {}
}

pub fn (mut v TypeIndirectionVisitor) visit_instance(t &Instance) !string {
	v.traverse_type_list(t.args)!

	if info := t.typ {
		// Module of the class itself
		if info.fullname.contains('.') {
			parts := info.fullname.rsplit('.')
			v.modules[parts[0]] = true
		}

		// Modules of all base classes in MRO
		for s in info.mro {
			if s.fullname.contains('.') {
				parts := s.fullname.rsplit('.')
				v.modules[parts[0]] = true
			}
		}
	}
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_type_var(t &TypeVarType) !string {
	v.traverse_type_list(t.values)!
	v.visit(t.upper_bound)
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_param_spec(t &ParamSpecType) !string {
	v.visit(t.upper_bound)
	v.visit(t.default)
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_type_var_tuple(t &TypeVarTupleType) !string {
	v.visit(t.upper_bound)
	v.visit(t.default)
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_unpack_type(t &UnpackType) !string {
	t.type.accept(mut v)!
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_type_alias_type(t &TypeAliasType) !string {
	v.traverse_type_list(t.args)!
	if alias := t.alias {
		// v.modules[alias.module] = true
	}
	return ''
}

pub fn (mut v TypeIndirectionVisitor) visit_overloaded(t &Overloaded) !string {
	for item in t.items {
		MypyTypeNode(*item).accept(mut v)!
	}
	return ''
}
