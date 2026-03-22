// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:10
// exportjson.v — Convert binary mypy cache files (.ff) to JSON
// Переведён из mypy/exportjson.py

module mypy

import json
import os

// Config — конфигурация для конвертации
pub struct Config {
pub:
	implicit_names bool
}

// new_config создаёт новый Config
pub fn new_config(implicit_names bool) Config {
	return Config{
		implicit_names: implicit_names
	}
}

// Json — тип для JSON значений
pub type Json = map[string]Any | string

// convert_binary_cache_to_json конвертирует бинарный кэш в JSON
pub fn convert_binary_cache_to_json(data []u8, implicit_names bool) Json {
	tree := mypy_file_read(data)
	return convert_mypy_file_to_json(tree, new_config(implicit_names))
}

// convert_mypy_file_to_json конвертирует MypyFile в JSON
pub fn convert_mypy_file_to_json(self MypyFile, cfg Config) Json {
	return {
		'.class':                  Any('MypyFile')
		'_fullname':               Any(self._fullname)
		'names':                   Any(convert_symbol_table(self.names, cfg))
		'is_stub':                 Any(self.is_stub)
		'path':                    Any(self.path)
		'is_partial_stub_package': Any(self.is_partial_stub_package)
		'future_import_flags':     Any(self.future_import_flags.sorted())
	}
}

// convert_symbol_table конвертирует SymbolTable в JSON
pub fn convert_symbol_table(self SymbolTable, cfg Config) Json {
	mut data := map[string]Any{}
	data['.class'] = Any('SymbolTable')
	for key, value in self.items() {
		if key == '__builtins__' || value.no_serialize {
			continue
		}
		if !cfg.implicit_names && key in ['__spec__', '__package__', '__file__', '__doc__', '__annotations__', '__name__'] {
			continue
		}
		data[key] = Any(convert_symbol_table_node(value, cfg))
	}
	return data
}

// convert_symbol_table_node конвертирует SymbolTableNode в JSON
pub fn convert_symbol_table_node(self SymbolTableNode, cfg Config) Json {
	mut data := map[string]Any{}
	data['.class'] = Any('SymbolTableNode')
	data['kind'] = Any(node_kinds[self.kind])
	if self.module_hidden {
		data['module_hidden'] = Any(true)
	}
	if !self.module_public {
		data['module_public'] = Any(false)
	}
	if self.implicit {
		data['implicit'] = Any(true)
	}
	if self.plugin_generated {
		data['plugin_generated'] = Any(true)
	}
	if self.cross_ref.len > 0 {
		data['cross_ref'] = Any(self.cross_ref)
	} else if self.node != none {
		data['node'] = Any(convert_symbol_node(self.node, cfg))
	}
	return data
}

// convert_symbol_node конвертирует SymbolNode в JSON
pub fn convert_symbol_node(self SymbolNode, cfg Config) Json {
	if self is FuncDefNode {
		return convert_func_def(self)
	} else if self is OverloadedFuncDefNode {
		return convert_overloaded_func_def(self)
	} else if self is DecoratorNode {
		return convert_decorator(self)
	} else if self is VarNode {
		return convert_var(self)
	} else if self is TypeInfoNode {
		return convert_type_info(self, cfg)
	} else if self is TypeAliasNode {
		return convert_type_alias(self)
	} else if self is TypeVarExprNode {
		return convert_type_var_expr(self)
	} else if self is ParamSpecExprNode {
		return convert_param_spec_expr(self)
	} else if self is TypeVarTupleExprNode {
		return convert_type_var_tuple_expr(self)
	}
	return {'ERROR': Any('${typeof(self)} unrecognized')}
}

// convert_func_def конвертирует FuncDef в JSON
pub fn convert_func_def(self FuncDefNode) Json {
	return {
		'.class':                    Any('FuncDef')
		'name':                      Any(self._name)
		'fullname':                  Any(self._fullname)
		'arg_names':                 Any(self.arg_names)
		'arg_kinds':                 Any(self.arg_kinds.map(int(it)))
		'type':                      Any(if self.typ == none { none } else { convert_type(self.typ) })
		'flags':                     Any(get_flags(self, funcdef_flags))
		'abstract_status':           Any(self.abstract_status)
		'deprecated':                Any(self.deprecated)
		'original_first_arg':        Any(self.original_first_arg)
	}
}

// convert_overloaded_func_def конвертирует OverloadedFuncDef в JSON
pub fn convert_overloaded_func_def(self OverloadedFuncDefNode) Json {
	return {
		'.class':     Any('OverloadedFuncDef')
		'items':      Any(self.items.map(convert_overload_part(it)))
		'type':       Any(if self.typ == none { none } else { convert_type(self.typ) })
		'fullname':   Any(self._fullname)
		'impl':       Any(if self.impl == none { none } else { convert_overload_part(self.impl) })
		'flags':      Any(get_flags(self, funcbase_flags))
		'deprecated': Any(self.deprecated)
	}
}

// convert_overload_part конвертирует OverloadPart в JSON
pub fn convert_overload_part(self OverloadPart) Json {
	if self is FuncDefNode {
		return convert_func_def(self)
	}
	return convert_decorator(self as DecoratorNode)
}

