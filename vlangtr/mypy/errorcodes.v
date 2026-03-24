// I, Antigravity, am working on this file. Started: 2026-03-22 03:22
module mypy

// ============================================================================
// ErrorCode - Classification of possible errors mypy can detect
// ============================================================================

@[heap]
pub struct ErrorCode {
pub:
	code            string
	description     string
	category        string
	default_enabled bool
	sub_code_of     ?&ErrorCode
}

pub fn (e ErrorCode) str() string {
	return '<ErrorCode ${e.code}>'
}

pub fn (e ErrorCode) repr() string {
	return '<ErrorCode ${e.category}: ${e.code}>'
}

pub const literal_req = &ErrorCode{
	code:        'literal-required'
	description: 'Argument must be a literal'
	category:    'General'
}

// Global maps for error codes
pub const error_codes = map[string]&ErrorCode{}
pub const sub_code_map = map[string][]string{}

// Helper to register error code (in V we use consts, so we manually populate these if needed,
// or use a registration function called at init)

pub fn register_error_code(code &ErrorCode) {
	// In V 0.5.x, map is not really mutable if it's a const.
	// We might need a global mut for this if dynamic registration is required.
	// However, for now we just define them as consts.
}

// ============================================================================
// Error Code Constants
// ============================================================================

pub const attr_defined = &ErrorCode{
	code:            'attr-defined'
	description:     'Check that attribute exists'
	category:        'General'
	default_enabled: true
}

pub const name_defined = &ErrorCode{
	code:            'name-defined'
	description:     'Check that name is defined'
	category:        'General'
	default_enabled: true
}

pub const call_arg = &ErrorCode{
	code:            'call-arg'
	description:     'Check number, names and kinds of arguments in calls'
	category:        'General'
	default_enabled: true
}

pub const arg_type = &ErrorCode{
	code:            'arg-type'
	description:     'Check argument types in calls'
	category:        'General'
	default_enabled: true
}

pub const call_overload = &ErrorCode{
	code:            'call-overload'
	description:     'Check that an overload variant matches arguments'
	category:        'General'
	default_enabled: true
}

pub const valid_type = &ErrorCode{
	code:            'valid-type'
	description:     'Check that type (annotation) is valid'
	category:        'General'
	default_enabled: true
}

pub const nonetype_type = &ErrorCode{
	code:            'nonetype-type'
	description:     'Check that type (annotation) is not NoneType'
	category:        'General'
	default_enabled: true
}

pub const var_annotated = &ErrorCode{
	code:            'var-annotated'
	description:     "Require variable annotation if type can't be inferred"
	category:        'General'
	default_enabled: true
}

pub const override_code = &ErrorCode{
	code:            'override'
	description:     'Check that method override is compatible with base class'
	category:        'General'
	default_enabled: true
}

pub const return_code = &ErrorCode{
	code:            'return'
	description:     'Check that function always returns a value'
	category:        'General'
	default_enabled: true
}

pub const return_value = &ErrorCode{
	code:            'return-value'
	description:     'Check that return value is compatible with signature'
	category:        'General'
	default_enabled: true
}

pub const assignment = &ErrorCode{
	code:            'assignment'
	description:     'Check that assigned value is compatible with target'
	category:        'General'
	default_enabled: true
}

pub const method_assign = &ErrorCode{
	code:            'method-assign'
	description:     'Check that assignment target is not a method'
	category:        'General'
	default_enabled: true
	sub_code_of:     assignment
}

pub const type_arg = &ErrorCode{
	code:            'type-arg'
	description:     'Check that generic type arguments are present'
	category:        'General'
	default_enabled: true
}

pub const type_var = &ErrorCode{
	code:            'type-var'
	description:     'Check that type variable values are valid'
	category:        'General'
	default_enabled: true
}

pub const union_attr = &ErrorCode{
	code:            'union-attr'
	description:     'Check that attribute exists in each item of a union'
	category:        'General'
	default_enabled: true
}

pub const index_code = &ErrorCode{
	code:            'index'
	description:     'Check indexing operations'
	category:        'General'
	default_enabled: true
}

