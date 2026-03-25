// Work in progress by Cline. Started: 2026-03-22 15:04
// checkstrformat.v — Format expression type checker
// Bridge implementation aligned with the current V AST/type layer.

module mypy

pub type StringOrBytesExpr = BytesExpr | StrExpr

pub struct ConversionSpecifier {
pub mut:
	whole_seq                string
	start_pos                int
	key                      ?string
	conv_type                string
	flags                    string
	width                    string
	precision                string
	format_spec              ?string
	non_standard_format_spec bool
	conversion               ?string
	field                    ?string
}

pub struct RegexMatch {
pub:
	groups map[string]string
}

pub fn (rm RegexMatch) group() string {
	return ''
}

pub fn (rm RegexMatch) groups() map[string]string {
	return rm.groups
}

pub fn new_conversion_specifier(match_obj RegexMatch, start_pos int, non_standard_format_spec bool) ConversionSpecifier {
	m_dict := match_obj.groups()
	return ConversionSpecifier{
		whole_seq:                match_obj.group()
		start_pos:                start_pos
		key:                      m_dict['key']
		conv_type:                m_dict['type'] or { '' }
		flags:                    m_dict['flags'] or { '' }
		width:                    m_dict['width'] or { '' }
		precision:                m_dict['precision'] or { '' }
		format_spec:              m_dict['format_spec']
		non_standard_format_spec: non_standard_format_spec
		conversion:               m_dict['conversion']
		field:                    m_dict['field']
	}
}

pub fn (cs ConversionSpecifier) has_key() bool {
	return cs.key != none
}

pub fn (cs ConversionSpecifier) has_star() bool {
	return cs.width == '*' || cs.precision == '*'
}

fn get_numeric_types_old() map[string]bool {
	return {
		'd': true
		'i': true
		'o': true
		'u': true
		'x': true
		'X': true
		'e': true
		'E': true
		'f': true
		'F': true
		'g': true
		'G': true
	}
}

fn get_numeric_types_new() map[string]bool {
	return {
		'b': true
		'd': true
		'o': true
		'e': true
		'E': true
		'f': true
		'F': true
		'g': true
		'G': true
		'n': true
		'x': true
		'X': true
		'%': true
	}
}

pub const dummy_field_name = '__dummy_name__'

pub fn parse_conversion_specifiers(format_str string) []ConversionSpecifier {
	mut specifiers := []ConversionSpecifier{}
	mut pos := 0
	for pos < format_str.len {
		if format_str[pos] == `%` {
			if pos + 1 < format_str.len && format_str[pos + 1] != `%` {
				specifiers << ConversionSpecifier{
					whole_seq: format_str[pos..pos + 2]
					start_pos: pos
					conv_type: format_str[pos + 1].ascii_str()
				}
			}
			pos += 2
		} else {
			pos++
		}
	}
	return specifiers
}

pub struct StringFormatterChecker {
pub mut:
	chk &TypeChecker
	msg &MessageBuilder
}

pub fn new_string_formatter_checker(chk &TypeChecker, msg &MessageBuilder) StringFormatterChecker {
	return StringFormatterChecker{
		chk: chk
		msg: unsafe { msg }
	}
}

pub fn (mut sfc StringFormatterChecker) check_str_format_call(call CallExpr, format_value string) {
	mut specs := parse_format_value(format_value) or { return }
	if !sfc.auto_generate_keys(mut specs, call.base.ctx) {
		return
	}
	sfc.check_specs_in_format_call(call, specs)
}

pub fn (mut sfc StringFormatterChecker) auto_generate_keys(mut all_specs []ConversionSpecifier, ctx Context) bool {
	mut some_defined := false
	mut all_defined := true
	for spec in all_specs {
		if key := spec.key {
			if key.is_int() {
				some_defined = true
			}
		} else {
			all_defined = false
		}
	}
	if some_defined && !all_defined {
		sfc.msg.fail('Cannot mix manual and automatic field numbering', ctx, false, false,
			none)
		return false
	}
	if all_defined {
		return true
	}
	mut next_index := 0
	for i in 0 .. all_specs.len {
		if all_specs[i].key == none {
			str_index := next_index.str()
			all_specs[i].key = str_index
			all_specs[i].field = str_index
			next_index++
		}
	}
	return true
}

