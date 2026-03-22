// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 22:30
// Shared logic between mypy parser files (sharedparse.py)

module mypy

// _NON_BINARY_MAGIC_METHODS contains magic methods that are not binary operations.
const non_binary_magic_methods = [
	'__abs__',
	'__call__',
	'__complex__',
	'__contains__',
	'__buffer__',
	'__del__',
	'__delattr__',
	'__delitem__',
	'__enter__',
	'__exit__',
	'__float__',
	'__getattr__',
	'__getattribute__',
	'__getitem__',
	'__hex__',
	'__init__',
	'__init_subclass__',
	'__int__',
	'__invert__',
	'__iter__',
	'__len__',
	'__long__',
	'__neg__',
	'__new__',
	'__oct__',
	'__pos__',
	'__release_buffer__',
	'__repr__',
	'__reversed__',
	'__setattr__',
	'__setitem__',
	'__str__',
]

// MAGIC_METHODS_ALLOWING_KWARGS contains magic methods that allow keyword arguments.
const magic_methods_allowing_kwargs = [
	'__init__',
	'__init_subclass__',
	'__new__',
	'__call__',
	'__setattr__',
]

// BINARY_MAGIC_METHODS contains binary operation magic methods.
const binary_magic_methods = [
	'__add__',
	'__and__',
	'__divmod__',
	'__eq__',
	'__floordiv__',
	'__ge__',
	'__gt__',
	'__iadd__',
	'__iand__',
	'__idiv__',
	'__ifloordiv__',
	'__ilshift__',
	'__imatmul__',
	'__imod__',
	'__imul__',
	'__ior__',
	'__ipow__',
	'__irshift__',
	'__isub__',
	'__itruediv__',
	'__ixor__',
	'__le__',
	'__lshift__',
	'__lt__',
	'__matmul__',
	'__mod__',
	'__mul__',
	'__ne__',
	'__or__',
	'__pow__',
	'__radd__',
	'__rand__',
	'__rdiv__',
	'__rfloordiv__',
	'__rlshift__',
	'__rmatmul__',
	'__rmod__',
	'__rmul__',
	'__ror__',
	'__rpow__',
	'__rrshift__',
	'__rshift__',
	'__rsub__',
	'__rtruediv__',
	'__rxor__',
	'__sub__',
	'__truediv__',
	'__xor__',
]

// MAGIC_METHODS contains all magic methods (union of non-binary and binary).
pub const magic_methods = non_binary_magic_methods + binary_magic_methods

// MAGIC_METHODS_POS_ARGS_ONLY contains magic methods that are positional-args only.
pub const magic_methods_pos_args_only = magic_methods.filter(it !in magic_methods_allowing_kwargs)

// special_function_elide_names checks if a function name is a magic method that elides names.
pub fn special_function_elide_names(name string) bool {
	return name in magic_methods_pos_args_only
}

// argument_elide_name checks if an argument name should be elided.
// Returns true if name starts with "__" but doesn't end with "__".
pub fn argument_elide_name(name ?string) bool {
	if name == none {
		return false
	}
	n := name or { return false }
	return n.starts_with('__') && !n.ends_with('__')
}

// is_magic_method checks if a name is a magic method.
pub fn is_magic_method(name string) bool {
	return name in magic_methods
}

// is_binary_magic_method checks if a name is a binary magic method.
pub fn is_binary_magic_method(name string) bool {
	return name in binary_magic_methods
}

// is_non_binary_magic_method checks if a name is a non-binary magic method.
pub fn is_non_binary_magic_method(name string) bool {
	return name in non_binary_magic_methods
}

// magic_method_allows_kwargs checks if a magic method allows keyword arguments.
pub fn magic_method_allows_kwargs(name string) bool {
	return name in magic_methods_allowing_kwargs
}
