// fixup.v — Fix up various things after deserialization
// Translated from mypy/fixup.py to V 0.5.x
//
// Work in progress by Antigravity. Started: 2026-03-22 16:00

module mypy

// fixup_module fixes various things after deserialization
pub fn fixup_module(mut tree MypyFile, modules map[string]MypyFile, allow_missing bool) {
	mut node_fixer := NodeFixer{
		modules:       modules
		allow_missing: allow_missing
		type_fixer:    new_type_fixer(modules, allow_missing)
	}
	node_fixer.visit_symbol_table(mut tree.names, tree.fullname)
}

// NodeFixer — node fixer
pub struct NodeFixer {
pub mut:
	modules       map[string]MypyFile
	allow_missing bool
	current_info  ?&TypeInfo
	type_fixer    TypeFixer
}

// new_node_fixer creates a new NodeFixer
pub fn new_node_fixer(modules map[string]MypyFile, allow_missing bool) NodeFixer {
	return NodeFixer{
		modules:       modules
		allow_missing: allow_missing
		current_info:  none
		type_fixer:    new_type_fixer(modules, allow_missing)
	}
}

// visit_type_info visits TypeInfo
pub fn (mut nf NodeFixer) visit_type_info(mut info TypeInfo) {
	save_info := nf.current_info
	defer { nf.current_info = save_info }

	nf.current_info = &info

	nf.visit_symbol_table(mut info.names, info.fullname)

	for mut base in info.bases {
		fixed := MypyTypeNode(base).accept_translator(mut nf.type_fixer) or { MypyTypeNode(base) }
		if fixed is Instance {
			base = fixed
		}
	}
}

// visit_symbol_table visits symbol table
pub fn (mut nf NodeFixer) visit_symbol_table(mut symtab SymbolTable, table_fullname string) {
	for _, mut value in symtab.symbols {
		if cross_ref := value.cross_ref {
			value.cross_ref = none

			if cross_ref in nf.modules {
				value.node = SymbolNodeRef(nf.modules[cross_ref])
			} else {
				stnode := lookup_fully_qualified(cross_ref, nf.modules)
				if st := stnode {
					if n := st.node {
						value.node = n
					}
				} else if !nf.allow_missing {
					// panic('Could not find cross-ref ${cross_ref}')
				} else {
					// value.node = missing_info(nf.modules)
				}
			}
		} else {
			// ...
		}
	}
}

// TypeFixer — type fixer
pub struct TypeFixer {
pub mut:
	modules       map[string]MypyFile
	allow_missing bool
}

// new_type_fixer creates a new TypeFixer
pub fn new_type_fixer(modules map[string]MypyFile, allow_missing bool) TypeFixer {
	return TypeFixer{
		modules:       modules
		allow_missing: allow_missing
	}
}

// Implementation of ITypeTranslator for TypeFixer
pub fn (mut tf TypeFixer) visit_unbound_type(t &UnboundType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_any(t &AnyType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_none_type(t &NoneType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_uninhabited_type(t &UninhabitedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_erased_type(t &ErasedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_deleted_type(t &DeletedType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_instance(t &Instance) !MypyTypeNode {
	mut res := *t
	for mut a in res.args {
		a = a.accept_translator(mut tf) or { *a }
	}
	return MypyTypeNode(res)
}

pub fn (mut tf TypeFixer) visit_type_var(t &TypeVarType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_param_spec(t &ParamSpecType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_parameters(t &ParametersType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_type_var_tuple(t &TypeVarTupleType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_callable_type(t &CallableType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_overloaded(t &Overloaded) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_tuple_type(t &TupleType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_typeddict_type(t &TypedDictType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_literal_type(t &LiteralType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_union_type(t &UnionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_partial_type(t &PartialTypeT) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_type_type(t &TypeType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_type_alias_type(t &TypeAliasType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_unpack_type(t &UnpackType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_callable_argument(t &CallableArgument) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_ellipsis_type(t &EllipsisType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_placeholder_type(t &PlaceholderType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_raw_expression_type(t &RawExpressionType) !MypyTypeNode {
	return MypyTypeNode(*t)
}

pub fn (mut tf TypeFixer) visit_type_list(t &TypeList) !MypyTypeNode {
	return MypyTypeNode(*t)
}

// lookup_fully_qualified_typeinfo finds TypeInfo by fully qualified name
pub fn lookup_fully_qualified_typeinfo(modules map[string]MypyFile, name string, allow_missing bool) ?&TypeInfo {
	_ = allow_missing
	stnode := lookup_fully_qualified(name, modules)
	if st := stnode {
		if node := st.node {
			if node is TypeInfo {
				return &node
			}
		}
	}
	return none
}

// lookup_fully_qualified_alias finds TypeAlias by fully qualified name
pub fn lookup_fully_qualified_alias(modules map[string]MypyFile, name string, allow_missing bool) ?&TypeAlias {
	_ = allow_missing
	stnode := lookup_fully_qualified(name, modules)
	if st := stnode {
		if node := st.node {
			if node is TypeAlias {
				return &node
			}
		}
	}
	return none
}
