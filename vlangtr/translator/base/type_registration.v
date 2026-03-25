module base

import ast
import models

pub struct HelperEmitter {
pub mut:
	helper_structs []string
}

pub fn (mut e HelperEmitter) add_helper_struct(code string) {
	e.helper_structs << code
}

// register_literal_enum emits an enum for a Python Literal declaration and returns enum name.
pub fn register_literal_enum(nodes []ast.Expression, mut generated_literal_enums map[string]string, mut literal_enum_values map[string]map[string]string, mut emitter HelperEmitter) string {
	mut values := []string{}
	for node in nodes {
		if node is ast.Constant {
			values << node.value
		} else if node is ast.UnaryOp {
			if node.op.value == '-' && node.operand is ast.Constant {
				operand_const := node.operand
				values << '-${operand_const.value}'
			} else {
				values << 'UnaryOp'
			}
		} else {
			values << node.str()
		}
	}

	if values.len == 0 {
		return 'LiteralEnum_0'
	}

	mut sorted_values := values.clone()
	sorted_values.sort()
	key := 'Literal_${sorted_values.join('_')}'
	if key in generated_literal_enums {
		return generated_literal_enums[key]
	}

	enum_name := 'LiteralEnum_${generated_literal_enums.len}'
	mut enum_lines := ['pub enum ${enum_name} {']
	mut value_map := map[string]string{}
	mut used_member_names := map[string]bool{}

	for i, val in values {
		mut member_name := val.to_lower().replace(' ', '_').replace('-', '_').replace('.',
			'_')
		if member_name.len == 0 || !member_name[0].is_letter() {
			member_name = 'val_${i}'
		}
		base_member := member_name
		mut counter := 1
		for {
			if member_name !in used_member_names {
				break
			}
			member_name = '${base_member}_${counter}'
			counter++
		}
		used_member_names[member_name] = true
		enum_lines << '    ${member_name}'
		value_map[val] = member_name
	}
	enum_lines << '}'
	emitter.add_helper_struct(enum_lines.join('\n'))

	mut str_lines := ['pub fn (e ${enum_name}) str() string {', '    match e {']
	for val, member in value_map {
		str_lines << "        .${member} { return \"${val}\" }"
	}
	str_lines << '    }'
	str_lines << '}'
	emitter.add_helper_struct(str_lines.join('\n'))

	generated_literal_enums[key] = enum_name
	literal_enum_values[enum_name] = value_map.clone()
	return enum_name
}

// register_sum_type generates a named V sum type and returns its use-site type.
pub fn register_sum_type(v_union_type string, active_v_generics []string, include_all_symbols bool, mut generated_sum_types map[string]string, mut emitter HelperEmitter) string {
	mut parts := v_union_type.split('|').map(it.trim_space())
	if parts.len <= 1 {
		return v_union_type
	}
	parts.sort()
	normalized := parts.join(' | ')
	if normalized in generated_sum_types {
		return generated_sum_types[normalized]
	}

	mut type_name := 'SumType_' + parts.map(clean_sum_part(it)).join('')
	base_name := type_name
	mut counter := 1
	for {
		if !generated_sum_types.values().contains(type_name) {
			break
		}
		type_name = '${base_name}_${counter}'
		counter++
	}

	mut used_generics := []string{}
	for g in active_v_generics {
		if g in parts || parts.any(it.contains('[${g}]')) || parts.any(it.contains('${g} ')) {
			used_generics << g
		}
	}

	gen_decl := if used_generics.len > 0 { '[${used_generics.join(', ')}]' } else { '' }
	gen_args := gen_decl
	pub_prefix := if include_all_symbols { 'pub ' } else { '' }
	emitter.add_helper_struct('${pub_prefix}type ${type_name}${gen_decl} = ${normalized}')
	result := '${type_name}${gen_args}'
	generated_sum_types[normalized] = result
	return result
}

// register_tuple_struct emits a tuple-like struct and returns its name.
pub fn register_tuple_struct(tuple_types_str string, include_all_symbols bool, map_type_fn fn (string) string, mut generated_tuple_structs map[string]string, mut emitter HelperEmitter) string {
	struct_name := models.get_tuple_struct_name(tuple_types_str)
	if struct_name in generated_tuple_structs {
		return struct_name
	}

	field_types := tuple_types_str.split(',').map(it.trim_space())
	mut fields := []string{}
	for i, t in field_types {
		v_type := map_type_fn(t)
		fields << '    it_${i} ${v_type}'
	}
	pub_prefix := if include_all_symbols { 'pub ' } else { '' }
	struct_def := '${pub_prefix}struct ${struct_name} {\n${fields.join('\n')}\n}'
	emitter.add_helper_struct(struct_def)
	generated_tuple_structs[struct_name] = struct_name
	return struct_name
}

fn clean_sum_part(s string) string {
	replacements := {
		'int':    'Int'
		'string': 'String'
		'bool':   'Bool'
		'f64':    'F64'
		'i64':    'I64'
		'u32':    'U32'
		'u64':    'U64'
		'i8':     'I8'
		'i16':    'I16'
		'u8':     'U8'
		'u16':    'U16'
		'Any':    'Any'
		'void':   'Void'
		'none':   'None'
	}
	mut out := replacements[s] or { s }
	out = out.replace('[]', 'Array').replace('map', 'Map')
	mut clean := ''
	for ch in out {
		if ch.is_letter() || ch.is_digit() || ch == `_` {
			clean += ch.str()
		}
	}
	return clean
}
