// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 03:25
module mypy

// ============================================================================
// ErrorMessage - Container for error message template and code
// ============================================================================

pub struct ErrorMessage {
pub:
	value string
	code  ?&ErrorCode
}

pub fn (m ErrorMessage) format(args ...string) ErrorMessage {
	// In a real implementation, we'd use a proper string formatting tool.
	// For now, this is a placeholder that would be used by the MessageBuilder.
	mut res := m.value
	for i, arg in args {
		res = res.replace_once('{}', arg)
	}
	return ErrorMessage{
		value: res
		code:  m.code
	}
}

pub fn (m ErrorMessage) with_additional_msg(info string) ErrorMessage {
	return ErrorMessage{
		value: m.value + info
		code:  m.code
	}
}

// ============================================================================
// Message Constants
// ============================================================================

// Invalid types
pub const invalid_type_raw_enum_value = ErrorMessage{
	value: 'Invalid type: try using Literal[{}.{}] instead?'
	code:  valid_type
}

// Type checker error message constants
pub const no_return_value_expected = ErrorMessage{
	value: 'No return value expected'
	code:  return_value
}

pub const missing_return_statement = ErrorMessage{
	value: 'Missing return statement'
	code:  return_code
}

pub const empty_body_abstract = ErrorMessage{
	value: 'If the method is meant to be abstract, use @abc.abstractmethod'
	code:  redundant_expr
}

pub const incompatible_return_value_type = ErrorMessage{
	value: 'Incompatible return value type'
	code:  return_value
}

pub const return_value_expected = ErrorMessage{
	value: 'Return value expected'
	code:  return_value
}

pub const incompatible_types = ErrorMessage{
	value: 'Incompatible types'
	code:  none
}

pub const incompatible_types_in_assignment = ErrorMessage{
	value: 'Incompatible types in assignment'
	code:  assignment
}

pub const incompatible_redefinition = ErrorMessage{
	value: 'Incompatible redefinition'
	code:  none
}

pub const cannot_assign_to_method = ErrorMessage{
	value: 'Cannot assign to a method'
	code:  none
}

pub const cannot_assign_to_type = ErrorMessage{
	value: 'Cannot assign to a type'
	code:  none
}

pub const function_type_expected = ErrorMessage{
	value: 'Function is missing a type annotation'
	code:  none // would be NO_UNTYPED_DEF if implemented
}

pub const type_always_true = ErrorMessage{
	value: '{} which does not implement __bool__ or __len__ so it could always be true in boolean context'
	code:  truthy_bool
}

// ... (more constants would be added as needed)
