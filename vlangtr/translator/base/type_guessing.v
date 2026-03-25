module base

import ast

pub struct TypeGuessingContext {
pub:
	type_map        map[string]string
	location_map    map[string]string
	known_v_types   map[string]string
	name_remap      map[string]string
	defined_classes map[string]map[string]bool
}

// guess_type infers a best-effort V type for an expression node.
pub fn guess_type(node ast.Expression, ctx TypeGuessingContext, use_location bool) string {
	if use_location {
		loc_key := '${node.get_token().line}:${node.get_token().column}'
		if loc_key in ctx.location_map {
			res := ctx.location_map[loc_key]
			if res != 'none' {
				return res
			}
		}
	}

	if node is ast.Constant {
		return guess_constant_type(node)
	}
	if node is ast.Lambda {
		return guess_type_lambda(node, ctx)
	}
	if node is ast.UnaryOp {
		if node.op.value == 'not' {
			return 'bool'
		}
		return guess_type(node.operand, ctx, use_location)
	}
	if node is ast.Compare {
		return 'bool'
	}
	if node is ast.Call {
		return guess_type_call(node, ctx)
	}
	if node is ast.List || node is ast.Tuple {
		return guess_type_list(node, ctx)
	}
	if node is ast.Set {
		return guess_type_set(node, ctx)
	}
	if node is ast.Dict {
		return guess_type_dict(node, ctx)
	}
	if node is ast.Name {
		return guess_type_name(node, ctx, use_location)
	}
	if node is ast.Attribute {
		return guess_type_attribute(node, ctx)
	}
	if node is ast.Subscript {
		return guess_type_subscript(node)
	}
	if node is ast.BinaryOp {
		return guess_type_binop(node, ctx)
	}
	if node is ast.ListComp || node is ast.GeneratorExp {
		return guess_type_listcomp(node, ctx)
	}
	if node is ast.SetComp {
		return guess_type_setcomp(node, ctx)
	}
	if node is ast.DictComp {
		return guess_type_dictcomp(node, ctx)
	}
	return 'int'
}

fn guess_constant_type(node ast.Constant) string {
	tok := node.token
	if tok.typ == .string_tok || tok.typ == .fstring_tok || tok.typ == .tstring_tok {
		return 'string'
	}
	if tok.typ == .number {
		if node.value.contains('.') {
			return 'f64'
		}
		return 'int'
	}
	if tok.typ == .keyword {
		if node.value in ['True', 'False'] {
			return 'bool'
		}
		if node.value == 'None' {
			return 'Any'
		}
	}
	return 'int'
}

fn guess_type_call(node ast.Call, ctx TypeGuessingContext) string {
	if node.func is ast.Name {
		fid := node.func.id
		if fid in ctx.defined_classes {
			return fid
		}
		if fid == 'str' {
			if node.args.len > 0 && is_literal_string_expr(node.args[0], ctx) {
				return 'LiteralString'
			}
			return 'string'
		}
		if fid in ['int', 'len'] {
			return 'int'
		}
		if fid == 'float' {
			return 'f64'
		}
		if fid in ['bool', 'isinstance', 'hasattr', 'getattr', 'setattr'] {
			return 'bool'
		}
		if fid == 'print' {
			return 'None'
		}
		if fid == 'input' {
			return 'string'
		}
		if fid == 'open' {
			return 'os.File'
		}
		if fid in ['bytearray', 'memoryview', 'bytes'] {
			return '[]u8'
		}
		if fid in ['set', 'frozenset'] {
			if node.args.len > 0 {
				arg_type := guess_type(node.args[0], ctx, true)
				if arg_type.starts_with('[]') {
					return 'datatypes.Set[${arg_type[2..]}]'
				}
			}
			return 'datatypes.Set[string]'
		}
		if fid == 'Counter' {
			return 'map[string]int'
		}
		if fid == 'py_range' {
			return '[]int'
		}
		if fid in ['py_sorted', 'py_reversed'] {
			if node.args.len > 0 {
				return guess_type(node.args[0], ctx, true)
			}
			return '[]Any'
		}
		if fid == 'py_zip' {
			return '[]PyZipItem'
		}
		if fid == 'py_enumerate' {
			return '[]PyEnumerateItem'
		}
		if fid == 'py_divmod' {
			if node.args.len > 0 {
				return '[]${guess_type(node.args[0], ctx, true)}'
			}
			return '[]Any'
		}
		if fid in ['py_os_path_split', 'py_os_path_splitext'] {
			return '[]string'
		}

		ret_key := '${fid}@return'
		if ret_key in ctx.type_map {
			return ctx.type_map[ret_key]
		}
	}
	return 'Any'
}

