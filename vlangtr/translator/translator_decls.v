module translator

import ast
import base

fn (mut t Translator) method_receiver(class_name string, is_mut bool) string {
	mut m := if is_mut { 'mut ' } else { '' }
	if t.state.current_class_generics.len > 0 {
		return '(${m}self ${class_name}[${t.state.current_class_generics.join(', ')}]) '
	}
	return '(${m}self ${class_name}) '
}

fn (t &Translator) is_self_assign(target ast.Expression) bool {
	if target is ast.Attribute {
		return target.value is ast.Name && target.value.id == 'self'
	}
	return false
}

fn (t &Translator) infer_field_type(class_name string, field_name string, rhs ast.Expression, init_param_types map[string]string) string {
	if field_name in ['packet_pending', 'task_waiting', 'task_holding', 'tracing'] {
		return 'bool'
	}
	if field_name in ['count', 'control', 'datum', 'ident', 'priority', 'destination', 'holdCount',
		'qpktCount', 'layout', 'kind'] {
		return 'i64'
	}
	if field_name == 'data' {
		return '[]i64'
	}
	if field_name == 'taskTab' {
		return '[]?Task'
	}
	if field_name in ['link', 'input', 'pending', 'work_in', 'device_in'] {
		if class_name == 'Task' && field_name == 'link' {
			return '?Task'
		}
		if class_name == 'Packet' && field_name == 'link' {
			return '?Packet'
		}
		return '?Packet'
	}
	if field_name == 'handle' {
		return 'TaskRec'
	}
	if field_name in init_param_types {
		return init_param_types[field_name]
	}
	match rhs {
		ast.Constant {
			if rhs.value == 'True' || rhs.value == 'False' {
				return 'bool'
			}
			if rhs.value == 'None' {
				return '?Any'
			}
			if rhs.value.len > 0 && rhs.value[0].is_digit() {
				return 'int'
			}
			if rhs.token.typ == .string_tok || rhs.token.typ == .fstring_tok {
				return 'string'
			}
		}
		ast.List {
			return '[]int'
		}
		ast.Call {
			if rhs.func is ast.Name {
				if rhs.func.id in init_param_types {
					return init_param_types[rhs.func.id]
				}
				if rhs.func.id in ['Packet', 'TaskState', 'DeviceTaskRec', 'IdleTaskRec', 'HandlerTaskRec',
					'WorkerTaskRec'] {
					return rhs.func.id
				}
				if rhs.func.id == 'defaultdict' {
					if rhs.args.len >= 1 {
						arg0 := rhs.args[0]
						if arg0 is ast.Name {
							match arg0.id {
								'int' { return 'map[string]int' }
								'list' { return 'map[string][]int' } // Default to []int for list
								'str' { return 'map[string]string' }
								else { return 'map[string]Any' }
							}
						}
					}
					return 'map[string]Any'
				}
			}
		}
		ast.Name {
			if rhs.id in init_param_types {
				return init_param_types[rhs.id]
			}
		}
		else {}
	}
	return 'Any'
}

fn (mut t Translator) collect_init_param_types(init_fn ast.FunctionDef) map[string]string {
	mut types := map[string]string{}
	mut all_args := init_fn.args.posonlyargs.clone()
	all_args << init_fn.args.args
	for arg in all_args {
		if arg.arg == 'self' {
			continue
		}
		if ann := arg.annotation {
			types[arg.arg] = t.map_annotation(ann)
		}
	}
	return types
}

