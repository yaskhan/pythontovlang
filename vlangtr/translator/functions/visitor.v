module functions

import ast

pub struct FunctionsVisitorHandler {}

pub fn (h FunctionsVisitorHandler) visit_function_def(node &ast.FunctionDef, mut env FunctionVisitEnv, mut m FunctionsModule) {
	for dec in node.decorator_list {
		dec_name := env.visit_expr_fn(dec)
		if dec_name == 'overload' {
			env.state.overloads[node.name] << node
			return
		}
	}
	m.generation_handler.generate_function(node, env.state.current_class, mut env, mut m)
}
