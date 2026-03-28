module analyzer

import ast
import translator.base as tbase

const mutating_methods = ['append', 'extend', 'insert', 'pop', 'remove', 'clear', 'update',
	'setdefault', 'delete', 'add', 'discard']

pub struct TypeInferenceVisitorMixin {
	TypeInferenceBase
}

pub fn new_type_inference_visitor_mixin() TypeInferenceVisitorMixin {
	return TypeInferenceVisitorMixin{
		TypeInferenceBase: new_type_inference_base()
	}
}

fn (t &TypeInferenceVisitorMixin) type_ctx() tbase.TypeGuessingContext {
	return tbase.TypeGuessingContext{
		type_map:           t.type_map
		location_map:       t.location_map
		known_v_types:      map[string]string{}
		name_remap:         map[string]string{}
		defined_classes:    t.defined_classes_for_guessing()
		explicit_any_types: t.explicit_any_types
	}
}

fn (t &TypeInferenceVisitorMixin) defined_classes_for_guessing() map[string]map[string]bool {
	mut classes := map[string]map[string]bool{}
	for class_name in t.class_hierarchy.keys() {
		classes[class_name] = map[string]bool{}
	}
	return classes
}

fn (mut t TypeInferenceVisitorMixin) guess_expr_type(node ast.Expression) string {
	return tbase.guess_type(node, t.type_ctx(), true)
}

fn (mut t TypeInferenceVisitorMixin) store_type(name string, typ string) {
	if name.len == 0 || typ.len == 0 {
		return
	}
	t.type_map[name] = typ
	if !name.contains('.') && !name.contains('@') {
		qualified := t.get_qualified_name(name)
		if qualified != name {
			t.type_map[qualified] = typ
		}
	} else if name.contains('.') {
		short := name.all_after_last('.')
		if short.len > 0 && (!t.has_type(short) || t.get_type(short) == 'Any') {
			t.type_map[short] = typ
		}
	}
}

fn (mut t TypeInferenceVisitorMixin) store_call_signature(name string, sig CallSignature) {
	if name.len == 0 {
		return
	}
	t.call_signatures[name] = sig
	if !name.contains('.') && !name.contains('@') {
		qualified := t.get_qualified_name(name)
		if qualified != name {
			t.call_signatures[qualified] = sig
		}
	} else if name.contains('.') {
		short := name.all_after_last('.')
		if short.len > 0 && short !in t.call_signatures {
			t.call_signatures[short] = sig
		}
	}
}

fn (mut t TypeInferenceVisitorMixin) store_explicit_any(name string, loc string) {
	if name.len == 0 {
		return
	}
	t.explicit_any_types[name] = true
	if !name.contains('.') && !name.contains('@') {
		qualified := t.get_qualified_name(name)
		if qualified != name {
			t.explicit_any_types[qualified] = true
		}
	}
	if loc.len > 0 {
		t.explicit_any_types['${name}@${loc}'] = true
		if !name.contains('.') && !name.contains('@') {
			qualified := t.get_qualified_name(name)
			if qualified != name {
				t.explicit_any_types['${qualified}@${loc}'] = true
			}
		}
	}
}

fn (mut t TypeInferenceVisitorMixin) mark_reassigned_expr(node ast.Expression) {
	match node {
		ast.Name {
			mut info := t.get_mutability(node.id)
			info.is_reassigned = true
			t.set_mutability(node.id, info)
		}
		ast.Attribute {
			t.mark_reassigned_expr(node.value)
		}
		ast.Subscript {
			t.mark_reassigned_expr(node.value)
		}
		ast.Tuple {
			for elt in node.elements {
				t.mark_reassigned_expr(elt)
			}
		}
		ast.List {
			for elt in node.elements {
				t.mark_reassigned_expr(elt)
			}
		}
		ast.Starred {
			t.mark_reassigned_expr(node.value)
		}
		else {}
	}
}

fn (mut t TypeInferenceVisitorMixin) mark_mutated_expr(node ast.Expression) {
	match node {
		ast.Name {
			mut info := t.get_mutability(node.id)
			info.is_mutated = true
			t.set_mutability(node.id, info)
		}
		ast.Attribute {
			t.mark_mutated_expr(node.value)
		}
		ast.Subscript {
			t.mark_mutated_expr(node.value)
		}
		ast.Tuple {
			for elt in node.elements {
				t.mark_mutated_expr(elt)
			}
		}
		ast.List {
			for elt in node.elements {
				t.mark_mutated_expr(elt)
			}
		}
		ast.Starred {
			t.mark_mutated_expr(node.value)
		}
		else {}
	}
}

fn (mut t TypeInferenceVisitorMixin) get_base_node(node ast.Expression) ast.Expression {
	return match node {
		ast.Attribute { t.get_base_node(node.value) }
		ast.Subscript { t.get_base_node(node.value) }
		ast.Starred { t.get_base_node(node.value) }
		else { node }
	}
}