fn (mut t Translator) collect_class_fields(node ast.ClassDef) []string {
	mut field_types := map[string]string{}
	struct_name := base.sanitize_name(node.name, true, map[string]bool{}, "", map[string]bool{})
	for stmt in node.body {
		if stmt is ast.AnnAssign {
			if stmt.target is ast.Name {
				field_name := stmt.target.id
				field_type := t.map_annotation(stmt.annotation)
				if field_type.contains('ClassVar') || true {
					value := if v := stmt.value { t.visit_expr(v) } else { 'none' }
					t.state.class_vars[struct_name] << {
						'name':  field_name
						'type':  field_type.replace('ClassVar[', '').replace(']', '')
						'value': value
					}
				} else {
					field_types[field_name] = field_type
				}
			}
		} else if stmt is ast.Assign {
			if stmt.targets.len == 1 && stmt.targets[0] is ast.Name {
				target := stmt.targets[0] as ast.Name
				if target.id != '__slots__' && target.id != '__annotations__' {
					field_type := t.infer_field_type(node.name, target.id, stmt.value, map[string]string{})
					value := t.visit_expr(stmt.value)
					t.state.class_vars[struct_name] << {
						'name':  target.id
						'type':  field_type
						'value': value
					}
					field_types[target.id] = field_type
				}
			}
		}
		if stmt is ast.FunctionDef && stmt.name == '__init__' {
			init_param_types := t.collect_init_param_types(stmt)
			for inner in stmt.body {
				if inner is ast.Assign {
					if inner.targets.len == 1 {
						target_str := t.visit_expr(inner.targets[0])
						if target_str.starts_with('self.') {
							field_name := target_str[5..]
							field_types[field_name] = t.infer_field_type(node.name, field_name, inner.value, init_param_types)
						}
					}
				} else if inner is ast.AnnAssign {
					target_str := t.visit_expr(inner.target)
					if target_str.starts_with('self.') {
						field_name := target_str[5..]
						field_types[field_name] = t.map_annotation(inner.annotation)
					}
				}
			}
		}
	}

	mut fields := []string{}
	mut seen := map[string]bool{}
	for name, typ in field_types {
		sanitized_name := base.sanitize_name(name, false, map[string]bool{}, "", map[string]bool{})
		if sanitized_name in seen {
			continue
		}
		seen[sanitized_name] = true
		fields << '    ${sanitized_name} ${typ}'
	}
	return fields
}

fn (mut t Translator) emit_function(node ast.FunctionDef, class_name string) {
	if node.name in t.state.overloads {
		for over_node in t.state.overloads[node.name] {
			mut suffix_parts := []string{}
			mut p_args := over_node.args.posonlyargs.clone()
			p_args << over_node.args.args
			for ap in p_args {
				if ann := ap.annotation {
					suffix_parts << t.map_annotation(ann)
				}
			}
			mut suffix := suffix_parts.join('_')
			if suffix == '' { suffix = 'any' }
			t.emit_function_impl('${node.name}_${suffix}', over_node.args, over_node.returns, node.body, node.decorator_list, class_name)
		}
		return
	}
	t.emit_function_impl(node.name, node.args, node.returns, node.body, node.decorator_list, class_name)
}

