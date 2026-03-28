module expressions

import ast
import base
import stdlib_map

pub fn (mut eg ExprGen) visit_attribute(node ast.Attribute) string {
	// Handle module attributes
	if node.value is ast.Name && node.value.id in eg.state.imported_modules {
		module_name := eg.state.imported_modules[node.value.id]
		if node.attr == '__name__' { return "'${module_name}'" }
		
		if eg.state.mapper != unsafe { nil } {
			mapper := unsafe { &stdlib_map.StdLibMapper(eg.state.mapper) }
			if res := mapper.get_mapping(module_name, node.attr, []) {
				eg.state.used_builtins[res] = true
				return res
			}
		}

		is_class := node.attr.len > 0 && node.attr[0].is_capital()
		return '${module_name}.${base.sanitize_name(node.attr, is_class, map[string]bool{}, "", map[string]bool{})}'
	}

	if node.attr == '__class__' {
		return "typeof(${eg.visit(node.value)})"
	}
	if node.attr == '__annotations__' || node.attr == '__annotate__' {
		obj := eg.visit(node.value)
		obj_type := eg.guess_type(node.value)
		if obj_type in eg.state.defined_classes || obj in eg.state.defined_classes {
			class_name := if obj in eg.state.defined_classes { obj } else { obj_type }
			return "py_get_type_hints[${class_name}]()"
		}
		if obj in eg.state.function_names { return "${obj}__annotations__" }
		return "py_get_type_hints_generic(${obj})"
	}

	if node.attr == 'real' && eg.guess_type(node.value) == 'PyComplex' {
		return "${eg.visit(node.value)}.re"
	}
	if node.attr == 'imag' && eg.guess_type(node.value) == 'PyComplex' {
		return "${eg.visit(node.value)}.im"
	}

	mut attr_name := node.attr
	if attr_name == '__next__' { attr_name = 'next' }
	else if attr_name == '__await__' { attr_name = 'await_' }
	else if attr_name == '__iter__' { attr_name = 'iter' }

	if eg.state.current_class.len > 0 {
		attr_name = base.mangle_name(attr_name, eg.state.current_class)
	}
	attr_name = base.sanitize_name(attr_name, false, map[string]bool{}, "", map[string]bool{})

	obj := eg.visit(node.value)
	obj_type := eg.guess_type(node.value)
	obj_base := if obj.contains('[') { obj.all_before('[') } else { obj }

	if obj in eg.state.function_names || obj_base in eg.state.function_names {
		return "${obj}__${attr_name}"
	}

	// Static/Class methods and Class variables
	if obj_base in eg.state.defined_classes || obj_type in eg.state.defined_classes {
		target_class := if obj_base in eg.state.defined_classes { obj_base } else { obj_type }
		
		// Check for class variables first (meta singleton)
		if defining := base.find_defining_class_for_class_var(target_class, node.attr, eg.state.class_vars, eg.analyzer.class_hierarchy) {
			meta_const := "${base.to_snake_case(defining)}_meta"
			return "${meta_const}.${attr_name}"
		}

		if defining := base.find_defining_class_for_static_method(target_class, node.attr, eg.analyzer.static_methods, eg.analyzer.class_methods, eg.analyzer.class_hierarchy) {
			return "${defining}_${attr_name}"
		}
	}

	mut res := "${obj}.${attr_name}"

	obj_name := eg.analyzer.render_expr(node.value)
	full_name := '${obj_name}.${node.attr}'
	if remapped := eg.state.name_remap[full_name] {
		return remapped
	}

	// Narrowing/Casting
	loc_key := '${node.token.line}:${node.token.column}'
	v_attr_base := eg.map_python_type(eg.guess_type_no_loc(node), true)
	
	mut original_type := v_attr_base
	obj_type_clean := if obj_type.contains('[') { obj_type.all_before('[') } else { obj_type }
	struct_field_key := '${obj_type_clean}.${node.attr}'
	if base_field_type := eg.analyzer.get_type(struct_field_key) {
		if base_field_type != 'Any' && base_field_type != 'unknown' {
			original_type = eg.map_python_type(base_field_type, true)
		}
	}

	mut current := v_attr_base
	if narrowed := eg.analyzer.location_map[loc_key] {
		current = eg.map_python_type(narrowed, true)
	} else if inferred := eg.analyzer.get_type(full_name) {
		if inferred != 'Any' && inferred != 'unknown' {
			current = eg.map_python_type(inferred, true)
		}
	}

	if current != original_type && current != 'Any' && original_type.contains('|') {
		res = "(${res} as ${current})"
	}

	return res
}