fn (t &TypeInferenceVisitorMixin) expr_to_name(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.Attribute {
			base_name := t.expr_to_name(node.value)
			if base_name.len > 0 {
				'${base_name}.${node.attr}'
			} else {
				node.attr
			}
		}
		else { '' }
	}
}

fn (mut t TypeInferenceVisitorMixin) expr_to_type_string(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.Attribute {
			base_name := t.expr_to_type_string(node.value)
			if base_name.len > 0 {
				'${base_name}.${node.attr}'
			} else {
				node.attr
			}
		}
		ast.Subscript {
			base_name := t.expr_to_type_string(node.value)
			slice_name := match node.slice {
				ast.Tuple { node.slice.elements.map(t.expr_to_type_string(it)).join(', ') }
				else { t.expr_to_type_string(node.slice) }
			}
			if slice_name.len > 0 {
				'${base_name}[${slice_name}]'
			} else {
				base_name
			}
		}
		ast.Tuple { node.elements.map(t.expr_to_type_string(it)).join(', ') }
		ast.List { node.elements.map(t.expr_to_type_string(it)).join(', ') }
		ast.Constant { node.value }
		ast.NoneExpr { 'None' }
		ast.Call { t.expr_to_type_string(node.func) }
		ast.JoinedStr { 'LiteralString' }
		ast.FormattedValue { t.expr_to_type_string(node.value) }
		ast.BinaryOp {
			if node.op.value == '|' {
				'${t.expr_to_type_string(node.left)} | ${t.expr_to_type_string(node.right)}'
			} else {
				t.expr_to_type_string(node.left)
			}
		}
		ast.UnaryOp { '${node.op.value}${t.expr_to_type_string(node.operand)}' }
		ast.Starred { t.expr_to_type_string(node.value) }
		ast.Slice {
			mut parts := []string{}
			if lower := node.lower {
				parts << t.expr_to_type_string(lower)
			}
			if upper := node.upper {
				parts << t.expr_to_type_string(upper)
			}
			if step := node.step {
				parts << t.expr_to_type_string(step)
			}
			parts.join(':')
		}
		else { '' }
	}
}