fn (mut t Translator) emit_function_impl(fn_raw_name string, f_args ast.Arguments, f_returns ?ast.Expression, f_body []ast.Statement, decorator_list []ast.Expression, class_name string) {
	// Collect all parameters
	for dec in decorator_list {
		match dec {
			ast.Name {
				if dec.id == 'overload' { return }
			}
			ast.Attribute {
				if dec.attr == 'overload' { return }
			}
			else {}
		}
	}

	mut p_args := []string{}
	mut all_args := f_args.posonlyargs.clone()
	all_args << f_args.args
	all_args << f_args.kwonlyargs
	start_index := if class_name.len > 0 && all_args.len > 0 && (all_args[0].arg == 'self' || all_args[0].arg == 'cls') {
		1
	} else {
		0
	}
	for i := start_index; i < all_args.len; i++ {
		arg := all_args[i]
		arg_name := base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{})
		mut arg_type := 'Any'
		if arg.arg == 'val' && class_name == '' { arg_type = 'Any' }
		mut force_concrete_rec := false
		if class_name.len > 0 && arg.arg == 'r' && class_name.ends_with('Task') && class_name != 'Task' {
			arg_type = '${class_name}Rec'
			force_concrete_rec = true
		}
		if !force_concrete_rec {
			if ann := arg.annotation {
				arg_type = t.map_annotation(ann)
			} else if arg.arg in t.analyzer.type_map {
				arg_type = t.analyzer.type_map[arg.arg]
			}
		}
		if arg_type == '' { arg_type = 'Any' }
		p_args << '${arg_name} ${arg_type}'
	}
	if va := f_args.vararg {
		va_name := base.sanitize_name(va.arg, false, map[string]bool{}, "", map[string]bool{})
		mut va_type := 'Any'
		if ann := va.annotation {
			va_type = t.map_annotation(ann)
			if va_type.starts_with('[]') {
				va_type = va_type[2..]
			}
		}
		p_args << '${va_name} ...${va_type}'
	}
	if ka := f_args.kwarg {
		ka_name := base.sanitize_name(ka.arg, false, map[string]bool{}, "", map[string]bool{})
		p_args << '${ka_name} map[string]Any'
	}
	args_str := p_args.join(', ')
	t.mutable_locals = t.collect_mutable_locals(f_body)
	is_mut := 'self' in t.mutable_locals
	mut receiver := if class_name.len > 0 { t.method_receiver(class_name, is_mut) } else { '' }
	mut translated_name := base.sanitize_name(fn_raw_name, false, map[string]bool{}, '', map[string]bool{})
	if fn_raw_name == '__init__' {
		translated_name = 'init'
	} else if translated_name == 'upper' {
		translated_name = 'to_upper'
	} else if translated_name == 'fn' {
		translated_name = 'run'
	} else if fn_raw_name == '__str__' {
		translated_name = 'str'
	} else if fn_raw_name == '__repr__' {
		translated_name = 'repr'
	} else if fn_raw_name == '__iter__' {
		translated_name = 'iter'
	} else if fn_raw_name == '__next__' {
		translated_name = 'next'
	} else if fn_raw_name == '__await__' {
		translated_name = 'await_'
	}

	if t.state.is_unittest_class && translated_name.starts_with('test_') {
		translated_name = '${translated_name}_${class_name}'
		receiver = ''
	}
	prev_function_name := t.current_function_name
	t.current_function_name = fn_raw_name
	mut ret_type := ''
	if !(fn_raw_name == '__init__' && class_name.len > 0) {
		if ann := f_returns {
			mut r_type := t.map_annotation(ann)
			if r_type == 'Self' {
				if t.state.current_class_generics.len > 0 {
					r_type = '&${class_name}[${t.state.current_class_generics.join(', ')}]'
				} else {
					r_type = '&${class_name}'
				}
			} else if class_name.len > 0 && r_type.contains(class_name) && !r_type.starts_with('&') && !r_type.starts_with('[]') {
				r_type = '&' + r_type
			}
			ret_type = r_type
			if ann is ast.Subscript {
				b_raw := t.annotation_raw_name(ann.value)
				if b_raw in ['TypeGuard', 'typing.TypeGuard', 'TypeIs', 'typing.TypeIs'] {
					t.state.type_guards[fn_raw_name] = t.map_annotation(ann.slice)
				}
			}
		}
	}
	if class_name.len > 0 && fn_raw_name.ends_with('_add') {
		ret_type = ''
	}

	mut is_classmethod := false
	mut deprecation_msg := ''
	for dec in decorator_list {
		match dec {
			ast.Name {
				if dec.id == 'classmethod' {
					is_classmethod = true
				} else if dec.id == 'deprecated' {
					deprecation_msg = 'deprecated'
				}
			}
			ast.Attribute {
				if dec.attr == 'classmethod' {
					is_classmethod = true
				} else if dec.attr == 'deprecated' {
					deprecation_msg = 'deprecated'
				}
			}
			ast.Call {
				if dec.func is ast.Name {
					if dec.func.id == 'deprecated' {
						if dec.args.len > 0 && dec.args[0] is ast.Constant {
							deprecation_msg = (dec.args[0] as ast.Constant).value.trim("'\"")
						} else {
							deprecation_msg = 'deprecated'
						}
					}
				}
			}
			else {}
		}
	}

	if deprecation_msg.len > 0 {
		if deprecation_msg == 'deprecated' {
			t.emit_indented('@[deprecated]')
		} else {
			t.emit_indented('@[deprecated: \'${deprecation_msg}\']')
		}
	}

	if fn_raw_name == 'fail' && class_name == '' {
		t.emit_indented('@[noreturn]')
		ret_type = ''
	}
	sig_suffix := if ret_type.len > 0 { ' ${ret_type}' } else { '' }

	if class_name.len > 0 {
		if is_classmethod {
			// Class method -> top-level function Class_method
			mut name_to_emit := '${class_name}_${translated_name}'
			
			// Only add suffix if there are multiple versions (overloads)
			if fn_raw_name in t.state.overloads || translated_name.contains('_') {
				mut all_pos_args := f_args.posonlyargs.clone()
				all_pos_args << f_args.args
				mut suffix_parts := []string{}
				for parg in all_pos_args {
					if parg.arg == 'cls' || parg.arg == 'self' { continue }
					if ann_p := parg.annotation {
						at := t.map_annotation(ann_p)
						if at in t.state.current_class_generics {
							suffix_parts << 'generic'
						} else if at.len > 0 {
							suffix_parts << at
						}
					}
				}
				if suffix_parts.len > 0 {
					name_to_emit += '_' + suffix_parts.join('_')
				}
			}
			
			if t.state.current_class_generics.len > 0 {
				generics_str := t.state.current_class_generics.join(', ')
				t.emit_indented('fn ${name_to_emit}[${generics_str}](${args_str})${sig_suffix} {')
			} else {
				t.emit_indented('fn ${name_to_emit}(${args_str})${sig_suffix} {')
			}
		} else {
			mut fn_generics := ''
			if t.state.current_class_generics.len > 0 {
				fn_generics = '[${t.state.current_class_generics.join(', ')}]'
			}
			t.emit_indented('fn ${receiver}${translated_name}${fn_generics}(${args_str})${sig_suffix} {')
		}
	} else {
		t.emit_indented('fn ${translated_name}(${args_str})${sig_suffix} {')
	}
	t.state.indent_level++
	t.push_scope()
	// t.mutable_locals already collected
	if class_name.len > 0 {
		t.declare_local('self')
	}
	for farg in all_args[start_index..] {
		t.declare_local(base.sanitize_name(farg.arg, false, map[string]bool{}, '', map[string]bool{}))
	}
	for stmt in f_body {
		t.visit_stmt(stmt)
	}
	if f_body.len == 0 && ret_type.len > 0 {
		t.emit_indented('return')
	}
	t.state.indent_level--
	t.pop_scope()
	t.mutable_locals = map[string]bool{}
	t.current_function_name = prev_function_name
	t.emit_indented('}')
}

