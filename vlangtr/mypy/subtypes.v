// I, Cline, am working on this file. Started: 2026-03-22 15:20
// subtypes.v — Subtype checking for mypy types
// Translated from mypy/subtypes.py

module mypy

// Flags for detected protocol members
pub const is_settable = 1
pub const is_classvar = 2
pub const is_class_or_static = 3
pub const is_var = 4
pub const is_explicit_setter = 5

// SubtypeContext — subtype checking context
pub struct SubtypeContext {
pub:
	ignore_type_params       bool
	ignore_pos_arg_names     bool
	ignore_declared_variance bool
	always_covariant         bool
	ignore_promotions        bool
	erase_instances          bool
	keep_erased_types        bool
	options                  ?Options
}

// new_subtype_context creates a new SubtypeContext
pub fn new_subtype_context(ignore_type_params bool, ignore_pos_arg_names bool, ignore_declared_variance bool, always_covariant bool, ignore_promotions bool, erase_instances bool, keep_erased_types bool, options ?Options) SubtypeContext {
	return SubtypeContext{
		ignore_type_params:       ignore_type_params
		ignore_pos_arg_names:     ignore_pos_arg_names
		ignore_declared_variance: ignore_declared_variance
		always_covariant:         always_covariant
		ignore_promotions:        ignore_promotions
		erase_instances:          erase_instances
		keep_erased_types:        keep_erased_types
		options:                  options
	}
}

// is_subtype checks if left is a subtype of right
// Also considers Any to be a subtype of any type and vice versa
pub fn is_subtype_ctx(left MypyTypeNode, right MypyTypeNode, subtype_context SubtypeContext) bool {
	if left.str() == right.str() {
		return true
	}
	// TODO: full implementation with SubtypeVisitor
	return is_subtype_internal(left, right, subtype_context)
}

// is_subtype_internal — internal implementation of subtype checking
fn is_subtype_internal(left MypyTypeNode, right MypyTypeNode, ctx SubtypeContext) bool {
	left_proper := get_proper_type(left)
	right_proper := get_proper_type(right)

	// AnyType is a subtype of any type (for non-proper)
	if !ctx.erase_instances && !ctx.keep_erased_types {
		if right_proper is AnyType || right_proper is UnboundType || right_proper is ErasedType {
			if left_proper !is UnpackType {
				return true
			}
		}
	}

	// UnionType check
	if right_proper is UnionType && left_proper !is UnionType {
		for item in right_proper.items {
			if is_subtype_ctx(left, item, ctx) {
				return true
			}
		}
		return false
	}

	// Instance -> Instance
	if left_proper is Instance && right_proper is Instance {
		return is_instance_subtype(left_proper, right_proper, ctx)
	}

	// NoneType
	if left_proper is NoneType {
		if right_proper is NoneType || is_named_instance(right_proper, 'builtins.object') {
			return true
		}
		return false
	}

	// AnyType
	if left_proper is AnyType {
		return !ctx.erase_instances
	}

	// UninhabitedType (Never) — subtype of everything
	if left_proper is UninhabitedType {
		return true
	}

	// TypeVarType
	if left_proper is TypeVarType && right_proper is TypeVarType {
		if left_proper.id == right_proper.id {
			return true
		}
		return is_subtype_ctx(left_proper.upper_bound, right, ctx)
	}

	// CallableType
	if left_proper is CallableType && right_proper is CallableType {
		return is_callable_subtype(left_proper, right_proper, ctx)
	}

	// TupleType
	if left_proper is TupleType && right_proper is TupleType {
		if left_proper.items.len != right_proper.items.len {
			return false
		}
		for i in 0 .. left_proper.items.len {
			if !is_subtype_ctx(left_proper.items[i], right_proper.items[i], ctx) {
				return false
			}
		}
		return true
	}

	// TypedDictType
	if left_proper is TypedDictType && right_proper is TypedDictType {
		return is_typeddict_subtype(left_proper, right_proper, ctx)
	}

	return false
}

// is_instance_subtype checks subtype for Instance
fn is_instance_subtype(left Instance, right Instance, ctx SubtypeContext) bool {
	// Check cache
	mut ts := mut_type_state()
	kind := make_subtype_kind(false, ctx.ignore_promotions)
	if ts.is_cached_subtype_check(kind, &left, &right) {
		return true
	}
	if ts.is_cached_negative_subtype_check(kind, &left, &right) {
		return false
	}

	// Promotions
	if !ctx.ignore_promotions {
		if rti := right.typ {
			if !rti.is_protocol {
				if lti := left.typ {
					for base in lti.mro {
						if base.promote_types.len > 0 {
							for p in base.promote_types {
								if is_subtype_ctx(p, right, ctx) {
									ts.record_subtype_cache_entry(kind, &left, &right)
									return true
								}
							}
						}
					}
				}
			}
		}
	}

	// Nominal check
	if rti := right.typ {
		rname := rti.fullname
		if lti := left.typ {
			if lti.has_base(rname) || rname == 'builtins.object' {
				mapped := map_instance_to_supertype(left, rti)

				// Check type arguments
				if !ctx.ignore_type_params {
					for i, tvar in rti.type_vars {
						if i >= mapped.args.len || i >= right.args.len {
							continue
						}
						left_arg := mapped.args[i]
						right_arg := right.args[i]

						if tvar is TypeVarType {
							tvt := tvar as TypeVarType
							mut variance := tvt.variance
							if ctx.always_covariant && variance == 0 {
								variance = 1 // COVARIANT
							}
							if !check_type_parameter(left_arg, right_arg, int(variance), ctx) {
								ts.record_negative_subtype_cache_entry(kind, &left, &right)
								return false
							}
						}
					}
				}
				ts.record_subtype_cache_entry(kind, &left, &right)
				return true
			}
		}
	}

	// Protocols
	if rti := right.typ {
		if rti.is_protocol {
			if is_protocol_implementation(left, right, ctx) {
				return true
			}
		}
	}

	ts.record_negative_subtype_cache_entry(kind, &left, &right)
	return false
}