pub fn (t &TypeInferenceVisitorMixin) render_expr(node ast.Expression) string {
	return match node {
		ast.Name { node.id }
		ast.NoneExpr { 'none' }
		ast.Constant {
			if node.value == 'None' {
				'none'
			} else if node.value == 'True' {
				'true'
			} else if node.value == 'False' {
				'false'
			} else if node.token.typ == .number {
				node.value
			} else if node.token.typ == .string_tok || node.token.typ == .fstring_tok || node.token.typ == .tstring_tok {
				if node.value.starts_with("'") || node.value.starts_with('"') || node.value.starts_with('t\'')
					|| node.value.starts_with('t"') {
					node.value
				} else {
					"'${node.value}'"
				}
			} else {
				node.value
			}
		}
		ast.List { '[' + node.elements.map(t.render_expr(it)).join(', ') + ']' }
		ast.Tuple { node.elements.map(t.render_expr(it)).join(', ') }
		ast.Set { '{' + node.elements.map(t.render_expr(it)).join(', ') + '}' }
		ast.Dict {
			mut items := []string{}
			for i, key in node.keys {
				if i >= node.values.len {
					break
				}
				if key is ast.NoneExpr {
					items << t.render_expr(node.values[i])
				} else {
					items << '${t.render_expr(key)}: ${t.render_expr(node.values[i])}'
				}
			}
			'{${items.join(', ')}}'
		}
		ast.Attribute { '${t.render_expr(node.value)}.${node.attr}' }
		ast.Subscript { '${t.render_expr(node.value)}[${t.render_expr(node.slice)}]' }
		ast.Call {
			mut all_args := []string{}
			for arg in node.args {
				all_args << t.render_expr(arg)
			}
			for kw in node.keywords {
				if kw.arg.len > 0 {
					all_args << '${kw.arg}=${t.render_expr(kw.value)}'
				} else {
					all_args << t.render_expr(kw.value)
				}
			}
			'${t.render_expr(node.func)}(${all_args.join(', ')})'
		}
		ast.BinaryOp { '${t.render_expr(node.left)} ${node.op.value} ${t.render_expr(node.right)}' }
		ast.UnaryOp { '${node.op.value}${t.render_expr(node.operand)}' }
		ast.Compare {
			mut parts := []string{}
			parts << t.render_expr(node.left)
			for comp in node.comparators {
				parts << t.render_expr(comp)
			}
			mut rendered := []string{}
			for i, op in node.ops {
				if i + 1 < parts.len {
					rendered << '${parts[i]} ${op.value} ${parts[i + 1]}'
				}
			}
			rendered.join(' and ')
		}
		ast.JoinedStr { node.values.map(t.render_expr(it)).join(' + ') }
		ast.FormattedValue { t.render_expr(node.value) }
		ast.Slice {
			mut lower := ''
			if lower_expr := node.lower {
				lower = t.render_expr(lower_expr)
			}
			mut upper := ''
			if upper_expr := node.upper {
				upper = t.render_expr(upper_expr)
			}
			if step_expr := node.step {
				'${lower}..${upper};${t.render_expr(step_expr)}'
			} else {
				'${lower}..${upper}'
			}
		}
		ast.Starred { t.render_expr(node.value) }
		ast.NamedExpr { '(${t.render_expr(node.target)} = ${t.render_expr(node.value)})' }
		else { node.str() }
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_stmt(node ast.Statement) {
	match node {
		ast.Expr { t.visit_expr_stmt(node) }
		ast.Assign { t.visit_assign(node) }
		ast.AugAssign { t.visit_aug_assign(node) }
		ast.AnnAssign { t.visit_ann_assign(node) }
		ast.FunctionDef { t.visit_function_def(node) }
		ast.ClassDef { t.visit_class_def(node) }
		ast.If { t.visit_if(node) }
		ast.For { t.visit_for(node) }
		ast.While { t.visit_while(node) }
		ast.With { t.visit_with(node) }
		ast.Try { t.visit_try(node) }
		ast.TryStar { t.visit_try_star(node) }
		ast.Match { t.visit_match(node) }
		ast.Return { t.visit_return(node) }
		ast.Import { t.visit_import(node) }
		ast.ImportFrom { t.visit_import_from(node) }
		ast.Global { t.visit_global(node) }
		ast.Nonlocal { t.visit_nonlocal(node) }
		ast.Assert { t.visit_assert(node) }
		ast.Raise { t.visit_raise(node) }
		ast.Delete { t.visit_delete(node) }
		ast.Pass { t.visit_pass(node) }
		ast.Break { t.visit_break(node) }
		ast.Continue { t.visit_continue(node) }
		ast.TypeAlias { t.visit_type_alias(node) }
		else {}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_expr(node ast.Expression) {
	match node {
		ast.Name { t.visit_name(node) }
		ast.Constant { t.visit_constant(node) }
		ast.NoneExpr { t.visit_none_expr(node) }
		ast.List { t.visit_list(node) }
		ast.Dict { t.visit_dict(node) }
		ast.Tuple { t.visit_tuple(node) }
		ast.Set { t.visit_set(node) }
		ast.BinaryOp { t.visit_binary_op(node) }
		ast.UnaryOp { t.visit_unary_op(node) }
		ast.Compare { t.visit_compare(node) }
		ast.Call { t.visit_call(node) }
		ast.Attribute { t.visit_attribute(node) }
		ast.Subscript { t.visit_subscript(node) }
		ast.Slice { t.visit_slice(node) }
		ast.Lambda { t.visit_lambda(node) }
		ast.ListComp { t.visit_list_comp(node) }
		ast.DictComp { t.visit_dict_comp(node) }
		ast.SetComp { t.visit_set_comp(node) }
		ast.GeneratorExp { t.visit_generator(node) }
		ast.IfExp { t.visit_if_exp(node) }
		ast.Await { t.visit_await(node) }
		ast.Yield { t.visit_yield(node) }
		ast.YieldFrom { t.visit_yield_from(node) }
		ast.Starred { t.visit_starred(node) }
		ast.JoinedStr { t.visit_joined_str(node) }
		ast.FormattedValue { t.visit_formatted_value(node) }
		ast.NamedExpr { t.visit_named_expr(node) }
		else {}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_module(node ast.Module) {
	for stmt in node.body {
		t.visit_stmt(stmt)
	}
}

fn (mut t TypeInferenceVisitorMixin) visit_stmt_list(stmts []ast.Statement) {
	for stmt in stmts {
		t.visit_stmt(stmt)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_expr_stmt(node ast.Expr) {
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_import(node ast.Import) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_import_from(node ast.ImportFrom) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_global(node ast.Global) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_nonlocal(node ast.Nonlocal) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_pass(node ast.Pass) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_break(node ast.Break) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_continue(node ast.Continue) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_name(node ast.Name) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_constant(node ast.Constant) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_none_expr(node ast.NoneExpr) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_list(node ast.List) {
	for elt in node.elements {
		t.visit_expr(elt)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_tuple(node ast.Tuple) {
	for elt in node.elements {
		t.visit_expr(elt)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_set(node ast.Set) {
	for elt in node.elements {
		t.visit_expr(elt)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_dict(node ast.Dict) {
	for key in node.keys {
		if key !is ast.NoneExpr {
			t.visit_expr(key)
		}
	}
	for value in node.values {
		t.visit_expr(value)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_binary_op(node ast.BinaryOp) {
	t.visit_expr(node.left)
	t.visit_expr(node.right)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_unary_op(node ast.UnaryOp) {
	t.visit_expr(node.operand)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_compare(node ast.Compare) {
	t.visit_expr(node.left)
	for comp in node.comparators {
		t.visit_expr(comp)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_attribute(node ast.Attribute) {
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_subscript(node ast.Subscript) {
	if node.ctx == .store {
		t.mark_mutated_expr(node.value)
	}
	
	// TypedDict tracking for read access
	dict_name := t.expr_to_name(node.value)
	if dict_name.len > 0 {
		dict_type := t.get_type(dict_name)
		if dict_type in t.typed_dicts {
			mut key := ''
			if node.slice is ast.Constant {
				key = node.slice.value.trim('\'"')
			} else if node.slice is ast.Name {
				key = t.literal_types[node.slice.id] or { '' }
			}
			
			if key.len > 0 {
				field_type := t.get_type('${dict_type}.${key}')
				if field_type != 'Any' {
					loc_key := '${node.token.line}:${node.token.column}'
					t.location_map[loc_key] = field_type
				}
			}
		}
	}

	t.visit_expr(node.value)
	t.visit_expr(node.slice)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_slice(node ast.Slice) {
	if lower := node.lower {
		t.visit_expr(lower)
	}
	if upper := node.upper {
		t.visit_expr(upper)
	}
	if step := node.step {
		t.visit_expr(step)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_lambda(node ast.Lambda) {
	for param in node.args.posonlyargs {
		if annotation := param.annotation {
			t.visit_expr(annotation)
		}
		if default_value := param.default_ {
			t.visit_expr(default_value)
		}
	}
	for param in node.args.args {
		if annotation := param.annotation {
			t.visit_expr(annotation)
		}
		if default_value := param.default_ {
			t.visit_expr(default_value)
		}
	}
	for param in node.args.kwonlyargs {
		if annotation := param.annotation {
			t.visit_expr(annotation)
		}
		if default_value := param.default_ {
			t.visit_expr(default_value)
		}
	}
	if vararg := node.args.vararg {
		if annotation := vararg.annotation {
			t.visit_expr(annotation)
		}
	}
	if kwarg := node.args.kwarg {
		if annotation := kwarg.annotation {
			t.visit_expr(annotation)
		}
	}
	t.visit_expr(node.body)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_list_comp(node ast.ListComp) {
	t.visit_expr(node.elt)
	for gen in node.generators {
		t.visit_expr(gen.target)
		t.visit_expr(gen.iter)
		for cond in gen.ifs {
			t.visit_expr(cond)
		}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_dict_comp(node ast.DictComp) {
	t.visit_expr(node.key)
	t.visit_expr(node.value)
	for gen in node.generators {
		t.visit_expr(gen.target)
		t.visit_expr(gen.iter)
		for cond in gen.ifs {
			t.visit_expr(cond)
		}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_set_comp(node ast.SetComp) {
	t.visit_expr(node.elt)
	for gen in node.generators {
		t.visit_expr(gen.target)
		t.visit_expr(gen.iter)
		for cond in gen.ifs {
			t.visit_expr(cond)
		}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_generator(node ast.GeneratorExp) {
	t.visit_expr(node.elt)
	for gen in node.generators {
		t.visit_expr(gen.target)
		t.visit_expr(gen.iter)
		for cond in gen.ifs {
			t.visit_expr(cond)
		}
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_if_exp(node ast.IfExp) {
	t.visit_expr(node.test)
	t.visit_expr(node.body)
	t.visit_expr(node.orelse)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_await(node ast.Await) {
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_yield(node ast.Yield) {
	if value := node.value {
		t.visit_expr(value)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_yield_from(node ast.YieldFrom) {
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_starred(node ast.Starred) {
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_joined_str(node ast.JoinedStr) {
	for value in node.values {
		t.visit_expr(value)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_formatted_value(node ast.FormattedValue) {
	t.visit_expr(node.value)
	if format_spec := node.format_spec {
		t.visit_expr(format_spec)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_named_expr(node ast.NamedExpr) {
	t.visit_expr(node.target)
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_return(node ast.Return) {
	if value := node.value {
		t.visit_expr(value)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_assert(node ast.Assert) {
	t.visit_expr(node.test)
	if msg := node.msg {
		t.visit_expr(msg)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_raise(node ast.Raise) {
	if exc := node.exc {
		t.visit_expr(exc)
	}
	if cause := node.cause {
		t.visit_expr(cause)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_delete(node ast.Delete) {
	for target in node.targets {
		if target is ast.Subscript {
			t.mark_mutated_expr(t.get_base_node(target))
		}
		t.visit_expr(target)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_if(node ast.If) {
	t.visit_expr(node.test)
	t.visit_stmt_list(node.body)
	t.visit_stmt_list(node.orelse)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_while(node ast.While) {
	t.visit_expr(node.test)
	t.visit_stmt_list(node.body)
	t.visit_stmt_list(node.orelse)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_for(node ast.For) {
	t.visit_expr(node.target)
	t.visit_expr(node.iter)
	t.visit_stmt_list(node.body)
	t.visit_stmt_list(node.orelse)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_with(node ast.With) {
	for item in node.items {
		t.visit_expr(item.context_expr)
		if optional_vars := item.optional_vars {
			t.visit_expr(optional_vars)
		}
	}
	t.visit_stmt_list(node.body)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_try(node ast.Try) {
	t.visit_stmt_list(node.body)
	for handler in node.handlers {
		if typ := handler.typ {
			t.visit_expr(typ)
		}
		t.visit_stmt_list(handler.body)
	}
	t.visit_stmt_list(node.orelse)
	t.visit_stmt_list(node.finalbody)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_try_star(node ast.TryStar) {
	t.visit_stmt_list(node.body)
	for handler in node.handlers {
		if typ := handler.typ {
			t.visit_expr(typ)
		}
		t.visit_stmt_list(handler.body)
	}
	t.visit_stmt_list(node.orelse)
	t.visit_stmt_list(node.finalbody)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match(node ast.Match) {
	t.visit_expr(node.subject)
	for case in node.cases {
		t.visit_pattern(case.pattern)
		if guard := case.guard {
			t.visit_expr(guard)
		}
		t.visit_stmt_list(case.body)
	}
}

fn (mut t TypeInferenceVisitorMixin) infer_return_type(stmts []ast.Statement) string {
	mut found_types := map[string]bool{}
	has_return_value := t.collect_return_types(stmts, mut found_types)
	if found_types.len == 1 {
		return found_types.keys()[0]
	}
	if found_types.len > 1 || has_return_value {
		return 'Any'
	}
	return 'void'
}

fn (mut t TypeInferenceVisitorMixin) collect_return_types(stmts []ast.Statement, mut found_types map[string]bool) bool {
	mut has_return_value := false
	for stmt in stmts {
		match stmt {
			ast.Return {
				if value := stmt.value {
					has_return_value = true
					typ := t.guess_expr_type(value)
					if typ != 'Any' && typ.len > 0 {
						found_types[typ] = true
					}
				}
			}
			ast.If {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
				has_return_value = t.collect_return_types(stmt.orelse, mut found_types) || has_return_value
			}
			ast.For {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
				has_return_value = t.collect_return_types(stmt.orelse, mut found_types) || has_return_value
			}
			ast.While {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
				has_return_value = t.collect_return_types(stmt.orelse, mut found_types) || has_return_value
			}
			ast.With {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
			}
			ast.Try {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
				for handler in stmt.handlers {
					has_return_value = t.collect_return_types(handler.body, mut found_types) || has_return_value
				}
				has_return_value = t.collect_return_types(stmt.orelse, mut found_types) || has_return_value
				has_return_value = t.collect_return_types(stmt.finalbody, mut found_types) || has_return_value
			}
			ast.TryStar {
				has_return_value = t.collect_return_types(stmt.body, mut found_types) || has_return_value
				for handler in stmt.handlers {
					has_return_value = t.collect_return_types(handler.body, mut found_types) || has_return_value
				}
				has_return_value = t.collect_return_types(stmt.orelse, mut found_types) || has_return_value
				has_return_value = t.collect_return_types(stmt.finalbody, mut found_types) || has_return_value
			}
			ast.Match {
				for case in stmt.cases {
					has_return_value = t.collect_return_types(case.body, mut found_types) || has_return_value
				}
			}
			// Don't recurse into nested sub-functions or classes for return types of THIS function
			ast.FunctionDef {}
			ast.ClassDef {}
			else {}
		}
	}
	return has_return_value
}

pub fn (mut t TypeInferenceVisitorMixin) visit_function_def(node ast.FunctionDef) {
	t.store_type(node.name, 'fn (...Any) Any')

	mut combined_args := []ast.Parameter{}
	combined_args << node.args.posonlyargs
	combined_args << node.args.args
	mut signature_args := combined_args.clone()
	if signature_args.len > 0 && signature_args[0].arg in ['self', 'cls'] {
		signature_args = signature_args[1..].clone()
	}
	signature_args << node.args.kwonlyargs

	mut defaults_map := map[string]string{}
	for param in combined_args {
		if default_expr := param.default_ {
			defaults_map[param.arg] = t.render_expr(default_expr)
		}
	}
	for param in node.args.kwonlyargs {
		if default_expr := param.default_ {
			defaults_map[param.arg] = t.render_expr(default_expr)
		}
	}

	mut arg_types := []string{}
	mut arg_names := []string{}
	for param in signature_args {
		arg_names << param.arg
		mut py_type := 'Any'
		if annotation := param.annotation {
			py_type = t.expr_to_type_string(annotation)
		}
		if py_type == 'Any' || py_type == 'typing.Any' || py_type == 'typing_extensions.Any' {
			t.store_explicit_any(param.arg, '${param.token.line}:${param.token.column}')
		}
		v_type := map_python_type_to_v(py_type)
		if v_type == 'LiteralString' {
			arg_types << 'string'
			t.store_type(param.arg, 'string')
		} else {
			arg_types << v_type
			t.store_type(param.arg, v_type)
		}
	}
	if vararg := node.args.vararg {
		if annotation := vararg.annotation {
			t.visit_expr(annotation)
		}
	}
	if kwarg := node.args.kwarg {
		if annotation := kwarg.annotation {
			t.visit_expr(annotation)
		}
	}

	mut return_type := 'void'
	mut narrowed_type_opt := ?string(none)
	mut is_type_is := false
	if return_annotation := node.returns {
		py_return := t.expr_to_type_string(return_annotation)
		if py_return.len > 0 {
			if py_return.starts_with('TypeGuard[') || py_return.starts_with('TypeIs[') || 
			   py_return.starts_with('typing.TypeGuard[') || py_return.starts_with('typing.TypeIs[') {
				is_type_is = py_return.contains('TypeIs')
				bracket_idx := py_return.index('[') or { -1 }
				if bracket_idx >= 0 {
					narrowed := py_return[bracket_idx + 1..py_return.len - 1].trim_space()
					narrowed_type_opt = map_python_type_to_v(narrowed)
				}
				return_type = 'bool'
			} else {
				return_type = map_python_type_to_v(py_return)
			}
		}
	} else if node.name !in ['__init__', '__post_init__', 'setUp', 'tearDown'] {
		return_type = t.infer_return_type(node.body)
	}
	if return_type == 'LiteralString' {
		return_type = 'string'
	}
	t.store_type('${node.name}@return', return_type)

	sig := CallSignature{
		args:        arg_types
		arg_names:   arg_names
		defaults:    defaults_map
		return_type: return_type
		is_class:    false
		has_init:    false
		has_vararg:  node.args.vararg != none
		has_kwarg:   node.args.kwarg != none
		narrowed_type: narrowed_type_opt
		is_type_is:  is_type_is
	}
	t.store_call_signature(node.name, sig)

	mut is_overload := false
	mut is_property := false
	for decorator in node.decorator_list {
		t.visit_expr(decorator)
		dec_name := t.render_expr(decorator)
		if dec_name.ends_with('overload') {
			is_overload = true
		}
		if dec_name == 'property' {
			is_property = true
		}
	}

	if is_property {
		full_prop_name := t.get_qualified_name(node.name)
		t.type_map[full_prop_name] = return_type
	}

	for type_param in node.type_params {
		t.visit_type_param(type_param)
	}

	if is_overload {
		mut sig_info := map[string]string{}
		for i, p in signature_args {
			sig_info[p.arg] = arg_types[i]
		}
		sig_info['return'] = return_type
		
		qual_name := t.get_qualified_name(node.name)
		t.overloaded_signatures[qual_name] << sig_info
		// We don't visit the body of @overload stubs
		return
	}

	t.push_scope(node.name)
	for stmt in node.body {
		t.visit_stmt(stmt)
	}
	t.pop_scope()
}

pub fn (mut t TypeInferenceVisitorMixin) visit_class_def(node ast.ClassDef) {
	mut bases := []string{}
	for base in node.bases {
		base_name := t.expr_to_type_string(base)
		if base_name.len > 0 {
			bases << base_name
		}
	}
	t.add_class_to_hierarchy(node.name, bases)
	if 'TypedDict' in bases || 'typing.TypedDict' in bases {
		t.typed_dicts[node.name] = true
	}

	for decorator in node.decorator_list {
		t.visit_expr(decorator)
	}
	for keyword in node.keywords {
		t.visit_expr(keyword.value)
	}
	for type_param in node.type_params {
		t.visit_type_param(type_param)
	}

	t.push_scope(node.name)
	for stmt in node.body {
		match stmt {
			ast.Assign {
				for target in stmt.targets {
					if target is ast.Name {
						inferred := t.guess_expr_type(stmt.value)
						t.store_type('${node.name}.${target.id}', inferred)
						t.store_type(target.id, inferred)
					}
				}
			}
			else {}
		}
		t.visit_stmt(stmt)
	}
	t.pop_scope()
}

pub fn (mut t TypeInferenceVisitorMixin) visit_assign(node ast.Assign) {
	t.visit_expr(node.value)
	value_type := match node.value {
		ast.Call {
			if node.value.func is ast.Name && node.value.func.id == 'TypeVar' {
				for tgt in node.targets {
					if tgt is ast.Name {
						t.type_vars[tgt.id] = true
					}
				}
			}
			if node.value.func is ast.Attribute {
				call_attr := node.value.func
				if call_attr.value is ast.Name && call_attr.value.id == 'hashlib' {
					loc_key := '${node.value.token.line}:${node.value.token.column}'
					if call_attr.attr == 'sha256' {
						t.location_map[loc_key] = 'PyHashSha256'
						'PyHashSha256'
					} else if call_attr.attr == 'md5' {
						t.location_map[loc_key] = 'PyHashMd5'
						'PyHashMd5'
					} else {
						t.guess_expr_type(node.value)
					}
				} else {
					t.guess_expr_type(node.value)
				}
			} else {
				t.guess_expr_type(node.value)
			}
		}
		else { t.guess_expr_type(node.value) }
	}

	for target in node.targets {
		match target {
			ast.Name {
				if target.id in t.mutability_map {
					t.mark_reassigned_expr(target)
				}
				current := t.get_type(target.id)
				is_cap := target.id.len > 0 && target.id[0].is_capital()
				if value_type != 'Any' {
					if current == 'Any' || (current == 'int' && (value_type.contains('[]') || value_type.contains('map['))) || (is_cap && value_type.contains('[]') && (current == '[]Any' || current == 'int')) {
						t.store_type(target.id, value_type)
					}
				}
			}
			ast.Attribute {
				t.mark_mutated_expr(target)
				obj_name := t.render_expr(target.value)
				if obj_name.len > 0 {
					t.store_type('${obj_name}.${target.attr}', value_type)
				}
				if target.value is ast.Name && target.value.id == 'self' {
					t.store_type(target.attr, value_type)
				}
			}
			ast.Subscript {
				t.mark_mutated_expr(target.value)
				dict_name := t.expr_to_name(target.value)
				if dict_name.len > 0 {
					dict_type := t.get_type(dict_name)
					if dict_type in t.typed_dicts {
						// It's a TypedDict!
						mut key := ''
						if target.slice is ast.Constant {
							key = target.slice.value.trim('\'"')
						} else if target.slice is ast.Name {
							key = t.literal_types[target.slice.id] or { '' }
						}
						
						if key.len > 0 {
							field_type := t.get_type('${dict_type}.${key}')
							if field_type != 'Any' {
								// We don't store MyDict['key'] type usually, but we could
								// but here 'value_type' is what is being ASSIGNED.
								// If we assign to a TypedDict field, we might want to check its type
								// or just use it as a hint for the RHS if it was unknown.
							}
						}
					}

					if target.slice is ast.Slice {
						current := t.type_map[dict_name] or { 'Any' }
						if (current == 'Any' || current.contains('Any')) && value_type != 'Any' {
							t.store_type(dict_name, value_type)
						}
					} else {
						mut key_type := 'string'
						if target.slice is ast.Constant {
							if target.slice.value.is_int() {
								key_type = 'int'
							} else if target.slice.value.len > 0 {
								key_type = 'string'
							}
						} else {
							slice_type := t.guess_expr_type(target.slice)
							if slice_type == 'int' {
								key_type = 'int'
							} else if slice_type == 'string' {
								key_type = 'string'
							}
						}
						if value_type != 'Any' {
							new_type := 'map[${key_type}]${value_type}'
							current := t.type_map[dict_name] or { 'Any' }
							if current == 'Any' || current.contains('Any') {
								t.store_type(dict_name, new_type)
							}
						}
					}
				}
			}
			else {}
		}
		t.visit_expr(target)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_aug_assign(node ast.AugAssign) {
	t.mark_reassigned_expr(node.target)
	if node.target is ast.Attribute {
		if node.target.value is ast.Name && node.target.value.id == 'self' {
			inferred := t.guess_expr_type(node.target)
			t.store_type('self.${node.target.attr}', inferred)
			t.store_type(node.target.attr, inferred)
		}
	}
	if node.target is ast.Subscript {
		t.mark_mutated_expr(node.target.value)
	}
	t.visit_expr(node.target)
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_ann_assign(node ast.AnnAssign) {
	annotation_str := t.expr_to_type_string(node.annotation)
	mut v_type := map_python_type_to_v(annotation_str)
	if annotation_str == 'LiteralString' || annotation_str == 'typing.LiteralString'
		|| annotation_str == 'typing_extensions.LiteralString' {
		v_type = 'string'
	}
	
	if annotation_str.starts_with('Literal[') || annotation_str.starts_with('typing.Literal[') {
		if node.target is ast.Name {
			// Extract literal value
			mut lit_val := if annotation_str.starts_with('Literal[') { annotation_str[8..annotation_str.len - 1] } else { annotation_str[15..annotation_str.len - 1] }
			t.literal_types[node.target.id] = lit_val
		}
	}

	if annotation_str == 'Any' || annotation_str == 'typing.Any' || annotation_str == 'typing_extensions.Any' {
		if node.target is ast.Name {
			t.store_explicit_any(node.target.id, '${node.target.token.line}:${node.target.token.column}')
		} else if node.target is ast.Attribute {
			if node.target.value is ast.Name && node.target.value.id == 'self' {
				t.store_explicit_any(node.target.attr, '${node.target.token.line}:${node.target.token.column}')
			}
		}
	}

	mut target_name := ''
	if node.target is ast.Name {
		target_name = node.target.id
	} else if node.target is ast.Attribute {
		if node.target.value is ast.Name && node.target.value.id == 'self' {
			target_name = node.target.attr
		}
	}

	if target_name.len > 0 {
		if t.scope_names.len > 0 {
			curr_scope := t.scope_names[t.scope_names.len - 1]
			// If we are directly in a class scope (capitalized), store as class field
			if curr_scope.len > 0 && curr_scope[0].is_capital() {
				t.store_type('${curr_scope}.${target_name}', v_type)
			} else {
				t.store_type(target_name, v_type)
			}
		} else {
			t.store_type(target_name, v_type)
		}
		
	}

	if value_expr := node.value {
		t.visit_expr(value_expr)
	}
	t.visit_expr(node.target)
	t.visit_expr(node.annotation)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_type_alias(node ast.TypeAlias) {
	alias_type := t.expr_to_type_string(node.value)
	if alias_type.len > 0 {
		t.store_type(node.name, map_python_type_to_v(alias_type))
	}
	for type_param in node.type_params {
		t.visit_type_param(type_param)
	}
	t.visit_expr(node.value)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_type_param(node ast.TypeParam) {
	if bound := node.bound {
		t.visit_expr(bound)
	}
	if default_ := node.default_ {
		t.visit_expr(default_)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_call(node ast.Call) {
	if node.func is ast.Attribute {
		attr := node.func
		if attr.attr in mutating_methods {
			t.mark_mutated_expr(attr.value)
		}
		if attr.attr == 'append' && node.args.len == 1 {
			obj_name := t.expr_to_name(attr.value)
			elt_type := t.guess_expr_type(node.args[0])
			if obj_name.len > 0 && elt_type != 'Any' {
				new_type := '[]${elt_type}'
				current := t.get_type(obj_name)
				if current == 'Any' || current == '[]Any' || current == 'int' || current.contains('Any') {
					t.store_type(obj_name, new_type)
				}
			}
		}
		if attr.value is ast.Name && attr.value.id == 'hashlib' {
			loc_key := '${node.token.line}:${node.token.column}'
			if attr.attr == 'sha256' {
				t.location_map[loc_key] = 'PyHashSha256'
			} else if attr.attr == 'md5' {
				t.location_map[loc_key] = 'PyHashMd5'
			}
		}
		
		// Check for method-based mutability if object is a parameter
		obj_name := t.expr_to_name(attr.value)
		if obj_name.len > 0 {
			// This part usually handled by FunctionMutabilityScanner but let's double check
		}
	}
	if node.func is ast.Name {
		func_name := node.func.id
		if func_name in t.func_param_mutability {
			for i, arg in node.args {
				if i in t.func_param_mutability[func_name] {
					t.mark_mutated_expr(arg)
				}
			}
		}
		is_cap := func_name.len > 0 && func_name[0].is_capital()
		if !is_cap && func_name !in ['list', 'set', 'dict'] && (!t.has_type(func_name) || t.get_type(func_name) == 'Any') {
			t.store_type(func_name, 'fn (...Any) Any')
		}
	}
	for arg in node.args {
		t.visit_expr(arg)
	}
	for kw in node.keywords {
		t.visit_expr(kw.value)
	}
	t.visit_expr(node.func)
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_value(node ast.MatchValue) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_singleton(node ast.MatchSingleton) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_sequence(node ast.MatchSequence) {
	for pattern in node.patterns {
		t.visit_pattern(pattern)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_mapping(node ast.MatchMapping) {
	for key in node.keys {
		t.visit_expr(key)
	}
	for pattern in node.patterns {
		t.visit_pattern(pattern)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_class(node ast.MatchClass) {
	t.visit_expr(node.cls)
	for pattern in node.patterns {
		t.visit_pattern(pattern)
	}
	for pattern in node.kwd_patterns {
		t.visit_pattern(pattern)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_star(node ast.MatchStar) {}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_as(node ast.MatchAs) {
	if pattern := node.pattern {
		t.visit_pattern(pattern)
	}
}

pub fn (mut t TypeInferenceVisitorMixin) visit_match_or(node ast.MatchOr) {
	for pattern in node.patterns {
		t.visit_pattern(pattern)
	}
}

fn (mut t TypeInferenceVisitorMixin) visit_pattern(node ast.Pattern) {
	match node {
		ast.MatchValue { t.visit_match_value(node) }
		ast.MatchSingleton { t.visit_match_singleton(node) }
		ast.MatchSequence { t.visit_match_sequence(node) }
		ast.MatchMapping { t.visit_match_mapping(node) }
		ast.MatchClass { t.visit_match_class(node) }
		ast.MatchStar { t.visit_match_star(node) }
		ast.MatchAs { t.visit_match_as(node) }
		ast.MatchOr { t.visit_match_or(node) }
		else {}
	}
}