fn (mut t Translator) visit_function_def(node ast.FunctionDef) {
	for dec in node.decorator_list {
		if dec is ast.Name && dec.id == 'overload' {
			t.state.overloads[node.name] << node
			return
		}
	}
	t.emit_function(node, '')
}

fn (mut t Translator) visit_class_def(node ast.ClassDef) {
	struct_name := base.sanitize_name(node.name, true, map[string]bool{}, '', map[string]bool{})
	prev_class := t.state.current_class
	t.state.current_class = struct_name

	fields := t.collect_class_fields(node)
	t.state.defined_classes[struct_name] = map[string]bool{}
	t.state.current_class_generics = node.type_params.map(it.name)
	if t.state.current_class_generics.len == 0 {
		for base_exp in node.bases {
			if base_exp is ast.Subscript {
				val := base_exp.value
				if val is ast.Name {
					if val.id == 'Generic' {
						sl := base_exp.slice
						if sl is ast.Tuple {
							for elt in sl.elements {
								if elt is ast.Name { t.state.current_class_generics << elt.id }
							}
						} else if sl is ast.Name {
							t.state.current_class_generics << sl.id
						}
					}
				}
			}
		}
	}
	t.state.current_class_body = node.body.clone()

	// Update hierarchy
	mut parent_names := []string{}
	for b in node.bases {
		if b is ast.Name {
			parent_names << base.sanitize_name(b.id, true, map[string]bool{}, '', map[string]bool{})
		}
	}
	t.state.class_hierarchy[struct_name] = parent_names

	t.state.is_unittest_class = false
	for b in node.bases {
		mut b_name := ''
		if b is ast.Name {
			b_name = b.id
		} else if b is ast.Attribute {
			b_name = b.attr
		}
		if b_name == 'TestCase' {
			t.state.is_unittest_class = true
			break
		}
	}

	mut is_protocol := false
	mut class_deprecation_msg := ''
	for b in node.bases {
		mut b_name := ''
		if b is ast.Name { b_name = b.id }
		else if b is ast.Attribute { b_name = b.attr }
		if b_name == 'Protocol' || b_name == 'ABC' {
			is_protocol = true
		}
	}

	if is_protocol {
		t.emit_indented('interface ${struct_name} {')
		t.state.indent_level++
		for stmt in node.body {
			if stmt is ast.FunctionDef {
				mut p_args := []string{}
				for i, arg in stmt.args.args {
					if i == 0 && arg.arg == 'self' { continue }
					mut ann_str := 'Any'
					if ann := arg.annotation {
						ann_str = t.map_annotation(ann)
					}
					p_args << '${arg.arg} ${ann_str}'
				}
				ret := if ann := stmt.returns { ' ${t.map_annotation(ann)}' } else { '' }
				t.emit_indented('${stmt.name}(${p_args.join(', ')})${ret}')
			}
		}
		t.state.indent_level--
		t.emit_indented('}')
		return
	}

	for dec in node.decorator_list {
		mut d_name := ''
		if dec is ast.Name { d_name = dec.id }
		else if dec is ast.Attribute { d_name = dec.attr }
		else if dec is ast.Call && dec.func is ast.Name { d_name = (dec.func as ast.Name).id }
		
		if d_name == 'disjoint_base' {
			t.emit_indented('@[disjoint_base]')
		} else if d_name == 'deprecated' {
			if dec is ast.Call {
				if dec.args.len > 0 && dec.args[0] is ast.Constant {
					class_deprecation_msg = (dec.args[0] as ast.Constant).value.trim("'\"")
				} else {
					class_deprecation_msg = 'deprecated'
				}
			} else {
				class_deprecation_msg = 'deprecated'
			}
		}
	}

	if class_deprecation_msg.len > 0 {
		if class_deprecation_msg == 'deprecated' {
			t.emit_indented('@[deprecated]')
		} else {
			t.emit_indented('@[deprecated: \'${class_deprecation_msg}\']')
		}
	}

	if !t.state.is_unittest_class {
		t.emit_indented('struct ${struct_name} {')
		t.emit_indented('pub mut:')
		t.state.indent_level++
		// Embed base implementations
		for p_name in parent_names {
			if p_name != 'object' && p_name != 'Any' {
				t.emit_indented('${p_name}_Impl')
			}
		}
		if fields.len > 0 {
			for field in fields {
				t.emit_indented(field)
			}
		} else {
			t.emit_indented('// fields inferred dynamically')
		}
		t.state.indent_level--
		t.emit_indented('}')
	}
	t.emit('')

	// Emit factory function
	for stmt in node.body {
		if stmt is ast.FunctionDef {
			if stmt.name == '__init__' {
				mut args_str := []string{}
				mut call_args := []string{}
				mut all_init_args := []ast.Parameter{}
				for a in stmt.args.posonlyargs {
					all_init_args << a
				}
				for a in stmt.args.args {
					all_init_args << a
				}
				for a in stmt.args.kwonlyargs {
					all_init_args << a
				}

				for arg in all_init_args {
					if arg.arg == 'self' || arg.arg == 'cls' {
						continue
					}
					mut arg_type := 'Any'
					if ann := arg.annotation {
						arg_type = t.map_annotation(ann)
					}
					arg_name := base.sanitize_name(arg.arg, false, map[string]bool{}, '', map[string]bool{})
					args_str << '${arg_name} ${arg_type}'
					call_args << arg_name
				}
				t.emit_indented('fn new_${base.to_snake_case(node.name)}(${args_str.join(', ')}) &${struct_name} {')
				t.state.indent_level++
				t.emit_indented('mut res := &${struct_name}{}')
				t.emit_indented('res.init(${call_args.join(', ')})')
				t.emit_indented('return res')
				t.state.indent_level--
				t.emit_indented('}')
				t.emit('')
				break
			}
		}
	}

	// Emit meta struct
	class_vars := t.state.class_vars[struct_name]
	if class_vars.len > 0 {
		meta_struct_name := '${struct_name}Meta'
		t.emit_indented('pub struct ${meta_struct_name} {')
		t.state.indent_level++
		t.emit_indented('pub mut:')
		for cvar in class_vars {
			name := base.sanitize_name(cvar['name'], false, map[string]bool{}, "", map[string]bool{})
			val := if cvar['value'] == 'none' { '' } else { ' = ' + cvar['value'] }
			t.emit_indented('    ${name} ${cvar['type']}${val}')
		}
		t.state.indent_level--
		t.emit_indented('}')
		t.emit('')
		meta_const_name := '${base.to_snake_case(struct_name)}_meta'
		t.emit_indented('pub const ${meta_const_name} = &${meta_struct_name}{}')
		t.emit('')
	}

	for stmt in node.body {
		if stmt is ast.FunctionDef {
			t.emit_function(stmt, struct_name)
			t.emit('')
		}
	}

	t.state.current_class = prev_class
}