// check_type_parameter checks a type parameter considering variance
fn check_type_parameter(left MypyTypeNode, right MypyTypeNode, variance int, ctx SubtypeContext) bool {
	// INVARIANT = 0, COVARIANT = 1, CONTRAVARIANT = -1
	if variance == 1 { // COVARIANT
		return is_subtype_ctx(left, right, ctx)
	} else if variance == -1 { // CONTRAVARIANT
		return is_subtype_ctx(right, left, ctx)
	} else { // INVARIANT
		return is_subtype_ctx(left, right, ctx) && is_subtype_ctx(right, left, ctx)
	}
}

// is_callable_subtype checks subtype for CallableType
fn is_callable_subtype(left CallableType, right CallableType, ctx SubtypeContext) bool {
	// Check return type (covariantly)
	if !is_subtype_ctx(left.ret_type, right.ret_type, ctx) {
		return false
	}

	// Check arguments (contravariantly)
	if left.arg_types.len != right.arg_types.len {
		return false
	}
	for i in 0 .. left.arg_types.len {
		if !is_subtype_ctx(right.arg_types[i], left.arg_types[i], ctx) {
			return false
		}
	}

	return true
}

// is_typeddict_subtype checks subtype for TypedDictType
fn is_typeddict_subtype(left TypedDictType, right TypedDictType, ctx SubtypeContext) bool {
	// Check that left contains all keys of right
	for key in right.items.keys() {
		if key !in left.items {
			return false
		}
		left_type := left.items[key] or { return false }
		right_type := right.items[key] or { return false }

		// Required vs NotRequired check
		left_required := key in left.required_keys
		right_required := key in right.required_keys
		if !right_required && left_required {
			return false
		}

		// Readonly check
		left_readonly := key in left.readonly_keys
		right_readonly := key in right.readonly_keys
		if !right_readonly && left_readonly {
			return false
		}

		// Types must be compatible
		if right_readonly {
			if !is_subtype_ctx(left_type, right_type, ctx) {
				return false
			}
		} else {
			if !is_subtype_ctx(left_type, right_type, ctx) || !is_subtype_ctx(right_type, left_type, ctx) {
				return false
			}
		}
	}
	return true
}

pub fn is_protocol_implementation(left Instance, right Instance, ctx SubtypeContext) bool {
	right_info := right.typ or { return false }
	left_info := left.typ or { return false }

	for name, sym in right_info.names.symbols {
		if name.starts_with('__') && name.ends_with('__') && name !in ['__call__', '__iter__'] {
			continue
		}

		left_sym := left_info.names.symbols[name] or { return false }

		// Check compatibility of protocol member types
		if sym.node != none && left_sym.node != none {
			right_node := sym.node
			left_node := left_sym.node
			right_type := right_node.node_type() or { continue }
			left_type := left_node.node_type() or { continue }
			if !is_subtype_ctx(left_type, right_type, ctx) {
				return false
			}
		}
	}

	return true
}

// is_proper_subtype checks proper subtype
pub fn is_proper_subtype(left MypyTypeNode, right MypyTypeNode, ctx SubtypeContext) bool {
	left_proper := get_proper_type(left)
	right_proper := get_proper_type(right)

	// AnyType is not a proper subtype (except when both are AnyType)
	if left_proper is AnyType {
		return right_proper is AnyType
	}
	if right_proper is AnyType {
		return false
	}

	// UninhabitedType (Never) is a proper subtype of everything
	if left_proper is UninhabitedType {
		return true
	}

	// Check via is_subtype
	return is_subtype_ctx(left, right, ctx)
}

// is_equivalent checks type equivalence
pub fn is_equivalent_ctx(a MypyTypeNode, b MypyTypeNode, ctx SubtypeContext) bool {
	return is_subtype_ctx(a, b, ctx) && is_subtype_ctx(b, a, ctx)
}

pub fn is_same_type_ctx(a MypyTypeNode, b MypyTypeNode, ctx SubtypeContext) bool {
	return is_proper_subtype(a, b, ctx) && is_proper_subtype(b, a, ctx)
}

// is_named_instance checks if the type is a named instance
fn is_named_instance(typ MypyTypeNode, fullname string) bool {
	if typ is Instance {
		it := typ as Instance
		if info := it.typ {
			return info.fullname == fullname
		}
	}
	return false
}

// get_proper_type returns the proper type

