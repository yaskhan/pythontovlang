module expressions

import analyzer
import ast
import base
import models

pub struct ExprGen {
pub mut:
	model    models.VType
	analyzer analyzer.Analyzer
	state    base.TranslatorState
}

pub fn new_expr_gen(model &models.VType, type_analyzer &analyzer.Analyzer) ExprGen {
	return ExprGen{
		model:    *model
		analyzer: *type_analyzer
		state:    base.new_translator_state()
	}
}

fn (eg &ExprGen) type_ctx() base.TypeGuessingContext {
	return base.TypeGuessingContext{
		type_map:        eg.analyzer.type_map
		location_map:    eg.analyzer.location_map
		known_v_types:   eg.state.known_v_types
		name_remap:      eg.state.name_remap
		defined_classes: eg.state.defined_classes
	}
}

pub fn (eg &ExprGen) guess_type(node ast.Expression) string {
	return base.guess_type(node, eg.type_ctx(), true)
}

pub fn (eg &ExprGen) guess_type_no_loc(node ast.Expression) string {
	return base.guess_type(node, eg.type_ctx(), false)
}

pub fn (mut eg ExprGen) wrap_bool(node ast.Expression, invert bool) string {
	expr := eg.visit(node)
	v_type := eg.guess_type(node)
	return base.wrap_bool(node, expr, v_type, invert)
}

pub fn (eg &ExprGen) indent() string {
	return eg.state.indent()
}

fn (mut eg ExprGen) emit(line string) {
	eg.state.output << '${eg.indent()}${line}'
}

pub fn (mut eg ExprGen) visit(node ast.Expression) string {
	match node {
		ast.Name { return eg.visit_name(node) }
		ast.Constant { return eg.visit_constant(node) }
		ast.NoneExpr { return 'none' }
		ast.List { return eg.visit_list(node) }
		ast.Tuple { return eg.visit_tuple(node) }
		ast.Dict { return eg.visit_dict(node) }
		ast.Set { return eg.visit_set(node) }
		ast.BinaryOp { return eg.visit_bin_op(node) }
		ast.UnaryOp { return eg.visit_unary_op(node) }
		ast.Compare { return eg.visit_compare(node) }
		ast.Call { return eg.visit_call(node) }
		ast.Attribute { return eg.visit_attribute(node) }
		ast.Subscript { return eg.visit_subscript(node) }
		ast.Slice { return eg.visit_slice(node) }
		ast.ListComp { return eg.visit_list_comp(node, '') or { '[]' } }
		ast.GeneratorExp { return eg.visit_generator_exp(node, '') or { '[]' } }
		ast.DictComp { return eg.visit_dict_comp(node, '') or { '{}' } }
		ast.SetComp { return eg.visit_set_comp(node, '') or { '{}' } }
		ast.IfExp { return eg.visit_if_exp(node) }
		ast.Starred { return eg.visit_starred(node) }
		ast.JoinedStr { return eg.visit_joined_str(node) }
		ast.FormattedValue { return eg.visit_formatted_value(node) }
		ast.Lambda { return eg.visit_lambda(node) }
		ast.NamedExpr { return eg.visit_named_expr(node) }
		else { return '/* unsupported expr */' }
	}
}

pub fn (mut eg ExprGen) visit_name(node ast.Name) string {
	name := eg.state.name_remap[node.id] or { node.id }
	return base.sanitize_name(name, false, map[string]bool{}, '', map[string]bool{})
}

fn (eg &ExprGen) extract_string_content(value string) string {
	if value.len >= 3 && value[0] == `t` && (value[1] == `'` || value[1] == `"`) {
		return value[2..value.len - 1]
	}
	if value.len >= 2 && (value[0] == `'` || value[0] == `"`) {
		return value[1..value.len - 1]
	}
	return value
}

fn (eg &ExprGen) quote_string_content(value string) string {
	if value.len == 0 {
		return "''"
	}

	if value.contains('\\') {
		if !value.contains("'") {
			return "r'${value}'"
		}
		if !value.contains('"') {
			return 'r"${value}"'
		}
	}

	mut escaped := value.replace('\\', '\\\\')
	escaped = escaped.replace("'", "\\'")
	escaped = escaped.replace('\n', '\\n')
	escaped = escaped.replace('\r', '\\r')
	escaped = escaped.replace('\t', '\\t')
	return "'${escaped}'"
}