fn guess_type_list(node ast.Expression, ctx TypeGuessingContext) string {
	mut elts := []ast.Expression{}
	if node is ast.List {
		elts = node.elements.clone()
	} else if node is ast.Tuple {
		elts = node.elements.clone()
	}
	if elts.len == 0 {
		return '[]Any'
	}

	mut element_types := []string{}
	mut has_none := false
	for elt in elts {
		if elt is ast.Starred {
			element_types << 'Any'
		} else if elt is ast.Constant && elt.value == 'None' {
			has_none = true
		} else if elt is ast.Name && elt.id in ['None', 'none'] {
			has_none = true
		} else {
			element_types << guess_type(elt, ctx, true)
		}
	}

	mut lcs := 'Any'
	if element_types.len > 0 {
		if element_types.all(it == element_types[0]) {
			lcs = element_types[0]
		}
	}
	if has_none {
		return '[]?${lcs}'
	}
	return '[]${lcs}'
}

fn guess_type_set(node ast.Set, ctx TypeGuessingContext) string {
	if node.elements.len == 0 {
		return 'datatypes.Set[string]'
	}
	mut element_types := map[string]bool{}
	for elt in node.elements {
		if elt is ast.Starred {
			element_types['Any'] = true
		} else {
			element_types[guess_type(elt, ctx, true)] = true
		}
	}
	if element_types.len == 1 {
		t := element_types.keys()[0]
		if t == 'Any' {
			return 'datatypes.Set[string]'
		}
		return 'datatypes.Set[${t}]'
	}
	return 'datatypes.Set[string]'
}

fn guess_type_dict(node ast.Dict, ctx TypeGuessingContext) string {
	if node.keys.len == 0 {
		return 'map[string]Any'
	}
	mut key_types := map[string]bool{}
	mut val_types := map[string]bool{}
	for i, k in node.keys {
		v := node.values[i]
		if k is ast.NoneExpr {
			key_types['string'] = true
			val_types['Any'] = true
		} else {
			key_types[guess_type(k, ctx, true)] = true
			val_types[guess_type(v, ctx, true)] = true
		}
	}
	mut k_type := 'string'
	if key_types.len == 1 {
		k_type = key_types.keys()[0]
	}
	if k_type == 'Any' {
		k_type = 'string'
	}
	mut v_type := 'Any'
	if val_types.len == 1 {
		v_type = val_types.keys()[0]
	}
	return 'map[${k_type}]${v_type}'
}

fn guess_type_name(node ast.Name, ctx TypeGuessingContext, use_location bool) string {
	actual_name := ctx.name_remap[node.id] or { node.id }
	if actual_name in ctx.known_v_types {
		return ctx.known_v_types[actual_name]
	}
	if node.id in ctx.known_v_types {
		return ctx.known_v_types[node.id]
	}
	if use_location {
		loc_key := '${node.id}@${node.token.line}:${node.token.column}'
		if loc_key in ctx.type_map {
			return ctx.type_map[loc_key]
		}
	}
	if node.id in ctx.type_map {
		return ctx.type_map[node.id]
	}
	return 'int'
}

fn guess_type_attribute(node ast.Attribute, ctx TypeGuessingContext) string {
	if node.value is ast.Name {
		attr_name := '${node.value.id}.${node.attr}'
		if attr_name in ctx.type_map {
			return ctx.type_map[attr_name]
		}
	}
	return 'Any'
}

