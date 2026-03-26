module expressions

import ast
import base

pub fn (mut eg ExprGen) visit_attribute(node ast.Attribute) string {
	if node.value is ast.Name && node.value.id in eg.state.imported_modules {
		module_name := eg.state.imported_modules[node.value.id]
		if node.attr == '__name__' {
			return "'${module_name}'"
		}
		return '${module_name}.${base.sanitize_name(node.attr, false, map[string]bool{},
			'', map[string]bool{})}'
	}

	if node.attr == '__class__' {
		return 'typeof(${eg.visit(node.value)})'
	}
	if node.attr == '__annotations__' || node.attr == '__annotate__' {
		return 'py_get_type_hints_generic(${eg.visit(node.value)})'
	}
	if node.attr == '__type_params__' {
		obj := eg.visit(node.value)
		base_name := if obj.contains('[') { obj.all_before('[') } else { obj }
		if base_name in eg.state.type_params_map {
			params := eg.state.type_params_map[base_name]
			if params.len == 0 {
				return '[]string{}'
			}
			return '[' + params.map("'${it}'").join(', ') + ']'
		}
		return '[]string{}'
	}

	if node.attr == 'real' && eg.guess_type(node.value) == 'PyComplex' {
		return '${eg.visit(node.value)}.re'
	}
	if node.attr == 'imag' && eg.guess_type(node.value) == 'PyComplex' {
		return '${eg.visit(node.value)}.im'
	}

	mut attr_name := node.attr
	if attr_name == '__next__' {
		attr_name = 'next'
	} else if attr_name == '__await__' {
		attr_name = 'await_'
	} else if attr_name == '__iter__' {
		attr_name = 'iter'
	} else if attr_name == '__init__' {
		attr_name = 'init'
	} else if attr_name == '__new__' {
		attr_name = 'new'
	} else if attr_name == 'fn' {
		attr_name = 'run'
	}

	if eg.state.current_class.len > 0 {
		attr_name = base.mangle_name(attr_name, eg.state.current_class)
	}
	attr_name = base.sanitize_name(attr_name, false, map[string]bool{}, '', map[string]bool{})

	obj := eg.visit(node.value)
	obj_type := eg.guess_type(node.value)
	obj_base := if obj.contains('[') { obj.all_before('[') } else { obj }

	if obj in eg.state.function_names || obj_base in eg.state.function_names {
		return '${obj}__${attr_name}'
	}

	if obj_base in eg.state.defined_classes || obj_type in eg.state.defined_classes {
		target_class := if obj_base in eg.state.defined_classes { obj_base } else { obj_type }
		if defining := base.find_defining_class_for_static_method(target_class, node.attr,
			eg.analyzer.static_methods, eg.analyzer.class_methods, eg.analyzer.class_hierarchy)
		{
			return '${defining}_${attr_name}'
		}
	}

	return '${obj}.${attr_name}'
}
