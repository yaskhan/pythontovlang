module pydantic_support

import analyzer
import ast
import base

pub struct PydanticVisitEnv {
pub mut:
	state            base.TranslatorState
	analyzer         analyzer.Analyzer
	visit_stmt_fn    fn (ast.Statement)
	visit_expr_fn    fn (ast.Expression) string
	emit_struct_fn   fn (string)
	emit_function_fn fn (string)
	emit_constant_fn fn (string)
	source_mapping   bool
}

pub fn new_pydantic_visit_env(
	state base.TranslatorState,
	analyzer_ref analyzer.Analyzer,
	visit_stmt_fn fn (ast.Statement),
	visit_expr_fn fn (ast.Expression) string,
	emit_struct_fn fn (string),
	emit_function_fn fn (string),
	emit_constant_fn fn (string),
	source_mapping bool,
) PydanticVisitEnv {
	return PydanticVisitEnv{
		state:            state
		analyzer:         analyzer_ref
		visit_stmt_fn:    visit_stmt_fn
		visit_expr_fn:    visit_expr_fn
		emit_struct_fn:   emit_struct_fn
		emit_function_fn: emit_function_fn
		emit_constant_fn: emit_constant_fn
		source_mapping:   source_mapping
	}
}

fn sanitize_name(name string, is_type bool) string {
	return base.sanitize_name(name, is_type, map[string]bool{}, '', map[string]bool{})
}

fn trim_quotes(value string) string {
	mut out := value.trim_space()
	if out.len >= 2 {
		if (out.starts_with("'") && out.ends_with("'")) || (out.starts_with('"') && out.ends_with('"')) {
			out = out[1..out.len - 1]
		}
	}
	return out
}