fn guess_type_subscript(node ast.Subscript) string {
	if node.value is ast.Attribute {
		if node.value.value is ast.Name && node.value.value.id == 'sys' && node.value.attr == 'argv' {
			return 'string'
		}
	} else if node.value is ast.Name {
		if node.value.id == 'argv' {
			return 'string'
		}
	}
	return 'Any'
}

fn guess_type_binop(node ast.BinaryOp, ctx TypeGuessingContext) string {
	left := guess_type(node.left, ctx, true)
	right := guess_type(node.right, ctx, true)
	if node.op.value == '/' {
		if left == 'PyComplex' || right == 'PyComplex' {
			return 'PyComplex'
		}
		return 'f64'
	}
	if left.starts_with('[]') {
		return left
	}
	if right.starts_with('[]') {
		return right
	}
	if left == 'LiteralString' && right == 'LiteralString' {
		return 'LiteralString'
	}
	if is_string_type(left) || is_string_type(right) {
		return 'string'
	}
	if left == 'PyComplex' || right == 'PyComplex' {
		return 'PyComplex'
	}
	if left == 'f64' || right == 'f64' {
		return 'f64'
	}
	if left == 'int' && right == 'int' {
		return 'int'
	}
	return 'Any'
}

fn guess_type_listcomp(node ast.Expression, ctx TypeGuessingContext) string {
	mut elt_type := 'Any'
	if node is ast.ListComp {
		elt_type = guess_type(node.elt, ctx, true)
	} else if node is ast.GeneratorExp {
		elt_type = guess_type(node.elt, ctx, true)
	}
	if elt_type in ['Any', 'unknown'] {
		return '[]Any'
	}
	return '[]${elt_type}'
}

fn guess_type_setcomp(node ast.SetComp, ctx TypeGuessingContext) string {
	elt_type := guess_type(node.elt, ctx, true)
	if elt_type in ['Any', 'unknown'] {
		return 'datatypes.Set[string]'
	}
	return 'datatypes.Set[${elt_type}]'
}

fn guess_type_dictcomp(node ast.DictComp, ctx TypeGuessingContext) string {
	mut key_type := guess_type(node.key, ctx, true)
	mut val_type := guess_type(node.value, ctx, true)
	if key_type in ['Any', 'unknown'] {
		key_type = 'string'
	}
	if val_type == 'unknown' {
		val_type = 'Any'
	}
	return 'map[${key_type}]${val_type}'
}

fn guess_type_lambda(node ast.Lambda, ctx TypeGuessingContext) string {
	mut param_types := []string{}
	for arg in node.args.posonlyargs {
		param_types << (ctx.type_map[arg.arg] or { 'int' })
	}
	for arg in node.args.args {
		param_types << (ctx.type_map[arg.arg] or { 'int' })
	}
	for arg in node.args.kwonlyargs {
		param_types << (ctx.type_map[arg.arg] or { 'int' })
	}
	mut ret_type := guess_type(node.body, ctx, true)
	if ret_type in ['void', 'Any', 'unknown'] {
		ret_type = 'int'
	}
	return 'fn(${param_types.join(', ')}) ${ret_type}'
}

pub fn is_literal_string_expr(node ast.Expression, ctx TypeGuessingContext) bool {
	if node is ast.Constant {
		return node.token.typ == .string_tok || node.token.typ == .fstring_tok
			|| node.token.typ == .tstring_tok
	}
	if node is ast.JoinedStr {
		for v in node.values {
			if !is_literal_string_expr(v, ctx) {
				return false
			}
		}
		return true
	}
	if node is ast.FormattedValue {
		return is_literal_string_expr(node.value, ctx)
	}
	if node is ast.BinaryOp && node.op.value == '+' {
		return is_literal_string_expr(node.left, ctx) && is_literal_string_expr(node.right, ctx)
	}
	if node is ast.Name {
		return (ctx.type_map[node.id] or { '' }) == 'LiteralString'
	}
	return false
}
