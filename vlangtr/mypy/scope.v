// scope.v — Track current scope to easily calculate the corresponding fine-grained target
// Translated from mypy/scope.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 08:20
//
// Translation notes:
//   - Scope: tracks which target we are processing at any given time
//   - SavedScope: tuple of (module, class, function) for saving/restoring scope
//   - Context managers replaced with explicit enter/leave methods

module mypy

// ---------------------------------------------------------------------------
// SavedScope — tuple for saving/restoring scope
// ---------------------------------------------------------------------------

pub struct SavedScope {
pub:
	module   string
	class    ?TypeInfo
	function ?FuncBase
}

// ---------------------------------------------------------------------------
// Scope — track which target we are processing
// ---------------------------------------------------------------------------

// Scope tracks which target we are processing at any given time.
@[heap]
pub struct Scope {
pub mut:
	module    ?string
	classes   []TypeInfo
	function  ?FuncBase
	functions []FuncBase
	ignored   int = 0
}

// current_module_id returns the current module id
pub fn (s &Scope) current_module_id() string {
	assert s.module != none
	return s.module or { '' }
}

// current_target returns the current target (non-class; for a class return enclosing module)
pub fn (s &Scope) current_target() string {
	assert s.module != none
	if f := s.function {
		return f.fullname
	}
	return s.module or { '' }
}

// current_full_target returns the current target (may be a class)
pub fn (s &Scope) current_full_target() string {
	assert s.module != none
	if f := s.function {
		return f.fullname
	}
	if s.classes.len > 0 {
		return s.classes[s.classes.len - 1].fullname
	}
	return s.module or { '' }
}

// current_type_name returns the current type's short name if it exists
pub fn (s &Scope) current_type_name() ?string {
	if s.classes.len > 0 {
		return s.classes[s.classes.len - 1].name
	}
	return none
}

// current_function_name returns the current function's short name if it exists
pub fn (s &Scope) current_function_name() ?string {
	if f := s.function {
		return f.name
	}
	return none
}

// module_scope enters a module scope
pub fn (mut s Scope) module_scope(prefix string) {
	s.module = prefix
	s.classes = []
	s.function = none
	s.ignored = 0
}

// module_scope_leave leaves a module scope
pub fn (mut s Scope) module_scope_leave() {
	s.module = none
}

// function_scope enters a function scope
pub fn (mut s Scope) function_scope(fdef FuncBase) {
	s.functions << fdef
	if s.function == none {
		s.function = fdef
	} else {
		// Nested functions are part of the topmost function target
		s.ignored++
	}
}

// function_scope_leave leaves a function scope
pub fn (mut s Scope) function_scope_leave() {
	s.functions.pop()
	if s.ignored > 0 {
		// Leave a scope that's included in the enclosing target
		s.ignored--
	} else {
		s.function = none
	}
}

// outer_functions returns the list of outer functions
pub fn (s &Scope) outer_functions() []FuncBase {
	if s.functions.len > 1 {
		return s.functions[..s.functions.len - 1]
	}
	return []
}

// enter_class enters a class target scope
pub fn (mut s Scope) enter_class(info TypeInfo) {
	if s.function == none {
		s.classes << info
	} else {
		// Classes within functions are part of the enclosing function target
		s.ignored++
	}
}

// leave_class leaves a class target scope
pub fn (mut s Scope) leave_class() {
	if s.ignored > 0 {
		// Leave a scope that's included in the enclosing target
		s.ignored--
	} else {
		assert s.classes.len > 0
		// Leave the innermost class
		s.classes.pop()
	}
}

// class_scope enters a class scope
pub fn (mut s Scope) class_scope(info TypeInfo) {
	s.enter_class(info)
}

// class_scope_leave leaves a class scope
pub fn (mut s Scope) class_scope_leave() {
	s.leave_class()
}

// save produces a saved scope that can be entered with saved_scope()
pub fn (s &Scope) save() SavedScope {
	assert s.module != none
	// We only save the innermost class, which is sufficient since
	// the rest are only needed for when classes are left
	cls := if s.classes.len > 0 { s.classes[s.classes.len - 1] } else { none }
	return SavedScope{
		module:   s.module or { '' }
		class:    cls
		function: s.function
	}
}

// saved_scope enters a saved scope
pub fn (mut s Scope) saved_scope(saved SavedScope) {
	mod_name := saved.module
	info := saved.class
	function := saved.function
	s.module_scope(mod_name)
	if info_ := info {
		s.class_scope(info_)
	}
	if f := function {
		s.function_scope(f)
	}
}

// saved_scope_leave leaves a saved scope
pub fn (mut s Scope) saved_scope_leave(saved SavedScope) {
	info := saved.class
	function := saved.function
	if f := function {
		s.function_scope_leave()
	}
	if info_ := info {
		s.class_scope_leave()
	}
	s.module_scope_leave()
}