pub fn (mut sfc StringFormatterChecker) check_str_interpolation(expr StringOrBytesExpr, replacements Expression) MypyTypeNode {
	expr_ctx := format_string_expr_context(expr)
	expr_val := match expr {
		StrExpr {
			sfc.chk.expr_checker.accept(expr)
			expr.value
		}
		BytesExpr {
			sfc.chk.expr_checker.accept(expr)
			expr.value
		}
	}
	specifiers := parse_conversion_specifiers(expr_val)
	if has_mapping_keys := sfc.analyze_conversion_specifiers(specifiers, expr_ctx) {
		if has_mapping_keys {
			sfc.check_mapping_str_interpolation(specifiers, replacements, expr_ctx)
		} else {
			sfc.check_simple_str_interpolation(specifiers, replacements, expr_ctx)
		}
	}
	return match expr {
		BytesExpr { sfc.named_type('builtins.bytes') }
		StrExpr { sfc.named_type('builtins.str') }
	}
}

pub fn (mut sfc StringFormatterChecker) analyze_conversion_specifiers(specifiers []ConversionSpecifier, context Context) ?bool {
	mut has_star := false
	mut has_key := false
	mut all_have_keys := true
	for spec in specifiers {
		if spec.has_star() {
			has_star = true
		}
		if spec.has_key() {
			has_key = true
		} else if spec.conv_type != '%' {
			all_have_keys = false
		}
	}
	if has_key && has_star {
		sfc.msg.fail('String interpolation with * and key is not supported', context,
			false, false, none)
		return none
	}
	if has_key && !all_have_keys {
		sfc.msg.fail('Cannot mix key and non-key in string interpolation', context, false,
			false, none)
		return none
	}
	return has_key
}

pub fn (mut sfc StringFormatterChecker) conversion_type(p string, context Context, expr StringOrBytesExpr) ?MypyTypeNode {
	if p == 'b' {
		if expr !is BytesExpr {
			sfc.msg.fail('Format character "b" is only supported on bytes patterns', context,
				false, false, none)
			return none
		}
		return sfc.named_type('builtins.bytes')
	}
	if p == 'a' || p == 's' || p == 'r' {
		return AnyType{
			type_of_any: .special_form
		}
	}
	if p in get_numeric_types_new() || p in get_numeric_types_old() {
		return UnionType{
			items: [sfc.named_type('builtins.int'), sfc.named_type('builtins.float')]
		}
	}
	if p == 'c' {
		return UnionType{
			items: [sfc.named_type('builtins.int'), sfc.named_type('builtins.str')]
		}
	}
	sfc.msg.fail('Unsupported placeholder ${p}', context, false, false, none)
	return none
}

fn (sfc StringFormatterChecker) named_type(name string) MypyTypeNode {
	return sfc.chk.named_type(name)
}

fn (mut sfc StringFormatterChecker) accept(expr Expression) MypyTypeNode {
	return sfc.chk.expr_checker.accept(expr)
}

fn format_string_expr_context(expr StringOrBytesExpr) Context {
	return match expr {
		StrExpr { expr.base.ctx }
		BytesExpr { expr.base.ctx }
	}
}

fn parse_format_value(format_value string) ?[]ConversionSpecifier {
	mut specs := []ConversionSpecifier{}
	mut i := 0
	for i < format_value.len {
		if format_value[i] == `{` {
			if i + 1 < format_value.len && format_value[i + 1] == `{` {
				i += 2
				continue
			}
			end := format_value.index_after('}', i + 1) or { return none }
			if end < i {
				return none
			}
			spec_str := format_value[i..end + 1]
			mut spec := ConversionSpecifier{
				whole_seq: spec_str
				start_pos: i
			}
			content := spec_str[1..spec_str.len - 1]
			if content.contains(':') {
				parts := content.split_nth(':', 2)
				if parts.len > 0 && parts[0] != '' {
					spec.key = parts[0]
					spec.field = parts[0]
				}
				if parts.len > 1 && parts[1] != '' {
					spec.format_spec = parts[1]
				}
			} else if content != '' {
				spec.key = content
				spec.field = content
			}
			specs << spec
			i = end + 1
		} else {
			i++
		}
	}
	return specs
}