// convert_decorator конвертирует Decorator в JSON
pub fn convert_decorator(self DecoratorNode) Json {
	return {
		'.class':      Any('Decorator')
		'func':        Any(convert_func_def(self.func))
		'var':         Any(convert_var(self.var))
		'is_overload': Any(self.is_overload)
	}
}

// convert_var конвертирует Var в JSON
pub fn convert_var(self VarNode) Json {
	mut data := map[string]Any{}
	data['.class'] = Any('Var')
	data['name'] = Any(self._name)
	data['fullname'] = Any(self._fullname)
	data['type'] = Any(if self.typ == none { none } else { convert_type(self.typ) })
	data['setter_type'] = Any(if self.setter_type == none { none } else { convert_type(self.setter_type) })
	data['flags'] = Any(get_flags(self, var_flags))
	if self.final_value != none {
		data['final_value'] = Any(self.final_value)
	}
	return data
}

// convert_type_info конвертирует TypeInfo в JSON
pub fn convert_type_info(self TypeInfoNode, cfg Config) Json {
	return {
		'.class':                    Any('TypeInfo')
		'module_name':               Any(self.module_name)
		'fullname':                  Any(self.fullname)
		'names':                     Any(convert_symbol_table(self.names, cfg))
		'defn':                      Any(convert_class_def(self.defn))
		'abstract_attributes':       Any(self.abstract_attributes)
		'type_vars':                 Any(self.type_vars)
		'bases':                     Any(self.bases.map(convert_type(it)))
		'mro':                       Any(self._mro_refs)
		'_promote':                  Any(self._promote.map(convert_type(it)))
		'tuple_type':                Any(if self.tuple_type == none { none } else { convert_type(self.tuple_type) })
		'typeddict_type':            Any(if self.typeddict_type == none { none } else { convert_typeddict_type(self.typeddict_type) })
		'flags':                     Any(get_flags(self, TypeInfoNode.flags))
		'metadata':                  Any(self.metadata)
		'slots':                     Any(if self.slots == none { none } else { self.slots.sorted() })
		'deprecated':                Any(self.deprecated)
	}
}

// convert_class_def конвертирует ClassDef в JSON
pub fn convert_class_def(self ClassDefNode) Json {
	return {
		'.class':    Any('ClassDef')
		'name':      Any(self.name)
		'fullname':  Any(self.fullname)
		'type_vars': Any(self.type_vars.map(convert_type(it)))
	}
}

// convert_type_alias конвертирует TypeAlias в JSON
pub fn convert_type_alias(self TypeAliasNode) Json {
	return {
		'.class':                  Any('TypeAlias')
		'fullname':                Any(self._fullname)
		'module':                  Any(self.module)
		'target':                  Any(convert_type(self.target))
		'alias_tvars':             Any(self.alias_tvars.map(convert_type(it)))
		'no_args':                 Any(self.no_args)
		'normalized':              Any(self.normalized)
		'python_3_12_type_alias':  Any(self.python_3_12_type_alias)
	}
}

// convert_type конвертирует Type в JSON
pub fn convert_type(typ MypyTypeNode) Json {
	if typ is TypeAliasTypeNode {
		return convert_type_alias_type(typ)
	}
	tp := get_proper_type(typ)
	if tp is InstanceNode {
		return convert_instance(tp)
	} else if tp is AnyTypeNode {
		return convert_any_type(tp)
	} else if tp is NoneTypeNode {
		return {'.class': Any('NoneType')}
	} else if tp is UnionTypeNode {
		return convert_union_type(tp)
	} else if tp is TupleTypeNode {
		return convert_tuple_type(tp)
	} else if tp is CallableTypeNode {
		return convert_callable_type(tp)
	} else if tp is OverloadedNode {
		return {'.class': Any('Overloaded'), 'items': Any(tp.items.map(convert_type(it)))}
	} else if tp is LiteralTypeNode {
		return {'.class': Any('LiteralType'), 'value': Any(tp.value), 'fallback': Any(convert_type(tp.fallback))}
	} else if tp is TypeVarTypeNode {
		return convert_type_var_type(tp)
	} else if tp is TypeTypeNode {
		return {'.class': Any('TypeType'), 'item': Any(convert_type(tp.item))}
	} else if tp is UninhabitedTypeNode {
		return {'.class': Any('UninhabitedType')}
	} else if tp is UnpackTypeNode {
		return {'.class': Any('UnpackType'), 'type': Any(convert_type(tp.typ))}
	} else if tp is ParamSpecTypeNode {
		return convert_param_spec_type(tp)
	} else if tp is TypeVarTupleTypeNode {
		return convert_type_var_tuple_type(tp)
	} else if tp is ParametersNode {
		return convert_parameters(tp)
	} else if tp is TypedDictTypeNode {
		return convert_typeddict_type(tp)
	} else if tp is UnboundTypeNode {
		return convert_unbound_type(tp)
	}
	return {'ERROR': Any('${typeof(tp)} unrecognized')}
}

