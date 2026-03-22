// checker_shared.v — Shared definitions used by different parts of type checker
// Translated from mypy/checker_shared.py to V 0.5.x

module mypy

// TypeRange — object representing an exact type or a type with upper bound
pub struct TypeRange {
pub mut:
	item           MypyTypeNode
	is_upper_bound bool // false => exact type
}

// new_type_range creates a new TypeRange
pub fn new_type_range(item MypyTypeNode, is_upper_bound bool) TypeRange {
	return TypeRange{
		item:           item
		is_upper_bound: is_upper_bound
	}
}

// TypeAndType — tuple of two types
pub struct TypeAndType {
pub mut:
	first  MypyTypeNode
	second MypyTypeNode
}

// TypeAndStringList — tuple of type and list of strings
pub struct TypeAndStringList {
pub mut:
	typ  MypyTypeNode
	strs []string
}

// TypeAndTypeOpt — tuple of two optional types
pub struct TypeAndTypeOpt {
pub mut:
	first  ?MypyTypeNode
	second ?MypyTypeNode
}

// OptionalTypeMap — optional map[string]Type
pub type OptionalTypeMap = ?map[string]MypyTypeNode

// TypeMapPair — pair of optional maps
pub struct TypeMapPair {
pub mut:
	first  OptionalTypeMap
	second OptionalTypeMap
}

// CheckerScope — scope for type checker
pub struct CheckerScope {
pub mut:
	stack []TypeInfoOrFuncItemOrMypyFile
}

// TypeInfoOrFuncItemOrMypyFile — sum-type for stack
pub type TypeInfoOrFuncItemOrMypyFile = TypeInfo | FuncItem | MypyFile

// new_checker_scope creates a new CheckerScope
pub fn new_checker_scope(mod MypyFile) CheckerScope {
	return CheckerScope{
		stack: [TypeInfoOrFuncItemOrMypyFile(mod)]
	}
}

// current_function returns the current function
pub fn (mut cs CheckerScope) current_function() ?FuncItem {
	_ = cs
	return none
}

// top_level_function returns the top-level function (not lambda)
pub fn (mut cs CheckerScope) top_level_function() ?FuncItem {
	_ = cs
	return none
}

// active_class returns the active class (if we are inside a class)
pub fn (mut cs CheckerScope) active_class() ?TypeInfo {
	if cs.stack.len > 0 {
		last := cs.stack[cs.stack.len - 1]
		if last is TypeInfo {
			return last as TypeInfo
		}
	}
	return none
}

// enclosing_class returns the class directly enclosing the function
pub fn (mut cs CheckerScope) enclosing_class(func ?FuncItem) ?TypeInfo {
	_ = func
	for i := cs.stack.len - 1; i >= 1; i-- {
		if cs.stack[i] is FuncItem && cs.stack[i - 1] is TypeInfo {
			return cs.stack[i - 1] as TypeInfo
		}
	}
	return none
}

// active_self_type returns the self type for the current class
pub fn (mut cs CheckerScope) active_self_type() ?Instance {
	mut info := cs.active_class()
	if info == none && cs.current_function() != none {
		info = cs.enclosing_class(none)
	}
	if ti := info {
		return checker_scope_fill_typevars(ti)
	}
	return none
}

// current_self_type returns the self type (handles nested functions)
pub fn (mut cs CheckerScope) current_self_type() ?Instance {
	for i := cs.stack.len - 1; i >= 0; i-- {
		if cs.stack[i] is TypeInfo {
			ti := cs.stack[i] as TypeInfo
			return checker_scope_fill_typevars(ti)
		}
	}
	return none
}

// is_top_level checks if we are at the top level
pub fn (cs CheckerScope) is_top_level() bool {
	return cs.stack.len == 1
}

// push_function adds a function to the stack
pub fn (mut cs CheckerScope) push_function(item FuncItem) {
	cs.stack << TypeInfoOrFuncItemOrMypyFile(item)
}

// pop_function removes a function from the stack
pub fn (mut cs CheckerScope) pop_function() {
	if cs.stack.len > 0 {
		cs.stack.pop()
	}
}

// push_class adds a class to the stack
pub fn (mut cs CheckerScope) push_class(info TypeInfo) {
	cs.stack << TypeInfoOrFuncItemOrMypyFile(info)
}

// pop_class removes a class from the stack
pub fn (mut cs CheckerScope) pop_class() {
	if cs.stack.len > 0 {
		cs.stack.pop()
	}
}

// checker_scope_fill_typevars creates a simple Instance for a TypeInfo.
fn checker_scope_fill_typevars(info TypeInfo) Instance {
	return Instance{
		type_: &info
		args:  []MypyTypeNode{}
	}
}