fn (mut sfc StringFormatterChecker) check_specs_in_format_call(call CallExpr, specs []ConversionSpecifier) {
	for i, spec in specs {
		if i >= call.args.len {
			return
		}
		if fmt_spec := spec.format_spec {
			if fmt_spec.len == 0 {
				continue
			}
			last_char := fmt_spec[fmt_spec.len - 1]
			arg := call.args[i]
			arg_type := sfc.chk.expr_checker.accept(arg)
			if last_char in [`d`, `i`, `o`, `x`, `X`] {
				_ = sfc.chk.check_subtype(arg_type, sfc.named_type('builtins.int'), arg.get_context(),
					'Argument must be int for format specifier')
			} else if last_char in [`f`, `F`, `e`, `E`, `g`, `G`] {
				_ = sfc.chk.check_subtype(arg_type, sfc.named_type('builtins.float'),
					arg.get_context(), 'Argument must be float for format specifier')
			}
		}
	}
}

fn (mut sfc StringFormatterChecker) check_simple_str_interpolation(specifiers []ConversionSpecifier, replacements Expression, expr_ctx Context) {
	if replacements is TupleExpr {
		if specifiers.len != replacements.items.len {
			sfc.msg.fail('Wrong number of arguments for format string', expr_ctx, false,
				false, none)
			return
		}
		for i, spec in specifiers {
			if spec.conv_type == '%' {
				continue
			}
			repl := replacements.items[i]
			repl_type := sfc.chk.expr_checker.accept(repl)
			if spec.conv_type in ['d', 'i', 'o', 'u', 'x', 'X'] {
				_ = sfc.chk.check_subtype(repl_type, sfc.named_type('builtins.int'), repl.get_context(),
					'Argument must be int for format specifier')
			} else if spec.conv_type in ['e', 'E', 'f', 'F', 'g', 'G'] {
				_ = sfc.chk.check_subtype(repl_type, sfc.named_type('builtins.float'),
					repl.get_context(), 'Argument must be float for format specifier')
			}
		}
	} else if specifiers.filter(it.conv_type != '%').len > 1 {
		sfc.msg.fail('Wrong number of arguments for format string', expr_ctx, false, false,
			none)
	}
}

fn (mut sfc StringFormatterChecker) check_mapping_str_interpolation(specifiers []ConversionSpecifier, replacements Expression, expr_ctx Context) {
	if replacements is DictExpr {
		for spec in specifiers {
			if key := spec.key {
				mut found := false
				for item in replacements.items {
					if k := item.key {
						if k is StrExpr {
							dict_key := k as StrExpr
							if dict_key.value == key {
								found = true
								break
							}
						}
					}
				}
				if !found {
					sfc.msg.fail('Key "${key}" not found in format arguments', expr_ctx,
						false, false, none)
				}
			}
		}
		return
	}
	repl_type := sfc.chk.expr_checker.accept(replacements)
	if !has_type_component(repl_type, 'builtins.dict') {
		sfc.msg.fail('Expected mapping for format string with keys', replacements.get_context(),
			false, false, none)
	}
}

pub fn has_type_component(typ MypyTypeNode, fullname string) bool {
	proper_type := get_proper_type(typ)
	if proper_type is Instance {
		inst := proper_type
		info := inst.type_ or { inst.typ or { return false } }
		if isnil(info) {
			return false
		}
		return info.has_base(fullname)
	}
	if proper_type is TypeVarType {
		type_var := proper_type
		if has_type_component(type_var.upper_bound, fullname) {
			return true
		}
		return type_var.values.any(has_type_component(it, fullname))
	}
	if proper_type is UnionType {
		union_type := proper_type
		return union_type.items.any(has_type_component(it, fullname))
	}
	return false
}
