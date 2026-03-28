module base

import ast
import models

pub struct TypeUtilsContext {
pub mut:
	imported_symbols map[string]string
	scc_files        []string
	used_builtins    map[string]bool
	warnings         []string
	config           voidptr
}

pub struct TypeMapOptions {
pub:
	struct_name        string
	allow_union        bool = true
	register_sum_types bool = true
	is_return          bool
	self_type          string = 'Self'
	generic_map        map[string]string
}

pub fn is_collection_type(v_type string) bool {
	return v_type.starts_with('[]') || v_type.starts_with('map[')
		|| v_type.starts_with('datatypes.Set[') || v_type == 'string' || v_type == 'LiteralString'
}

pub fn is_clonable_collection(v_type string) bool {
	return v_type.starts_with('[]') || v_type.starts_with('map[')
}

pub fn is_tuple_struct(v_type string) bool {
	return v_type.starts_with('TupleStruct_')
}

pub fn is_string_type(v_type string) bool {
	return v_type == 'string' || v_type == 'LiteralString'
}

pub fn is_numeric_type(v_type string) bool {
	return v_type in ['int', 'f64', 'i64', 'u32', 'u64', 'i8', 'i16', 'u8', 'u16']
}

// wrap_bool lowers Python truthiness into explicit V boolean checks.
pub fn wrap_bool(node ast.Expression, expr string, v_type string, invert bool) string {
	if v_type.starts_with('?') {
		inner := v_type[1..]
		inner_cond := bool_condition(expr, inner, invert)
		if invert {
			if inner_cond.len > 0 {
				return '(${expr} == none || ${inner_cond})'
			}
			return '${expr} == none'
		}
		if inner_cond.len > 0 {
			return '(${expr} != none && ${inner_cond})'
		}
		return '${expr} != none'
	}

	if v_type == 'none' {
		return if invert { 'true' } else { 'false' }
	}
	if v_type == 'bool' {
		return if invert { '!${expr}' } else { expr }
	}
	if v_type == 'Any' {
		return if invert { '!py_bool(${expr})' } else { 'py_bool(${expr})' }
	}
	return bool_condition(expr, v_type, invert)
}

fn bool_condition(expr string, v_type string, invert bool) string {
	if is_collection_type(v_type) {
		op := if invert { '==' } else { '>' }
		return '${expr}.len ${op} 0'
	}
	if is_numeric_type(v_type) {
		op := if invert { '==' } else { '!=' }
		return '${expr} ${op} 0'
	}
	if v_type == 'bool' {
		return if invert { '!${expr}' } else { expr }
	}
	if v_type == 'Any' {
		return if invert { '!py_bool(${expr})' } else { 'py_bool(${expr})' }
	}
	return if invert { '!${expr}' } else { expr }
}

// map_type is a centralized Python-to-V type mapper with post-processing.
pub fn map_type(type_str string, opts TypeMapOptions, mut ctx TypeUtilsContext, sum_type_registrar fn (string) string, literal_registrar fn ([]string) string, tuple_registrar fn (string) string) string {
	if type_str.contains('TypeForm') {
		ctx.warnings << "Experimental feature 'TypeForm' is used."
	}

	registrar := if opts.register_sum_types {
		sum_type_registrar
	} else {
		fn (_ string) string {
			return ''
		}
	}
	tup_registrar := if opts.register_sum_types {
		tuple_registrar
	} else {
		fn (_ string) string {
			return ''
		}
	}

	mut v_type := models.map_python_type_to_v(type_str, opts.self_type, opts.allow_union,
		opts.generic_map, registrar, literal_registrar, tup_registrar)
	if v_type.contains('map[Any]') {
		v_type = v_type.replace('map[Any]', 'map[string]')
	}
	if opts.is_return && v_type == 'none' {
		return 'void'
	}
	if v_type == 'LiteralString' {
		v_type = 'string'
	}

	basic_v_types := ['Any', 'int', 'string', 'bool', 'void', 'none', 'f64', 'i64', 'u32', 'u64',
		'i8', 'i16', 'u8', 'u16', 'Final', 'ClassVar', 'LiteralString', 'noreturn']
	if v_type in basic_v_types {
		return v_type
	}

	if v_type in ctx.imported_symbols {
		return ctx.imported_symbols[v_type]
	}

	if v_type.contains('.') {
		parts := v_type.split('.')
		if parts.len > 1 {
			module_prefix := parts[..parts.len - 1].join('.')
			typename := parts[parts.len - 1]
			for f in ctx.scc_files {
				norm := f.replace('.py', '').replace('/', '.').replace('\\', '.')
				if module_prefix.ends_with(norm) {
					prefix := get_scc_prefix(f)
					return '${prefix}__${typename}'
				}
			}
		}
	}

	return v_type
}

pub fn get_v_default_value(v_type string, active_v_generics []string) string {
	if v_type.starts_with('?') {
		return 'none'
	}
	if v_type in ['int', 'i64', 'u32', 'u64', 'i8', 'i16', 'u8', 'u16'] {
		return '0'
	}
	if v_type in ['f64', 'f32'] {
		return '0.0'
	}
	if v_type == 'bool' {
		return 'false'
	}
	if v_type == 'string' {
		return "'0'"
	}
	if v_type.starts_with('[]') || v_type.starts_with('map[') {
		return '${v_type}{}'
	}
	if v_type == 'Any' {
		return 'Any(NoneExpr{})'
	}
	if v_type.len > 0 && v_type[0].is_capital() && !v_type.contains('|') {
		if v_type in active_v_generics {
			return 'py_zero[${v_type}]()'
		}
		return '${v_type}{}'
	}
	return 'none'
}
