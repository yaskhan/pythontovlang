module variables

import ast

pub fn (mut m VariablesModule) visit_delete(node ast.Delete) {
	for target in node.targets {
		if target is ast.Subscript {
			sub := target
			value_expr := m.visit_expr(sub.value)
			if sub.slice is ast.Slice {
				slice := sub.slice
				lower := if lower_expr := slice.lower {
					m.visit_expr(lower_expr)
				} else {
					'0'
				}
				upper := if upper_expr := slice.upper {
					m.visit_expr(upper_expr)
				} else {
					'${value_expr}.len'
				}
				m.state.used_delete_many = true
				m.emit('${value_expr}.delete_many(${lower}, (${upper}) - (${lower}))')
			} else {
				index_expr := m.visit_expr(sub.slice)
				m.emit('${value_expr}.delete(${index_expr})')
			}
			continue
		}

		if target is ast.Name {
			m.emit("//##LLM@@ 'del ${target.id}' statement ignored. V does not support deleting variables from scope.")
			continue
		}

		if target is ast.Attribute {
			attr := target
			value_expr := m.visit_expr(attr.value)
			m.emit("//##LLM@@ 'del ${value_expr}.${attr.attr}' statement ignored. V does not support deleting struct attributes.")
			continue
		}

		m.emit("//##LLM@@ 'del' statement with unsupported target type.")
	}
}