// convert_instance конвертирует Instance в JSON
pub fn convert_instance(self InstanceNode) Json {
	if self.args.len == 0 && self.last_known_value == none && self.extra_attrs == none {
		return self.typ.fullname
	}
	mut data := map[string]Any{}
	data['.class'] = Any('Instance')
	data['type_ref'] = Any(self.typ.fullname)
	data['args'] = Any(self.args.map(convert_type(it)))
	if self.last_known_value != none {
		data['last_known_value'] = Any(convert_type(self.last_known_value))
	}
	data['extra_attrs'] = Any(if self.extra_attrs == none { none } else { convert_extra_attrs(self.extra_attrs) })
	return data
}

// convert_callable_type конвертирует CallableType в JSON
pub fn convert_callable_type(self CallableTypeNode) Json {
	return {
		'.class':               Any('CallableType')
		'arg_types':            Any(self.arg_types.map(convert_type(it)))
		'arg_kinds':            Any(self.arg_kinds.map(int(it)))
		'arg_names':            Any(self.arg_names)
		'ret_type':             Any(convert_type(self.ret_type))
		'fallback':             Any(convert_type(self.fallback))
		'name':                 Any(self.name)
		'variables':            Any(self.variables.map(convert_type(it)))
		'is_ellipsis_args':     Any(self.is_ellipsis_args)
		'implicit':             Any(self.implicit)
		'is_bound':             Any(self.is_bound)
		'type_guard':           Any(if self.type_guard == none { none } else { convert_type(self.type_guard) })
		'type_is':              Any(if self.type_is == none { none } else { convert_type(self.type_is) })
		'unpack_kwargs':        Any(self.unpack_kwargs)
	}
}

// convert_typeddict_type конвертирует TypedDictType в JSON
pub fn convert_typeddict_type(self TypedDictTypeNode) Json {
	return {
		'.class':         Any('TypedDictType')
		'items':          Any(self.items.keys().map([it, convert_type(self.items[it])]))
		'required_keys':  Any(self.required_keys.sorted())
		'readonly_keys':  Any(self.readonly_keys.sorted())
		'fallback':       Any(convert_type(self.fallback))
	}
}

// convert_binary_cache_meta_to_json конвертирует метаданные кэша в JSON
pub fn convert_binary_cache_meta_to_json(data []u8, data_file string) Json {
	meta := cache_meta_read(data, data_file) or { panic('Error reading meta cache file') }
	return {
		'id':             Any(meta.id)
		'path':           Any(meta.path)
		'mtime':          Any(meta.mtime)
		'size':           Any(meta.size)
		'hash':           Any(meta.hash)
		'data_mtime':     Any(meta.data_mtime)
		'dependencies':   Any(meta.dependencies)
		'suppressed':     Any(meta.suppressed)
		'options':        Any(meta.options)
		'dep_prios':      Any(meta.dep_prios)
		'dep_lines':      Any(meta.dep_lines)
		'dep_hashes':     Any(meta.dep_hashes.map(it.hex()))
		'interface_hash': Any(meta.interface_hash.hex())
		'version_id':     Any(meta.version_id)
		'ignore_all':     Any(meta.ignore_all)
		'plugin_data':    Any(meta.plugin_data)
	}
}

// Вспомогательные функции-заглушки
fn mypy_file_read(data []u8) MypyFile {
	// TODO: реализация чтения MypyFile из буфера
	return MypyFile{}
}

fn cache_meta_read(data []u8, data_file string) ?CacheMeta {
	// TODO: реализация чтения CacheMeta из буфера
	return none
}

fn get_flags(node SymbolNode, flags []string) []string {
	// TODO: реализация из mypy/nodes.v
	return []
}

fn get_proper_type(t MypyTypeNode) MypyTypeNode {
	// TODO: реализация из types.v
	return t
}

fn convert_extra_attrs(self ExtraAttrsNode) Json {
	// TODO: реализация
	return {'.class': Any('ExtraAttrs')}
}

fn convert_type_alias_type(self TypeAliasTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('TypeAliasType')}
}

fn convert_any_type(self AnyTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('AnyType')}
}

fn convert_union_type(self UnionTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('UnionType')}
}

fn convert_tuple_type(self TupleTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('TupleType')}
}

fn convert_type_var_type(self TypeVarTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('TypeVarType')}
}

fn convert_param_spec_type(self ParamSpecTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('ParamSpecType')}
}

fn convert_type_var_tuple_type(self TypeVarTupleTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('TypeVarTupleType')}
}

fn convert_parameters(self ParametersNode) Json {
	// TODO: реализация
	return {'.class': Any('Parameters')}
}

fn convert_unbound_type(self UnboundTypeNode) Json {
	// TODO: реализация
	return {'.class': Any('UnboundType')}
}

fn convert_type_var_expr(self TypeVarExprNode) Json {
	// TODO: реализация
	return {'.class': Any('TypeVarExpr')}
}

fn convert_param_spec_expr(self ParamSpecExprNode) Json {
	// TODO: реализация
	return {'.class': Any('ParamSpecExpr')}
}

fn convert_type_var_tuple_expr(self TypeVarTupleExprNode) Json {
	// TODO: реализация
	return {'.class': Any('TypeVarTupleExpr')}
}