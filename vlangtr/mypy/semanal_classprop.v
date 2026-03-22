// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 05:00
module mypy

// Вычисление свойств классов (абстрактность, протоколы, ClassVar).
// Происходит после семантического анализа, но до проверки типов.

pub const type_promotions = {
	'builtins.int':        'float'
	'builtins.float':      'complex'
	'builtins.bytearray':  'bytes'
	'builtins.memoryview': 'bytes'
}

pub fn calculate_class_abstract_status(typ &TypeInfo, is_stub_file bool, mut errors Errors) {
	mut mutable_typ := unsafe { &TypeInfo(typ) }
	mutable_typ.is_abstract = false
	mutable_typ.abstract_attributes = []

	if typ.typeddict_type != none {
		return
	}

	if typ.is_newtype {
		return
	}

	mut concrete := map[string]bool{}
	mut abstract := []string{}
	mut abstract_in_this_class := []string{}

	for base in typ.mro {
		for name, symnode in base.names.symbols {
			node := symnode.node or { continue }
			mut working_node := node

			if working_node is OverloadedFuncDef {
				if working_node.items.len > 0 {
					working_node = SymbolNodeRef(working_node.items[0])
				} else {
					continue
				}
			}

			if working_node is Decorator {
				working_node = SymbolNodeRef(working_node.func)
			}

			if working_node is FuncDef {
				if working_node.abstract_status in [1, 2] && name !in concrete {
					mutable_typ.is_abstract = true
					if name !in abstract {
						abstract << name
					}
					if base.fullname == typ.fullname {
						if name !in abstract_in_this_class {
							abstract_in_this_class << name
						}
					}
				}
			} else if working_node is Var {
				if working_node.is_abstract_var && name !in concrete {
					mutable_typ.is_abstract = true
					if name !in abstract {
						abstract << name
					}
					if base.fullname == typ.fullname {
						if name !in abstract_in_this_class {
							abstract_in_this_class << name
						}
					}
				}
			}
			concrete[name] = true
		}
	}

	// Сортировка и установка
	mut sorted_abstract := abstract.clone()
	sorted_abstract.sort()
	mutable_typ.abstract_attributes = sorted_abstract

	if is_stub_file {
		if m := typ.declared_metaclass {
			if m.typ != none && m.typ.fullname == 'abc.ABCMeta' {
				return
			}
		}
		if typ.is_protocol {
			return
		}
		if abstract.len > 0 && abstract_in_this_class.len == 0 {
			attrs := sorted_abstract.map('"${it}"').join(', ')
			errors.report(typ.base.ctx.line, typ.base.ctx.column, 'Class ${typ.fullname} has abstract attributes ${attrs}',
				.error, none)
			errors.report(typ.base.ctx.line, typ.base.ctx.column, "If it is meant to be abstract, add 'abc.ABCMeta' as an explicit metaclass",
				.note, none)
		}
	}

	if typ.is_final && abstract.len > 0 {
		attrs := sorted_abstract.map('"${it}"').join(', ')
		errors.report(typ.base.ctx.line, typ.base.ctx.column, 'Final class ${typ.fullname} has abstract attributes ${attrs}',
			.error, none)
	}
}

pub fn check_protocol_status(info &TypeInfo, mut errors Errors) {
	if info.is_protocol {
		for base_type in info.bases {
			if base_type.typ != none {
				if !base_type.typ.is_protocol && base_type.typ.fullname != 'builtins.object' {
					errors.report(info.base.ctx.line, info.base.ctx.column, 'All bases of a protocol must be protocols',
						.error, none)
				}
			}
		}
	}
}

pub fn calculate_class_vars(info &TypeInfo) {
	for name, sym in info.names.symbols {
		node := sym.node or { continue }
		if node is Var && node.is_inferred && !node.is_classvar {
			for base in info.mro[1..] {
				member := base.names.symbols[name] or { continue }
				if member_node := member.node {
					if member_node is Var && member_node.is_classvar {
						unsafe {
							mut mut_node := &Var(node)
							mut_node.is_classvar = true
						}
					}
				}
			}
		}
	}
}

pub fn add_type_promotion(info &TypeInfo, module_names map[string]&SymbolTableNode, options &Options) {
	// Установка ad-hoc связей подтипов (например, int -> float)
	mut mut_info := unsafe { &TypeInfo(info) }

	if info.fullname in type_promotions {
		target_name := type_promotions[info.fullname]
		if target_sym := module_names[target_name] {
			if target_info := target_sym.node {
				if target_info is TypeInfo {
					mut_info.bases << Instance{
						typ: target_info
					}
				}
			}
		}
	}
}
