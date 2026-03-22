// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 04:45
module mypy

// Семантический анализ определений NewType.
// Например: UserId = NewType('UserId', int)

pub struct NewTypeAnalyzer {
pub mut:
	options &Options
	api     &SemanticAnalyzerInterface
}

pub fn (mut a NewTypeAnalyzer) process_newtype_declaration(s &AssignmentStmt) bool {
	name, call := a.analyze_newtype_declaration(s)
	if name == '' || call == none {
		return false
	}

	mut nt_name := name
	if a.api.is_func_scope() {
		nt_name += '@' + s.base.ctx.line.str()
	}

	mut c := call or { return false }
	old_type_raw, should_defer := a.check_newtype_args(name, c, s.get_context())

	if should_defer {
		a.api.defer(s.get_context(), false)
		return true
	}

	mut actual_old_type := old_type_raw or { MypyTypeNode(AnyType{
		type_of_any: .from_error
	}) }

	// Build TypeInfo
	mut base_type := a.api.named_type('builtins.object', [])
	if actual_old_type is Instance {
		base_type = actual_old_type
	} else if actual_old_type is TupleType {
		base_type = actual_old_type.partial_fallback
	}

	info := a.build_newtype_typeinfo(nt_name, actual_old_type, base_type, s.base.ctx.line,
		none)

	a.api.add_symbol(name, SymbolNodeRef(info), s, true, false, true)
	if a.api.is_func_scope() {
		a.api.add_symbol_skip_local(nt_name, SymbolNodeRef(info))
	}

	return true
}

pub fn (mut a NewTypeAnalyzer) analyze_newtype_declaration(s &AssignmentStmt) (string, ?&CallExpr) {
	if s.lvalues.len == 1 && s.lvalues[0] is NameExpr {
		r := s.rvalue
		if r is CallExpr {
			callee := r.callee
			if callee is NameExpr {
				if callee.fullname in ['typing.NewType', 'typing_extensions.NewType'] {
					return (s.lvalues[0] as NameExpr).name, r
				}
			}
		}
	}
	return '', none
}

pub fn (mut a NewTypeAnalyzer) check_newtype_args(name string, call &CallExpr, ctx Context) (?MypyTypeNode, bool) {
	args := call.args
	if args.len != 2 {
		a.fail('NewType(...) expects exactly two positional arguments', ctx)
		return none, false
	}

	// Check name
	arg0 := args[0]
	if arg0 is StrExpr {
		if arg0.value != name {
			a.fail('String argument 1 "${arg0.value}" to NewType(...) does not match variable name "${name}"',
				ctx)
		}
	} else {
		a.fail('Argument 1 to NewType(...) must be a string literal', ctx)
	}

	// Check base type
	// arg1 := args[1]

	mut old_type := a.api.anal_type(MypyTypeNode(AnyType{ type_of_any: .unannotated }),
		none, false, false, true, false, true, none, none)

	if old_type == none {
		return none, true // should defer
	}

	return old_type, false
}

pub fn (mut a NewTypeAnalyzer) build_newtype_typeinfo(name string, old_type MypyTypeNode, base_type &Instance, line int, existing_info ?&TypeInfo) &TypeInfo {
	info := or_existing_info(existing_info, a.api.basic_new_typeinfo(name, base_type,
		line))
	mut mut_info := unsafe { &TypeInfo(info) }
	mut_info.is_newtype = true

	// Add __init__(self, item: old_type)
	mut init_args := [
		Argument{
			variable: &Var{
				name:  'self'
				type_: MypyTypeNode(NoneType{})
			}
			kind:     .arg_pos
		},
		Argument{
			variable: &Var{
				name:  'item'
				type_: old_type
			}
			kind:     .arg_pos
		},
	]

	mut signature := &CallableType{
		base:      TypeBase{
			ctx: Context{
				line: line
			}
		}
		arg_types: [MypyTypeNode(Instance{
			typ: info
		}), old_type]
		arg_kinds: [.arg_pos, .arg_pos]
		arg_names: ['self', 'item']
		ret_type:  MypyTypeNode(NoneType{})
		fallback:  a.api.named_type('builtins.function', [])
		name:      name
	}

	mut init_func := &FuncDef{
		name:      '__init__'
		arguments: init_args
		body:      Block{}
		type_:     MypyTypeNode(signature)
	}
	init_func.info = info
	init_func.fullname = '${info.fullname}.__init__'

	mut_info.names.symbols['__init__'] = SymbolTableNode{
		kind: .mdef
		node: SymbolNodeRef(init_func)
	}

	return info
}

pub fn (mut a NewTypeAnalyzer) fail(msg string, ctx Context) {
	a.api.fail(msg, ctx, false, false, none)
}
