module classes

import ast

pub struct ClassDecoratorHandler {}

pub fn (h ClassDecoratorHandler) process_decorators(
	node ast.ClassDef,
	mut env ClassVisitEnv,
) ([]string, bool, bool, bool, string) {
	mut decorators := []string{}
	mut is_dataclass := false
	mut is_deprecated := false
	mut is_disjoint_base := false
	mut deprecated_message := ''

	for decorator in node.decorator_list {
		mut dec_str := ''
		if decorator is ast.Call {
			func := env.visit_expr_fn(decorator.func)
			mut dec_args := []string{}
			for arg in decorator.args {
				dec_args << env.visit_expr_fn(arg)
			}
			for kw in decorator.keywords {
				dec_args << '${kw.arg}=${env.visit_expr_fn(kw.value)}'
			}
			dec_str = '${func}(${dec_args.join(", ")})'
			if (func == 'deprecated' || func == 'warnings.deprecated') && dec_args.len > 0 {
				is_deprecated = true
				deprecated_message = dec_args[0].trim("'\"")
			}
		} else {
			dec_str = env.visit_expr_fn(decorator)
			if dec_str == 'deprecated' {
				is_deprecated = true
			} else if dec_str in ['disjoint_base', 'typing.disjoint_base'] {
				is_disjoint_base = true
			}
		}

		decorators << '// @${dec_str}'
		if dec_str.starts_with('dataclass') || dec_str.starts_with('dataclasses.dataclass') {
			is_dataclass = true
		}
	}

	return decorators, is_dataclass, is_deprecated, is_disjoint_base, deprecated_message
}

pub fn (h ClassDecoratorHandler) process_metaclass(node ast.ClassDef, mut env ClassVisitEnv) []string {
	mut decorators := []string{}
	for keyword in node.keywords {
		if keyword.arg == 'metaclass' {
			decorators << '// Metaclass: ${env.visit_expr_fn(keyword.value)}'
		}
	}
	return decorators
}
