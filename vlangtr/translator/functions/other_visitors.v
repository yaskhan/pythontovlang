module functions

import ast
import analyzer
import base

// visit_lambda generates a V closure for Python lambda expressions.
pub fn visit_lambda(
	node &ast.Lambda,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_expr_fn fn (ast.Expression) string,
	indent_fn fn () string,
	sanitize_fn fn (string, bool) string,
	map_type_fn fn (string, string, bool, bool, bool) string,
	guess_type_fn fn (ast.Expression) string,
	find_captured_vars_fn fn (ast.ASTNode, []map[string]bool, fn (string, bool) string) []string,
) string {
	mut defaults_map := map[string]ast.Expression{}
	for param in node.args.posonlyargs {
		if default_expr := param.default_ {
			defaults_map[param.arg] = default_expr
		}
	}
	for param in node.args.args {
		if default_expr := param.default_ {
			defaults_map[param.arg] = default_expr
		}
	}
	for param in node.args.kwonlyargs {
		if default_expr := param.default_ {
			defaults_map[param.arg] = default_expr
		}
	}

	mut current_scope := map[string]bool{}
	mut args_str_list := []string{}
	mut extra_captures := []string{}

	mut all_args := node.args.posonlyargs.clone()
	all_args << node.args.args
	all_args << node.args.kwonlyargs

	for arg in all_args {
		arg_name := sanitize_fn(arg.arg, false)
		mut is_capture_by_value := false
		if arg.arg in defaults_map {
			default_expr := defaults_map[arg.arg]
			if default_expr is ast.Name && default_expr.id == arg.arg {
				extra_captures << arg_name
				is_capture_by_value = true
			}
		}
		if is_capture_by_value {
			continue
		}

		current_scope[arg.arg] = true
		mut arg_type := 'int'
		inferred := analyzer_ref.type_map[arg_name]
		if inferred != '' {
			arg_type = map_type_fn(inferred, '', true, true, false)
		}
		args_str_list << '${arg_name} ${arg_type}'
	}

	if kwarg := node.args.kwarg {
		arg_name := sanitize_fn(kwarg.arg, false)
		current_scope[kwarg.arg] = true
		mut arg_type := 'map[string]Any'
		inferred := analyzer_ref.type_map[arg_name]
		if inferred != '' {
			arg_type = map_type_fn(inferred, '', true, true, false)
		}
		args_str_list << '${arg_name} ${arg_type}'
	}

	if vararg := node.args.vararg {
		arg_name := sanitize_fn(vararg.arg, false)
		current_scope[vararg.arg] = true
		mut arg_type := 'Any'
		inferred := analyzer_ref.type_map[arg_name]
		if inferred != '' {
			arg_type = map_type_fn(inferred, '', true, true, false)
		}
		if !arg_type.starts_with('[]') {
			arg_type = '[]${arg_type}'
		}
		args_str_list << '${arg_name} ${arg_type}'
	}

	args_str := args_str_list.join(', ')
	mut captures := find_captured_vars_fn(node, state.scope_stack, sanitize_fn)
	if extra_captures.len > 0 {
		mut existing := map[string]bool{}
		for cap in captures {
			existing[cap] = true
		}
		for name in extra_captures {
			if name !in existing {
				captures << name
				existing[name] = true
			}
		}
	}

	capture_str := if captures.len > 0 { '[${captures.join(', ')}] ' } else { '' }

	if node.body is ast.Constant {
		const_node := node.body
		if const_node.value == 'None' || const_node.value == '...' {
			return 'fn ${capture_str}(${args_str}) {}'
		}
	}

	state.scope_stack << current_scope
	state.scope_names << '<lambda>'
	defer {
		state.scope_stack = state.scope_stack[..state.scope_stack.len - 1]
		state.scope_names = state.scope_names[..state.scope_names.len - 1]
	}

	body := visit_expr_fn(node.body)
	body_type := map_type_fn(guess_type_fn(node.body), '', true, true, true)
	if body_type == 'void' {
		if body == 'none' {
			return 'fn ${capture_str}(${args_str}) {}'
		}
		return 'fn ${capture_str}(${args_str}) { ${body} }'
	}
	return 'fn ${capture_str}(${args_str}) ${body_type} { return ${body} }'
}

