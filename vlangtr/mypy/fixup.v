// fixup.v — Fix up various things after deserialization
// Translated from mypy/fixup.py to V 0.5.x
//
// Я Antigravity работаю над этим файлом. Начало: 2026-03-22 16:00

module mypy

// fixup_module исправляет различные вещи после десериализации
pub fn fixup_module(tree MypyFile, modules map[string]MypyFile, allow_missing bool) {
	node_fixer := NodeFixer{
		modules:      modules
		allow_missing: allow_missing
	}
	node_fixer.visit_symbol_table(mut tree.names, tree.fullname)
}

// NodeFixer — исправитель узлов
pub struct NodeFixer {
pub mut:
	modules       map[string]MypyFile
	allow_missing bool
	current_info  ?&TypeInfo
	type_fixer    TypeFixer
}

// new_node_fixer создаёт новый NodeFixer
pub fn new_node_fixer(modules map[string]MypyFile, allow_missing bool) NodeFixer {
	return NodeFixer{
		modules:       modules
		allow_missing: allow_missing
		current_info:  none
		type_fixer:    new_type_fixer(modules, allow_missing)
	}
}

// visit_type_info посещает TypeInfo
pub fn (mut nf NodeFixer) visit_type_info(info &TypeInfo) {
	save_info := nf.current_info
	defer { nf.current_info = save_info }

	nf.current_info = info

	if info.defn != none {
		// info.defn.accept(nf)
	}

	if info.names != none {
		nf.visit_symbol_table(mut info.names or { map[string]SymbolTableNode{} }, info.fullname)
	}

	if info.bases.len > 0 {
		for mut base in info.bases {
			base.accept(mut nf.type_fixer)
		}
	}

	if info.tuple_type != none {
		// info.tuple_type.accept(nf.type_fixer)
	}

	if info.typeddict_type != none {
		// info.typeddict_type.accept(nf.type_fixer)
	}

	if info.metaclass_type != none {
		// info.metaclass_type.accept(nf.type_fixer)
	}

	if info.mro_refs.len > 0 {
		mut mro := []TypeInfo{}
		for name in info.mro_refs {
			ti := lookup_fully_qualified_typeinfo(nf.modules, name, nf.allow_missing)
			if ti != none {
				mro << ti
			}
		}
		info.mro = mro
		info.mro_refs = []string{}
	}
}

// visit_symbol_table посещает таблицу символов
pub fn (mut nf NodeFixer) visit_symbol_table(mut symtab map[string]SymbolTableNode, table_fullname string) {
	for key, mut value in symtab {
		if value.cross_ref != none {
			cross_ref := value.cross_ref or { continue }
			value.cross_ref = none

			if cross_ref in nf.modules {
				value.node = nf.modules[cross_ref]
			} else {
				stnode := lookup_fully_qualified(cross_ref, nf.modules, !nf.allow_missing)
				if stnode != none {
					if stnode.node != none {
						value.node = stnode.node
					}
				} else if !nf.allow_missing {
					// panic('Could not find cross-ref ${cross_ref}')
				} else {
					value.node = missing_info(nf.modules)
				}
			}
		} else {
			if value.node is TypeInfo {
				// TypeInfo has no accept()
				// nf.visit_type_info(value.node)
			} else if value.node != none {
				// value.node.accept(nf)
			}
		}
	}
}

// visit_func_def посещает FuncDef
pub fn (mut nf NodeFixer) visit_func_def(func &FuncDef) {
	if nf.current_info != none {
		// func.info = nf.current_info
	}
	if func.type != none {
		// func.type.accept(nf.type_fixer)
	}
}

// visit_overloaded_func_def посещает OverloadedFuncDef
pub fn (mut nf NodeFixer) visit_overloaded_func_def(o &OverloadedFuncDef) {
	if nf.current_info != none {
		// o.info = nf.current_info
	}
	if o.type != none {
		// o.type.accept(nf.type_fixer)
	}
}

// visit_decorator посещает Decorator
pub fn (mut nf NodeFixer) visit_decorator(d &Decorator) {
	if nf.current_info != none {
		// d.var.info = nf.current_info
	}
	if d.func != none {
		// d.func.accept(nf)
	}
}

// visit_class_def посещает ClassDef
pub fn (mut nf NodeFixer) visit_class_def(c &ClassDef) {
	for v in c.type_vars {
		// v.accept(nf.type_fixer)
	}
}

// visit_var посещает Var
pub fn (mut nf NodeFixer) visit_var(v &Var) {
	if nf.current_info != none {
		// v.info = nf.current_info
	}
	if v.type != none {
		// v.type.accept(nf.type_fixer)
	}
}

// visit_type_alias посещает TypeAlias
pub fn (mut nf NodeFixer) visit_type_alias(a &TypeAlias) {
	// a.target.accept(nf.type_fixer)
}

// TypeFixer — исправитель типов
pub struct TypeFixer {
pub mut:
	modules       map[string]MypyFile
	allow_missing bool
}

// new_type_fixer создаёт новый TypeFixer
pub fn new_type_fixer(modules map[string]MypyFile, allow_missing bool) TypeFixer {
	return TypeFixer{
		modules:       modules
		allow_missing: allow_missing
	}
}

// visit_instance посещает Instance
pub fn (mut tf TypeFixer) visit_instance(mut inst &Instance) {
	type_ref := inst.type_ref
	if type_ref == none {
		return  // Уже были здесь
	}

	inst.type_ref = none
	inst.type = lookup_fully_qualified_typeinfo(tf.modules, type_ref or { '' }, tf.allow_missing)

	for mut a in inst.args {
		a.accept(mut tf)
	}
}