pub const operator = &ErrorCode{
	code:            'operator'
	description:     'Check that operator is valid for operands'
	category:        'General'
	default_enabled: true
}

pub const list_item = &ErrorCode{
	code:            'list-item'
	description:     'Check list items in a list expression [item, ...]'
	category:        'General'
	default_enabled: true
}

pub const dict_item = &ErrorCode{
	code:            'dict-item'
	description:     'Check dict items in a dict expression {key: value, ...}'
	category:        'General'
	default_enabled: true
}

pub const typeddict_item = &ErrorCode{
	code:            'typeddict-item'
	description:     'Check items when constructing TypedDict'
	category:        'General'
	default_enabled: true
}

pub const typeddict_unknown_key = &ErrorCode{
	code:            'typeddict-unknown-key'
	description:     'Check unknown keys when constructing TypedDict'
	category:        'General'
	default_enabled: true
	sub_code_of:     typeddict_item
}

pub const import_code = &ErrorCode{
	code:            'import'
	description:     'Require that imported module can be found or has stubs'
	category:        'General'
	default_enabled: true
}

pub const import_not_found = &ErrorCode{
	code:            'import-not-found'
	description:     'Require that imported module can be found'
	category:        'General'
	default_enabled: true
	sub_code_of:     import_code
}

pub const import_untyped = &ErrorCode{
	code:            'import-untyped'
	description:     'Require that imported module has stubs'
	category:        'General'
	default_enabled: true
	sub_code_of:     import_code
}

pub const syntax = &ErrorCode{
	code:            'syntax'
	description:     'Report syntax errors'
	category:        'General'
	default_enabled: true
}

pub const misc = &ErrorCode{
	code:            'misc'
	description:     'Miscellaneous other checks'
	category:        'General'
	default_enabled: true
}

pub const deprecated = &ErrorCode{
	code:            'deprecated'
	description:     'Warn when importing or using deprecated things'
	category:        'General'
	default_enabled: false
}

pub const unreachable = &ErrorCode{
	code:            'unreachable'
	description:     'Warn about unreachable statements or expressions'
	category:        'General'
	default_enabled: true
}

pub const redundant_cast = &ErrorCode{
	code:            'redundant-cast'
	description:     'Check that cast changes type of expression'
	category:        'General'
	default_enabled: true
}

pub const redundant_expr = &ErrorCode{
	code:            'redundant-expr'
	description:     'Warn about redundant expressions'
	category:        'General'
	default_enabled: false
}

pub const truthy_bool = &ErrorCode{
	code:            'truthy-bool'
	description:     'Warn about expressions that could always evaluate to true in boolean contexts'
	category:        'General'
	default_enabled: false
}

pub const truthy_function = &ErrorCode{
	code:            'truthy-function'
	description:     'Warn about function that always evaluate to true in boolean contexts'
	category:        'General'
	default_enabled: true
}

// Use a map to store all codes for easy lookup
pub fn get_mypy_error_codes() map[string]&ErrorCode {
	return {
		'attr-defined':          attr_defined
		'name-defined':          name_defined
		'call-arg':              call_arg
		'arg-type':              arg_type
		'call-overload':         call_overload
		'valid-type':            valid_type
		'nonetype-type':         nonetype_type
		'var-annotated':         var_annotated
		'override':              override_code
		'return':                return_code
		'return-value':          return_value
		'assignment':            assignment
		'method-assign':         method_assign
		'type-arg':              type_arg
		'type-var':              type_var
		'union-attr':            union_attr
		'index':                 index_code
		'operator':              operator
		'list-item':             list_item
		'dict-item':             dict_item
		'typeddict-item':        typeddict_item
		'typeddict-unknown-key': typeddict_unknown_key
		'import':                import_code
		'import-not-found':      import_not_found
		'import-untyped':        import_untyped
		'syntax':                syntax
		'misc':                  misc
		'deprecated':            deprecated
		'unreachable':           unreachable
		'redundant-cast':        redundant_cast
		'redundant-expr':        redundant_expr
		'truthy-bool':           truthy_bool
		'truthy-function':       truthy_function
	}
}

pub const mypy_error_codes = get_mypy_error_codes()