pub fn visit_yield(
	node &ast.Yield,
	mut state base.TranslatorState,
	visit_expr_fn fn (ast.Expression) string,
	indent_fn fn () string,
) string {
	_ = state
	_ = indent_fn
	active_channel := ''
	active_in_channel := ''
	if active_channel.len > 0 {
		val := if value := node.value { visit_expr_fn(value) } else { '0' }
		return 'py_yield(${active_channel}, ${active_in_channel}, ${val})'
	}
	mut val := ''
	if value := node.value {
		val = visit_expr_fn(value)
	}
	return '/* yield ${val} */'
}

pub fn visit_yield_from(
	node &ast.YieldFrom,
	mut state base.TranslatorState,
	visit_expr_fn fn (ast.Expression) string,
	indent_fn fn () string,
	emit_fn fn (string),
) ?string {
	_ = state
	active_channel := ''
	active_in_channel := ''
	if active_channel.len > 0 {
		val := visit_expr_fn(node.value)
		emit_fn('${indent_fn()}for v in ${val} {')
		emit_fn('${indent_fn()}py_yield(${active_channel}, ${active_in_channel}, v)')
		emit_fn('${indent_fn()}}')
		return none
	}
	val := visit_expr_fn(node.value)
	return '/* yield from ${val} */'
}

pub fn visit_await(
	node &ast.Await,
	visit_expr_fn fn (ast.Expression) string,
) string {
	return '/* await */ ${visit_expr_fn(node.value)}'
}

pub fn visit_global(
	node &ast.Global,
	mut state base.TranslatorState,
	indent_fn fn () string,
	emit_fn fn (string),
) {
	_ = state
	emit_fn('${indent_fn()}//##LLM@@ Python global or nonlocal scope modification detected. V heavily discourages global state.')
	emit_fn('${indent_fn()}// global ${node.names.join(', ')}')
}

pub fn visit_nonlocal(
	node &ast.Nonlocal,
	mut state base.TranslatorState,
	indent_fn fn () string,
	emit_fn fn (string),
) {
	_ = state
	emit_fn('${indent_fn()}//##LLM@@ Python global or nonlocal scope modification detected. V heavily discourages global state.')
	emit_fn('${indent_fn()}// nonlocal ${node.names.join(', ')}')
}

pub fn visit_return(
	node &ast.Return,
	mut state base.TranslatorState,
	analyzer_ref &analyzer.Analyzer,
	visit_expr_fn fn (ast.Expression) string,
	indent_fn fn () string,
	emit_fn fn (string),
) {
	_ = analyzer_ref
	_ = state
	active_channel := ''
	if active_channel.len > 0 {
		emit_fn('${indent_fn()}${active_channel}.close()')
	}
	for _ in 0..state.vexc_depth {
		emit_fn('${indent_fn()}vexc.end_try()')
	}
	if state.in_init && node.value == none {
		class_info := if state.current_class in state.defined_classes {
			state.defined_classes[state.current_class]
		} else {
			map[string]bool{}
		}
		if class_info['is_pydantic'] {
			emit_fn('${indent_fn()}self.validate() or { return err }')
		}
		emit_fn('${indent_fn()}return self')
		return
	}
	if value := node.value {
		val := visit_expr_fn(value)
		if state.current_function_return_type == 'void' && val == 'none' {
			emit_fn('${indent_fn()}return')
		} else {
			emit_fn('${indent_fn()}return ${val}')
		}
		return
	}
	emit_fn('${indent_fn()}return')
}
