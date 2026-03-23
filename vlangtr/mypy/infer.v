module mypy

pub struct ArgumentInferContext {
pub:
	mapping_type  Instance
	iterable_type Instance
}

pub fn infer_function_type_arguments(callee_type &CallableType, arg_types []?MypyTypeNode, arg_kinds []ArgKind, arg_names []?string, formal_to_actual [][]int, context ArgumentInferContext, strict bool, allow_polymorphic bool) ([]?MypyTypeNode, []MypyTypeNode) {
	_ = arg_types
	_ = arg_kinds
	_ = arg_names
	_ = formal_to_actual
	_ = context
	_ = strict
	_ = allow_polymorphic
	mut inferred := []?MypyTypeNode{}
	for _ in callee_type.variables {
		inferred << MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	return inferred, callee_type.variables.clone()
}

pub fn infer_type_arguments(type_vars []MypyTypeNode, template MypyTypeNode, actual MypyTypeNode, is_supertype bool, skip_unsatisfied bool) []?MypyTypeNode {
	_ = template
	_ = actual
	_ = is_supertype
	_ = skip_unsatisfied
	mut inferred := []?MypyTypeNode{}
	for _ in type_vars {
		inferred << MypyTypeNode(AnyType{
			type_of_any: .special_form
		})
	}
	return inferred
}