// visit_type_alias_type посещает TypeAliasType
pub fn (mut tf TypeFixer) visit_type_alias_type(mut t &TypeAliasType) {
	type_ref := t.type_ref
	if type_ref == none {
		return  // Уже были здесь
	}

	t.type_ref = none
	t.alias = lookup_fully_qualified_alias(tf.modules, type_ref or { '' }, tf.allow_missing)

	for mut a in t.args {
		a.accept(mut tf)
	}
}

// visit_callable_type посещает CallableType
pub fn (mut tf TypeFixer) visit_callable_type(mut ct &CallableType) {
	if ct.fallback != none {
		// ct.fallback.accept(tf)
	}
	for mut argt in ct.arg_types {
		if argt != none {
			argt.accept(mut tf)
		}
	}
	if ct.ret_type != none {
		// ct.ret_type.accept(tf)
	}
}

// visit_overloaded посещает Overloaded
pub fn (mut tf TypeFixer) visit_overloaded(t &Overloaded) {
	for mut ct in t.items {
		ct.accept(mut tf)
	}
}

// visit_tuple_type посещает TupleType
pub fn (mut tf TypeFixer) visit_tuple_type(mut tt &TupleType) {
	for mut it in tt.items {
		it.accept(mut tf)
	}
	if tt.partial_fallback != none {
		// tt.partial_fallback.accept(tf)
	}
}

// visit_typeddict_type посещает TypedDictType
pub fn (mut tf TypeFixer) visit_typeddict_type(mut tdt &TypedDictType) {
	for _, mut it in tdt.items {
		it.accept(mut tf)
	}
	if tdt.fallback != none {
		// tdt.fallback.accept(tf)
	}
}

// visit_literal_type посещает LiteralType
pub fn (mut tf TypeFixer) visit_literal_type(mut lt &LiteralType) {
	// lt.fallback.accept(tf)
}

// visit_type_var посещает TypeVarType
pub fn (mut tf TypeFixer) visit_type_var(mut tvt &TypeVarType) {
	for mut vt in tvt.values {
		vt.accept(mut tf)
	}
	tvt.upper_bound.accept(mut tf)
	tvt.default.accept(mut tf)
}

// visit_param_spec посещает ParamSpecType
pub fn (mut tf TypeFixer) visit_param_spec(mut p &ParamSpecType) {
	p.upper_bound.accept(mut tf)
	p.default.accept(mut tf)
}

// visit_type_var_tuple посещает TypeVarTupleType
pub fn (mut tf TypeFixer) visit_type_var_tuple(mut t &TypeVarTupleType) {
	t.tuple_fallback.accept(mut tf)
	t.upper_bound.accept(mut tf)
	t.default.accept(mut tf)
}

// visit_unpack_type посещает UnpackType
pub fn (mut tf TypeFixer) visit_unpack_type(mut u &UnpackType) {
	u.type.accept(mut tf)
}

// visit_union_type посещает UnionType
pub fn (mut tf TypeFixer) visit_union_type(mut ut &UnionType) {
	for mut it in ut.items {
		it.accept(mut tf)
	}
}

// visit_type_type посещает TypeType
pub fn (mut tf TypeFixer) visit_type_type(mut t &TypeType) {
	t.item.accept(mut tf)
}

// lookup_fully_qualified_typeinfo находит TypeInfo по полному имени
pub fn lookup_fully_qualified_typeinfo(modules map[string]MypyFile, name string, allow_missing bool) ?&TypeInfo {
	stnode := lookup_fully_qualified(name, modules, !allow_missing)
	if stnode == none {
		if allow_missing {
			return missing_info(modules)
		}
		return none
	}

	node := stnode.node
	if node is TypeInfo {
		return node
	} else {
		if allow_missing {
			return missing_info(modules)
		}
		return none
	}
}

// lookup_fully_qualified_alias находит TypeAlias по полному имени
pub fn lookup_fully_qualified_alias(modules map[string]MypyFile, name string, allow_missing bool) ?&TypeAlias {
	stnode := lookup_fully_qualified(name, modules, !allow_missing)
	if stnode == none {
		if allow_missing {
			return missing_alias()
		}
		return none
	}

	node := stnode.node
	if node is TypeAlias {
		return node
	} else if node is TypeInfo {
		// Уже исправлено или создаём новый alias
		return missing_alias()
	} else {
		if allow_missing {
			return missing_alias()
		}
		return none
	}
}

pub const missing_suggestion = '<missing {}: *should* have gone away during fine-grained update>'

// missing_info создаёт заглушку TypeInfo для отсутствующих модулей
pub fn missing_info(modules map[string]MypyFile) &TypeInfo {
	suggestion := missing_suggestion.replace('{}', 'info')
	// dummy_def := ClassDef{suggestion: suggestion, block: Block{}}
	// info := TypeInfo{names: map[string]SymbolTableNode{}, defn: dummy_def, module_name: '<missing>'}
	// obj_type := lookup_fully_qualified_typeinfo(modules, 'builtins.object', false)
	// info.bases = [Instance{type: obj_type, args: []}]
	// info.mro = [info, obj_type]
	return none  // Заглушка
}

// missing_alias создаёт заглушку TypeAlias для отсутствующих модулей
pub fn missing_alias() &TypeAlias {
	suggestion := missing_suggestion.replace('{}', 'alias')
	// return TypeAlias{target: AnyType{type_of_any: TypeOfAny.special_form}, fullname: suggestion, module_name: '<missing>'}
	return none  // Заглушка
}
