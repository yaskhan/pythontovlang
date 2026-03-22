// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:04
// checkstrformat.v — Format expression type checker
// Переведён из mypy/checkstrformat.py

module mypy

// FormatStringExpr — тип для строковых выражений форматирования
pub type FormatStringExpr = BytesExprNode | StrExprNode

// ConversionSpecifier — спецификатор конверсии форматирования
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

// new_conversion_specifier создаёт новый ConversionSpecifier
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

// has_key проверяет, есть ли ключ в спецификаторе
pub fn (cs ConversionSpecifier) has_key() bool {
	return cs.key != none
}

// has_star проверяет, содержит ли спецификатор *
pub fn (cs ConversionSpecifier) has_star() bool {
	return cs.width == '*' || cs.precision == '*'
}

// Константы для типов форматирования (используем map вместо set)
pub const numeric_types_old = {
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
pub const numeric_types_new = {
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
pub const require_int_old = {
	'o': true
	'x': true
	'X': true
}
pub const require_int_new = {
	'b': true
	'd': true
	'o': true
	'x': true
	'X': true
}
pub const float_types = {
	'e': true
	'E': true
	'f': true
	'F': true
	'g': true
	'G': true
}

// dummy_field_name — имя фиктивного поля для парсинга
pub const dummy_field_name = '__dummy_name__'

// parse_conversion_specifiers парсит c-printf-style строку форматирования
pub fn parse_conversion_specifiers(format_str string) []ConversionSpecifier {
	mut specifiers := []ConversionSpecifier{}
	// TODO: использовать регулярные выражения для парсинга
	// Временная реализация — простой поиск %
	mut pos := 0
	for pos < format_str.len {
		if format_str[pos] == `%` {
			if pos + 1 < format_str.len && format_str[pos + 1] != '%' {
				mut spec := ConversionSpecifier{
					whole_seq: format_str[pos..pos + 2]
					start_pos: pos
					conv_type: format_str[pos + 1].str()
				}
				specifiers << spec
			}
			pos += 2
		} else {
			pos++
		}
	}
	return specifiers
}

// StringFormatterChecker — проверка типов строкового форматирования
pub struct StringFormatterChecker {
pub mut:
	chk TypeCheckerSharedApi
	msg MessageBuilder
}

// new_string_formatter_checker создаёт новый StringFormatterChecker
pub fn new_string_formatter_checker(chk TypeCheckerSharedApi, msg MessageBuilder) StringFormatterChecker {
	return StringFormatterChecker{
		chk: chk
		msg: msg
	}
}

// check_str_format_call проверяет вызов str.format()
pub fn (mut sfc StringFormatterChecker) check_str_format_call(call CallExprNode, format_value string) {
	conv_specs := parse_format_value(format_value, call, sfc.msg) or { return }
	if !sfc.auto_generate_keys(conv_specs, call) {
		return
	}
	sfc.check_specs_in_format_call(call, conv_specs, format_value)
}

// auto_generate_keys преобразует '{} {name} {}' в '{0} {name} {1}'
pub fn (sfc StringFormatterChecker) auto_generate_keys(all_specs []ConversionSpecifier, ctx NodeBase) bool {
	mut some_defined := false
	mut all_defined := true
	for s in all_specs {
		if s.key != none && s.key or { '' }.is_int() {
			some_defined = true
		}
		if s.key == none {
			all_defined = false
		}
	}
	if some_defined && !all_defined {
		sfc.msg.fail('Cannot mix manual and automatic field numbering', ctx,
			code: codes.string_formatting
		)
		return false
	}
	if all_defined {
		return true
	}
	mut next_index := 0
	for mut spec in all_specs {
		if spec.key == none {
			str_index := next_index.str()
			spec.key = str_index
			if spec.field == none {
				spec.field = str_index
			} else {
				spec.field = str_index + spec.field or { '' }
			}
			next_index++
		}
	}
	return true
}

// check_str_interpolation проверяет типы в строковой интерполяции str % replacements
pub fn (mut sfc StringFormatterChecker) check_str_interpolation(expr FormatStringExpr, replacements Expression) MypyTypeNode {
	sfc.chk.expr_checker.accept(expr)
	specifiers := parse_conversion_specifiers(expr.value)
	has_mapping_keys := sfc.analyze_conversion_specifiers(specifiers, expr)
	if has_mapping_keys == none {
		// Ошибка уже сообщена
	} else if has_mapping_keys or { false } {
		sfc.check_mapping_str_interpolation(specifiers, replacements, expr)
	} else {
		sfc.check_simple_str_interpolation(specifiers, replacements, expr)
	}
	if expr is BytesExprNode {
		return sfc.named_type('builtins.bytes')
	} else if expr is StrExprNode {
		return sfc.named_type('builtins.str')
	}
	return sfc.named_type('builtins.str')
}

// analyze_conversion_specifiers анализирует спецификаторы конверсии
pub fn (sfc StringFormatterChecker) analyze_conversion_specifiers(specifiers []ConversionSpecifier, context NodeBase) ?bool {
	has_star := specifiers.any(it.has_star())
	has_key := specifiers.any(it.has_key())
	all_have_keys := specifiers.all(it.has_key() || it.conv_type == '%')

	if has_key && has_star {
		sfc.msg.string_interpolation_with_star_and_key(context)
		return none
	}
	if has_key && !all_have_keys {
		sfc.msg.string_interpolation_mixing_key_and_non_keys(context)
		return none
	}
	return has_key
}

// conversion_type возвращает тип, который принимает спецификатор конверсии
pub fn (sfc StringFormatterChecker) conversion_type(p string, context NodeBase, expr FormatStringExpr) ?MypyTypeNode {
	if p == 'b' {
		if expr !is BytesExprNode {
			sfc.msg.fail('Format character "b" is only supported on bytes patterns', context,
				code: codes.string_formatting
			)
			return none
		}
		return sfc.named_type('builtins.bytes')
	} else if p == 'a' {
		return AnyTypeNode{
			reason: TypeOfAny.special_form
		}
	} else if p in ['s', 'r'] {
		return AnyTypeNode{
			reason: TypeOfAny.special_form
		}
	} else if p in numeric_types_new {
		if p in require_int_new {
			return sfc.named_type('builtins.int')
		} else {
			return UnionTypeNode{
				items: [sfc.named_type('builtins.int'), sfc.named_type('builtins.float')]
			}
		}
	} else if p == 'c' {
		if expr is BytesExprNode {
			return UnionTypeNode{
				items: [sfc.named_type('builtins.int'), sfc.named_type('builtins.bytes')]
			}
		} else {
			return UnionTypeNode{
				items: [sfc.named_type('builtins.int'), sfc.named_type('builtins.str')]
			}
		}
	} else {
		sfc.msg.unsupported_placeholder(p, context)
		return none
	}
}

// named_type возвращает Instance тип по имени
fn (sfc StringFormatterChecker) named_type(name string) InstanceNode {
	return sfc.chk.named_type(name)
}

// accept проверяет тип узла
fn (sfc StringFormatterChecker) accept(expr Expression) MypyTypeNode {
	return sfc.chk.expr_checker.accept(expr)
}

// Вспомогательные типы
pub struct RegexMatch {
pub:
	groups map[string]string
}

pub fn (rm RegexMatch) group() string {
	return ''
}

// Вспомогательные функции-заглушки
fn parse_format_value(format_value string, ctx NodeBase, msg MessageBuilder) ?[]ConversionSpecifier {
	// TODO: реализация парсинга format строки
	return []ConversionSpecifier{}
}

fn (sfc StringFormatterChecker) check_specs_in_format_call(call CallExprNode, specs []ConversionSpecifier, format_value string) {
	// TODO: реализация
}

fn (sfc StringFormatterChecker) check_simple_str_interpolation(specifiers []ConversionSpecifier, replacements Expression, expr FormatStringExpr) {
	// TODO: реализация
}

fn (sfc StringFormatterChecker) check_mapping_str_interpolation(specifiers []ConversionSpecifier, replacements Expression, expr FormatStringExpr) {
	// TODO: реализация
}

// has_type_component проверяет, содержит ли тип указанный компонент
pub fn has_type_component(typ MypyTypeNode, fullname string) bool {
	tp := get_proper_type(typ)
	if tp is InstanceNode {
		return tp.typ.has_base(fullname)
	} else if tp is TypeVarTypeNode {
		return has_type_component(tp.upper_bound, fullname)
			|| tp.values.any(has_type_component(it, fullname))
	} else if tp is UnionTypeNode {
		return tp.items.any(has_type_component(it, fullname))
	}
	return false
}

fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	// TODO: реализация из types.v
	return t
}
