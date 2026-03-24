// scope.v — Scope tracking for semantic analysis
// Translated from mypy/scope.py

module mypy

// Scope — tracks the current module, class, and function context
pub struct Scope {
pub mut:
	module    ?string
	classes   []TypeInfo
	function  ?FuncItem
	functions []FuncItem
	ignored   int
}

// new_scope creates a new Scope
pub fn new_scope() Scope {
	return Scope{
		module:    none
		classes:   []TypeInfo{}
		function:  none
		functions: []FuncItem{}
		ignored:   0
	}
}

// enter_module enters a module scope
pub fn (mut s Scope) enter_module(fullname string) Scope {
	prev := s.save()
	s.module = fullname
	return prev
}

// class_scope enters a class scope
pub fn (mut s Scope) class_scope(info TypeInfo) {
	s.classes << info
}

// class_scope_leave leaves a class scope
pub fn (mut s Scope) class_scope_leave() {
	s.classes.pop()
}

// current_class returns the current TypeInfo
pub fn (s &Scope) current_class() ?TypeInfo {
	if s.classes.len > 0 {
		return s.classes.last()
	}
	return none
}

// current_function_full_name returns the fullname of the current function
pub fn (s &Scope) current_function_full_name() string {
	assert s.module != none
	if f := s.function {
		return match f {
			FuncDef { f.fullname }
			OverloadedFuncDef {
				if f.items.len > 0 { f.items[0].fullname } else { '' }
			}
			Decorator { f.func.fullname }
			LambdaExpr { '<lambda>' }
		}
	}
	return s.module or { '' }
}

// current_full_name returns the fullname of the current scope
pub fn (s &Scope) current_full_name() string {
	assert s.module != none
	if f := s.function {
		return match f {
			FuncDef { f.fullname }
			OverloadedFuncDef {
				if f.items.len > 0 { f.items[0].fullname } else { '' }
			}
			Decorator { f.func.fullname }
			LambdaExpr { '<lambda>' }
		}
	}
	if s.classes.len > 0 {
		return s.classes.last().fullname
	}
	return s.module or { '' }
}

// current_module returns the current module fullname
pub fn (s &Scope) current_module() string {
	return s.module or { '' }
}

// is_class_scope checks if we are in a class (not nested in a function)
pub fn (s &Scope) is_class_scope() bool {
	return s.classes.len > 0 && s.function == none
}

// current_function_name returns the name of the current function
pub fn (s &Scope) current_function_name() ?string {
	if f := s.function {
		return match f {
			FuncDef { f.name }
			OverloadedFuncDef {
				// We usually want the name of the items (they all should have same name)
				if f.items.len > 0 { f.items[0].name } else { '' }
			}
			Decorator { f.func.name }
			LambdaExpr { '<lambda>' }
		}
	}
	return none
}

// function_scope enters a function scope
pub fn (mut s Scope) function_scope(fdef FuncItem) {
	s.functions << fdef
	s.function = fdef
}

// function_scope_leave leaves a function scope
pub fn (mut s Scope) function_scope_leave() {
	s.functions.pop()
	if s.functions.len > 0 {
		s.function = s.functions.last()
	} else {
		s.function = none
	}
}

// outer_functions returns the list of outer functions
pub fn (s &Scope) outer_functions() []FuncItem {
	if s.functions.len > 1 {
		return s.functions[..s.functions.len - 1]
	}
	return []
}

// save returns a scope snapshot
pub fn (s &Scope) save() Scope {
	return Scope{
		module:    s.module
		classes:   s.classes.clone()
		function:  s.function
		functions: s.functions.clone()
		ignored:   s.ignored
	}
}

pub fn (mut s Scope) restore(prev Scope) {
	s.module = prev.module
	s.classes = prev.classes
	s.function = prev.function
	s.functions = prev.functions
	s.ignored = prev.ignored
}

pub fn (mut s Scope) enter_function(func FuncItem) Scope {
	prev := s.save()
	s.function = func
	s.functions << func
	return prev
}

pub fn (mut s Scope) enter_class(info &TypeInfo) Scope {
	prev := s.save()
	s.classes << *info
	return prev
}

pub fn (mut s Scope) leave(prev Scope) {
	s.restore(prev)
}
