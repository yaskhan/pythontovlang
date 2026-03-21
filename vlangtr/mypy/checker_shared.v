// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 05:15
module mypy

pub struct TypeRange {
pub:
	item           MypyTypeNode
	is_upper_bound bool
}

pub interface ExpressionCheckerSharedApi {
	accept(node Expression, type_context ?MypyTypeNode, allow_none_return bool, always_allow_any bool, is_callee bool) MypyTypeNode
	analyze_ref_expr(e RefExpr, lvalue bool) MypyTypeNode
	// ... more
}

pub interface TypeCheckerSharedApi {
	// plugin &Plugin
	// module_refs set[string]
	// scope &CheckerScope
	
	expr_checker() &ExpressionCheckerSharedApi
	named_type(name string, args []MypyTypeNode) &Instance
	lookup_typeinfo(fullname string) &TypeInfo
	lookup_type(node Expression) MypyTypeNode
	handle_cannot_determine_type(name string, context Context)
	handle_partial_var_type(typ &PartialType, is_lvalue bool, node &Var, context Context) MypyTypeNode
	
	check_subtype(subtype MypyTypeNode, supertype MypyTypeNode, context Context, msg string, subtype_label ?string, supertype_label ?string, notes []string, code ?&ErrorCode, outer_context ?Context) bool
}

pub struct CheckerScope {
pub mut:
	stack []MypyNode // TypeInfo | FuncItem | MypyFile
}

pub fn (s &CheckerScope) current_function() ?FuncItem {
	for i := s.stack.len - 1; i >= 0; i-- {
		node := s.stack[i]
		if node is FuncDef { return node }
		if node is OverloadedFuncDef { return node }
		if node is Decorator { return node.func }
	}
	return none
}

pub fn (s &CheckerScope) active_class() ?&TypeInfo {
	if s.stack.len > 0 {
		last := s.stack.last()
		if last is TypeInfo { return last }
	}
	return none
}

pub fn (s &CheckerScope) enclosing_class(func ?FuncItem) ?&TypeInfo {
	f := func or { s.current_function()? }
	// Find index of f in stack
	mut index := -1
	for i, node in s.stack {
		// This is tricky because MypyNode is a sum type of pointers
		// We'll assume we can find it by some ID or just iterate
		if node == f { // Need to verify if this works for sum types of pointers
			index = i
			break
		}
	}
	if index > 0 {
		enclosing := s.stack[index - 1]
		if enclosing is TypeInfo { return enclosing }
	}
	return none
}