fn (mut eg ExprGen) translate_tstring(values []ast.Expression) string {
	if values.len == 0 {
		return ''
	}
	if values[0] is ast.Constant {
		first := values[0] as ast.Constant
		if !first.value.starts_with('__py2v_t__')
			&& !first.value.starts_with('t\'')
			&& !first.value.starts_with('t"')
			&& first.token.typ != .tstring_tok {
			return ''
		}

		mut strings := []string{}
		mut interpolations := []string{}

		for i, value in values {
			match value {
				ast.Constant {
					mut content := value.value
					if content.starts_with('__py2v_t__') {
						content = content['__py2v_t__'.len..]
					}
					content = eg.extract_string_content(content)
					strings << eg.quote_string_content(content)
				}
				ast.FormattedValue {
					if i == 0 {
						strings << "''"
					}
					expr_text := eg.visit(value.value)
					conversion := match value.conversion {
						114 {
							eg.state.used_builtins['py_repr'] = true
							"'r'"
						}
						115 { "'s'" }
						97 {
							eg.state.used_builtins['py_ascii'] = true
							"'a'"
						}
						else { "'none'" }
					}
					mut format_spec := "''"
					if format_spec_node := value.format_spec {
						format_spec = eg.visit(format_spec_node)
					}
					interpolations << 'Interpolation{value: ${expr_text}, expression: ${eg.quote_string_content(expr_text)}, conversion: ${conversion}, format_spec: ${format_spec}}'
					if i == values.len - 1 {
						strings << "''"
					}
				}
				else {}
			}
		}

		for strings.len < interpolations.len + 1 {
			strings << "''"
		}

		return 'Template{strings: [${strings.join(', ')}], interpolations: [${interpolations.join(', ')}]}'
	}
	return ''
}

pub fn (mut eg ExprGen) visit_constant(node ast.Constant) string {
	if node.value == 'None' {
		return 'none'
	}
	if node.value == 'True' {
		return 'true'
	}
	if node.value == 'False' {
		return 'false'
	}
	if node.token.typ == .tstring_tok || node.value.starts_with('__py2v_t__')
		|| node.value.starts_with('t\'') || node.value.starts_with('t"') {
		mut content := node.value
		if content.starts_with('__py2v_t__') {
			content = content['__py2v_t__'.len..]
		}
		content = eg.extract_string_content(content)
		return 'Template{strings: [${eg.quote_string_content(content)}], interpolations: []}'
	}
	if node.token.typ == .string_tok || node.token.typ == .fstring_tok {
		if node.value.starts_with("'") || node.value.starts_with('"') || node.value.starts_with('t\'')
			|| node.value.starts_with('t"') {
			return node.value
		}
		return "'${node.value}'"
	}
	return node.value
}

pub fn (mut eg ExprGen) visit_list(node ast.List) string {
	mut values := []string{}
	for elt in node.elements {
		values << eg.visit(elt)
	}
	return '[${values.join(', ')}]'
}

pub fn (mut eg ExprGen) visit_tuple(node ast.Tuple) string {
	mut values := []string{}
	for elt in node.elements {
		values << eg.visit(elt)
	}
	return '[${values.join(', ')}]'
}

pub fn (mut eg ExprGen) visit_dict(node ast.Dict) string {
	mut items := []string{}
	for i, key in node.keys {
		if i >= node.values.len {
			break
		}
		val := eg.visit(node.values[i])
		if key is ast.NoneExpr {
			items << val
			continue
		}
		items << '${eg.visit(key)}: ${val}'
	}
	return '{${items.join(', ')}}'
}

pub fn (mut eg ExprGen) visit_set(node ast.Set) string {
	mut items := []string{}
	for elt in node.elements {
		items << eg.visit(elt)
	}
	return '{${items.join(', ')}}'
}

pub fn (mut eg ExprGen) visit_slice(node ast.Slice) string {
	mut lower := ''
	if lower_expr := node.lower {
		lower = eg.visit(lower_expr)
	}
	mut upper := ''
	if upper_expr := node.upper {
		upper = eg.visit(upper_expr)
	}
	if step_expr := node.step {
		step := eg.visit(step_expr)
		return '${lower}..${upper};${step}'
	}
	return '${lower}..${upper}'
}

pub fn (mut eg ExprGen) visit_joined_str(node ast.JoinedStr) string {
	tstring := eg.translate_tstring(node.values)
	if tstring.len > 0 {
		return tstring
	}
	mut parts := []string{}
	for value in node.values {
		parts << eg.visit(value)
	}
	if parts.len == 0 {
		return "''"
	}
	if parts.len == 1 {
		return parts[0]
	}
	return parts.join(' + ')
}

pub fn (mut eg ExprGen) visit_formatted_value(node ast.FormattedValue) string {
	expr := eg.visit(node.value)
	expr_type := eg.guess_type(node.value)
	if node.conversion == 114 {
		eg.state.used_builtins['py_repr'] = true
	} else if node.conversion == 97 {
		eg.state.used_builtins['py_ascii'] = true
	}
	if node.conversion == 114 || node.conversion == 115 || node.conversion == 97
		|| node.format_spec != none || expr_type !in ['string', 'LiteralString'] {
		return 'string(${expr})'
	}
	return expr
}

pub fn (mut eg ExprGen) visit_lambda(node ast.Lambda) string {
	mut params := []string{}
	for arg in node.args.posonlyargs {
		params << arg.arg
	}
	for arg in node.args.args {
		params << arg.arg
	}
	for arg in node.args.kwonlyargs {
		params << arg.arg
	}
	return 'fn (${params.join(', ')}) { return ${eg.visit(node.body)} }'
}

pub fn (mut eg ExprGen) visit_named_expr(node ast.NamedExpr) string {
	target := eg.visit(node.target)
	value := eg.visit(node.value)
	return '(${target} = ${value})'
}
