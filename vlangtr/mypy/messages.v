// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 14:10
module mypy

// Вывод форматированных сообщений об ошибках (MessageBuilder)

pub struct MessageBuilder {
pub mut:
	errors  &Errors
	options &Options
	modules map[string]&MypyFile

	disable_type_names_stack []bool
}

pub fn (mut m MessageBuilder) report(msg string, context Context, severity string, code ?ErrorCode) {
	// Основная функция для ошибок/нотаций
	mut err_info := &ErrorInfo{
		line:       context.line
		column:     context.column
		end_line:   context.end_line
		end_column: context.end_column
		message:    msg
		severity:   severity
		code:       code
	}
	m.errors.add_error_info(err_info, none)
}

pub fn (mut m MessageBuilder) fail(msg string, context Context, serious bool, blocker bool, code ?ErrorCode) {
	m.report(msg, context, 'error', code)
}

pub fn (mut m MessageBuilder) note(msg string, context Context, code ?ErrorCode) {
	m.report(msg, context, 'note', code)
}

// ---------------------------------------------------------
// Типичные сообщения об ошибках
// ---------------------------------------------------------

pub fn (mut m MessageBuilder) has_no_attr(original_type MypyTypeNode, typ MypyTypeNode, member string, context Context) MypyTypeNode {
	if m.are_type_names_disabled() {
		m.fail("Item has no attribute '${member}'", context, false, false, none)
	} else {
		type_str := m.format_type(original_type)
		m.fail("${type_str} has no attribute '${member}'", context, false, false, none) // TODO: error code attr-defined
	}
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

pub fn (mut m MessageBuilder) not_callable(typ MypyTypeNode, context Context) MypyTypeNode {
	type_str := m.format_type(typ)
	m.fail('${type_str} not callable', context, false, false, none) // TODO: operator
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

pub fn (mut m MessageBuilder) untyped_function_call(callee &CallableType, context Context) MypyTypeNode {
	// Function name is optional
	name := callee.name or { '(unknown)' }
	m.fail('Call to untyped function ${name} in typed context', context, false, false,
		none)
	return MypyTypeNode(AnyType{
		type_of_any: .from_error
	})
}

pub fn (mut m MessageBuilder) incompatible_argument(n int, arg_type MypyTypeNode, expected_type MypyTypeNode, context Context) {
	arg_str := m.format_type(arg_type)
	exp_str := m.format_type(expected_type)
	m.fail("Argument ${n} has incompatible type '${arg_str}'; expected '${exp_str}'",
		context, false, false, none)
}

pub fn (mut m MessageBuilder) unsupported_operand_types(op string, left MypyTypeNode, right MypyTypeNode, context Context) {
	if m.are_type_names_disabled() {
		m.fail('Unsupported operand types for ${op} (some union)', context, false, false,
			none)
	} else {
		left_str := m.format_type(left)
		right_str := m.format_type(right)
		m.fail("Unsupported operand types for ${op} ('${left_str}' and '${right_str}')",
			context, false, false, none)
	}
}

pub fn (mut m MessageBuilder) invalid_index_type(index_type MypyTypeNode, base_type MypyTypeNode, context Context) {
	idx_str := m.format_type(index_type)
	base_str := m.format_type(base_type)
	m.fail("Invalid index type '${idx_str}' for '${base_str}'", context, false, false,
		none)
}

// ---------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------

pub fn (mut m MessageBuilder) are_type_names_disabled() bool {
	if m.disable_type_names_stack.len > 0 {
		return m.disable_type_names_stack.last()
	}
	return false
}

pub fn (mut m MessageBuilder) format_type(typ MypyTypeNode) string {
	return typ.type_str()
}

pub fn (mut m MessageBuilder) format_type_bare(typ MypyTypeNode) string {
	return typ.type_str()
}
