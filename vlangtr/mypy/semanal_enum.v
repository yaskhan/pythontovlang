// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 04:00
module mypy

// Семантический анализ вызовов Enum (функциональный стиль определения Enum).
// Например: A = enum.Enum('A', 'foo bar')

pub const enum_bases = ['enum.Enum', 'enum.IntEnum', 'enum.Flag', 'enum.IntFlag', 'enum.StrEnum']

// Свойства, которые всегда есть у Enum и не считаются его элементами.
pub const enum_special_props = [
	'name', 'value', '_name_', '_value_',
	'__module__', '__annotations__', '__doc__', '__slots__', '__dict__'
]

pub struct EnumCallAnalyzer {
pub mut:
	options &Options
	api     SemanticAnalyzerInterface
}

pub fn (mut a EnumCallAnalyzer) process_enum_call(s &AssignmentStmt, is_func_scope bool) bool {
	if s.lvalues.len != 1 { return false }
	lvalue := s.lvalues[0]
	
	mut name := ''
	if lvalue is NameExpr {
		name = lvalue.name
	} else if lvalue is MemberExpr {
		name = lvalue.name
	} else {
		return false
	}

	info := a.check_enum_call(s.rvalue, name, is_func_scope) or { return false }
	
	if lvalue is MemberExpr {
		a.fail('Enum type as attribute is not supported', lvalue)
		return false
	}
	
	// Добавляем в таблицу символов
	a.api.add_symbol(name, info, s, true, false, true)
	return true
}

pub fn (mut a EnumCallAnalyzer) check_enum_call(node Expression, var_name string, is_func_scope bool) ?&TypeInfo {
	if node !is CallExpr { return none }
	call := node as CallExpr
	
	callee := call.callee
	if callee !is RefExpr { return none }
	
	fullname := callee.fullname
	if fullname !in enum_bases { return none }

	new_class_name, items, values, ok := a.parse_enum_call_args(call, fullname.split('.').last())
	
	mut info := &TypeInfo(0)
	if !ok {
		mut name := var_name
		if is_func_scope {
			name += '@' + call.line.str()
		}
		info = a.build_enum_call_typeinfo(name, [], fullname, node.line)
	} else {
		if new_class_name != var_name {
			msg := 'String argument 1 "${new_class_name}" to ${fullname}(...) does not match variable name "${var_name}"'
			a.fail(msg, call)
		}
		
		arg0 := call.args[0]
		mut name := var_name
		if arg0 is StrExpr {
			name = arg0.value
		}
		
		if name != var_name || is_func_scope {
			name += '@' + call.line.str()
		}
		info = a.build_enum_call_typeinfo(name, items, fullname, call.line)
	}
	
	if info.name != var_name || is_func_scope {
		a.api.add_symbol_skip_local(info.name, info)
	}
	
	// В Python: call.analyzed = EnumCallExpr(...)
	// В V: нужно предусмотреть соответствующее поле в CallExpr или использовать механизм analyzed
	
	return info
}

pub fn (mut a EnumCallAnalyzer) build_enum_call_typeinfo(name string, items []string, fullname string, line int) &TypeInfo {
	base := a.api.named_type_or_none(fullname, []) or {
		// fallback to object if not found
		a.api.named_type('builtins.object', [])
	}
	info := a.api.basic_new_typeinfo(name, base, line)
	// info.metaclass_type = info.calculate_metaclass_type()
	info.is_enum = true
	
	for item in items {
		mut v := &Var{
			name: item
			info: info
			is_property: true
			has_explicit_value: true
		}
		v.fullname = '${info.fullname}.${item}'
		info.names[item] = &SymbolTableNode{
			kind: .mdef
			node: v
		}
	}
	return info
}

pub fn (mut a EnumCallAnalyzer) parse_enum_call_args(call &CallExpr, class_name string) (string, []string, []?Expression, bool) {
	args := call.args
	// kinds := call.arg_kinds
	
	if args.len < 2 {
		return a.fail_enum_call_arg('Too few arguments for ${class_name}()', call)
	}
	
	arg0 := args[0]
	if arg0 !is StrExpr {
		return a.fail_enum_call_arg('${class_name}() expects a string literal as the first argument', call)
	}
	new_class_name := (arg0 as StrExpr).value
	
	mut items := []string{}
	mut values := []?Expression{}
	
	names_arg := args[1]
	if names_arg is StrExpr {
		fields := names_arg.value
		for field in fields.replace(',', ' ').split(' ') {
			if field != '' {
				items << field
			}
		}
	} else if names_arg is ListExpr {
		for item in names_arg.items {
			if item is StrExpr {
				items << item.value
			}
		}
	} else if names_arg is DictExpr {
		for i, key in names_arg.keys {
			if key is StrExpr {
				items << key.value
				values << names_arg.values[i]
			}
		}
	}
	
	if items.len == 0 {
		return a.fail_enum_call_arg('${class_name}() needs at least one item', call)
	}
	
	if values.len == 0 {
		// Fill with none
		for _ in 0..items.len {
			values << none
		}
	}
	
	return new_class_name, items, values, true
}

pub fn (mut a EnumCallAnalyzer) fail_enum_call_arg(msg string, ctx Context) (string, []string, []?Expression, bool) {
	a.fail(msg, ctx)
	return '', [], [], false
}

pub fn (mut a EnumCallAnalyzer) fail(msg string, ctx Context) {
	a.api.fail(msg, ctx, false, false, none)
}
