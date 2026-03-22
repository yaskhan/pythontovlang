// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:34
// strconv.v — Conversion of parse tree nodes to strings
// Переведён из mypy/strconv.py

module mypy

import os
import strings

// StrConv — visitor для конвертации узлов в человекочитаемую строку
// Например, MypyFile из программы '1' конвертируется в:
//   MypyFile:1(
//     fnam
//     ExpressionStmt:1(
//       IntExpr(1)))
pub struct StrConv {
pub mut:
	options   Options
	show_ids  bool
	id_mapper ?&IdMapper
}

// new_str_conv создаёт новый StrConv
pub fn new_str_conv(show_ids bool, options Options) StrConv {
	mut sc := StrConv{
		options:   options
		show_ids:  show_ids
		id_mapper: none
	}
	if show_ids {
		sc.id_mapper = &IdMapper{}
	}
	return sc
}

// stringify_type конвертирует тип в строку
pub fn (mut sc StrConv) stringify_type(t MypyTypeNode) string {
	// Delegate to types module
	return t.str()
}

// get_id возвращает ID объекта
pub fn (sc StrConv) get_id(o voidptr) ?int {
	if id_mapper := sc.id_mapper {
		return id_mapper.id(o)
	}
	return none
}

// format_id форматирует ID объекта
pub fn (sc StrConv) format_id(o voidptr) string {
	if sc.id_mapper != none {
		id := sc.get_id(o) or { return '' }
		return '<${id}>'
	}
	return ''
}

// dump конвертирует список элементов в многострочную отформатированную строку
pub fn (mut sc StrConv) dump(nodes []DumpNode, obj NodeBase) string {
	tag := short_type_name(obj) + ':' + obj.line.str()
	if sc.show_ids {
		id := sc.get_id(obj) or { 0 }
		tag += '<${id}>'
	}
	return dump_tagged(nodes, tag, mut sc)
}

// func_helper возвращает список для dump() представляющий аргументы и тело функции
pub fn (mut sc StrConv) func_helper(o FuncItem) []DumpNode {
	mut args := []DumpNode{}
	mut extra := []DumpNode{}

	for arg in o.arguments {
		kind := arg.kind
		if kind.is_required() {
			args << DumpNode(NodeBase(arg.variable))
		} else if kind.is_optional() {
			if init := arg.initializer {
				args << DumpNode(TaggedDumpNode{'default', [
					DumpNode(NodeBase(arg.variable)),
					DumpNode(NodeBase(init)),
				]})
			}
		} else if kind == ArgKind.star {
			extra << DumpNode(TaggedDumpNode{'VarArg', [
				DumpNode(NodeBase(arg.variable)),
			]})
		} else if kind == ArgKind.star2 {
			extra << DumpNode(TaggedDumpNode{'DictVarArg', [
				DumpNode(NodeBase(arg.variable)),
			]})
		}
	}

	mut a := []DumpNode{}
	if o.type_args.len > 0 {
		for p in o.type_args {
			a << DumpNode(sc.type_param(p))
		}
	}
	if args.len > 0 {
		a << DumpNode(TaggedDumpNode{'Args', args})
	}
	if o_type := o.typ {
		a << DumpNode(o_type)
	}
	if o.is_generator {
		a << DumpNode('Generator')
	}
	a << extra
	a << DumpNode(NodeBase(o.body))
	return a
}

// visit_mypy_file обрабатывает MypyFile
pub fn (mut sc StrConv) visit_mypy_file(o MypyFile) string {
	mut a := [DumpNode(o.defs)]
	if o.is_bom {
		a.insert(0, DumpNode('BOM'))
	}
	if o.path != 'main' {
		// Нормализуем разделители директорий
		normalized := o.path.replace(os.getwd() + os.path_separator, '').replace(os.path_separator,
			'/')
		a.insert(0, DumpNode(normalized))
	}
	if o.ignored_lines.len > 0 {
		lines_str := o.ignored_lines.map(it.str()).join(', ')
		a << DumpNode('IgnoredLines(${lines_str})')
	}
	return sc.dump(a, NodeBase(o))
}

// visit_import обрабатывает Import
pub fn (sc StrConv) visit_import(o Import) string {
	mut a := []string{}
	for id, as_id in o.ids {
		if as_id.len > 0 {
			a << '${id} : ${as_id}'
		} else {
			a << id
		}
	}
	return 'Import:${o.line}(${a.join(', ')})'
}

// visit_import_from обрабатывает ImportFrom
pub fn (sc StrConv) visit_import_from(o ImportFrom) string {
	mut a := []string{}
	for name, as_name in o.names {
		if as_name.len > 0 {
			a << '${name} : ${as_name}'
		} else {
			a << name
		}
	}
	dots := '.'.repeat(o.relative)
	return 'ImportFrom:${o.line}(${dots}${o.id}, [${a.join(', ')}])'
}

// visit_import_all обрабатывает ImportAll
pub fn (sc StrConv) visit_import_all(o ImportAll) string {
	dots := '.'.repeat(o.relative)
	return 'ImportAll:${o.line}(${dots}${o.id})'
}

// visit_func_def обрабатывает FuncDef
pub fn (mut sc StrConv) visit_func_def(o FuncDef) string {
	mut a := sc.func_helper(o)
	a.insert(0, DumpNode(o.name))

	mut arg_kinds := map[string]bool{}
	for arg in o.arguments {
		arg_kinds['${arg.kind}'] = true
	}
	if arg_kinds['named'] || arg_kinds['named_opt'] {
		a.insert(1, DumpNode('MaxPos(${o.max_pos})'))
	}
	if o.is_coroutine {
		a.insert(1, DumpNode('Async'))
	}
	if o.abstract_status in [is_abstract, implicitly_abstract] {
		a.insert(a.len - 1, DumpNode('Abstract'))
	}
	if o.is_static {
		a.insert(a.len - 1, DumpNode('Static'))
	}
	if o.is_class {
		a.insert(a.len - 1, DumpNode('Class'))
	}
	if o.is_property {
		a.insert(a.len - 1, DumpNode('Property'))
	}
	return sc.dump(a, NodeBase(o))
}

// visit_class_def обрабатывает ClassDef
pub fn (mut sc StrConv) visit_class_def(o ClassDef) string {
	mut a := [DumpNode(o.name), DumpNode(o.defs.body)]

	if o.base_type_exprs.len > 0 {
		if info := o.info {
			if info.bases.len > 0 {
				if info.bases.len != 1 || info.bases[0].typ.fullname != 'builtins.object' {
					base_nodes := info.bases.map(DumpNode(NodeBase(it)))
					a.insert(1, DumpNode(TaggedDumpNode{'BaseType', base_nodes}))
				}
			}
		} else {
			base_nodes := o.base_type_exprs.map(DumpNode(NodeBase(it)))
			a.insert(1, DumpNode(TaggedDumpNode{'BaseTypeExpr', base_nodes}))
		}
	}
	if o.type_vars.len > 0 {
		tv_nodes := o.type_vars.map(DumpNode(NodeBase(it)))
		a.insert(1, DumpNode(TaggedDumpNode{'TypeVars', tv_nodes}))
	}
	if o.decorators.len > 0 {
		dec_nodes := o.decorators.map(DumpNode(NodeBase(it)))
		a.insert(1, DumpNode(TaggedDumpNode{'Decorators', dec_nodes}))
	}
	if o.type_args.len > 0 {
		for p in o.type_args.reverse() {
			a.insert(1, DumpNode(sc.type_param(p)))
		}
	}
	return sc.dump(a, NodeBase(o))
}

// visit_var обрабатывает Var
pub fn (sc StrConv) visit_var(o Var) string {
	lst := if o.line < 0 { ':nil' } else { '' }
	return 'Var${lst}(${o.name})'
}

// visit_block обрабатывает Block
pub fn (mut sc StrConv) visit_block(o Block) string {
	body_nodes := o.body.map(DumpNode(NodeBase(it)))
	return sc.dump(body_nodes, NodeBase(o))
}

// visit_expression_stmt обрабатывает ExpressionStmt
pub fn (mut sc StrConv) visit_expression_stmt(o ExpressionStmt) string {
	return sc.dump([DumpNode(NodeBase(o.expr))], NodeBase(o))
}

// visit_assignment_stmt обрабатывает AssignmentStmt
pub fn (mut sc StrConv) visit_assignment_stmt(o AssignmentStmt) string {
	mut a := []DumpNode{}
	if o.lvalues.len > 1 {
		lv_nodes := o.lvalues.map(DumpNode(NodeBase(it)))
		a << DumpNode(TaggedDumpNode{'Lvalues', lv_nodes})
	} else {
		a << DumpNode(NodeBase(o.lvalues[0]))
	}
	a << DumpNode(NodeBase(o.rvalue))
	if o_type := o.typ {
		a << DumpNode(o_type)
	}
	return sc.dump(a, NodeBase(o))
}

// visit_while_stmt обрабатывает WhileStmt
pub fn (mut sc StrConv) visit_while_stmt(o WhileStmt) string {
	mut a := [DumpNode(NodeBase(o.expr)), DumpNode(NodeBase(o.body))]
	if o.else_body {
		a << DumpNode(TaggedDumpNode{'Else', o.else_body.body.map(DumpNode(NodeBase(it)))})
	}
	return sc.dump(a, NodeBase(o))
}

// visit_for_stmt обрабатывает ForStmt
pub fn (mut sc StrConv) visit_for_stmt(o ForStmt) string {
	mut a := []DumpNode{}
	if o.is_async {
		a << DumpNode(TaggedDumpNode{'Async', []DumpNode{}})
	}
	a << DumpNode(NodeBase(o.index))
	if o.index_type {
		a << DumpNode(o.index_type)
	}
	a << DumpNode(NodeBase(o.expr))
	a << DumpNode(NodeBase(o.body))
	if o.else_body {
		a << DumpNode(TaggedDumpNode{'Else', o.else_body.body.map(DumpNode(NodeBase(it)))})
	}
	return sc.dump(a, NodeBase(o))
}

// visit_return_stmt обрабатывает ReturnStmt
pub fn (mut sc StrConv) visit_return_stmt(o ReturnStmt) string {
	mut nodes := []DumpNode{}
	if o.expr {
		nodes << DumpNode(NodeBase(o.expr))
	}
	return sc.dump(nodes, NodeBase(o))
}

// visit_if_stmt обрабатывает IfStmt
pub fn (mut sc StrConv) visit_if_stmt(o IfStmt) string {
	mut a := []DumpNode{}
	for i in 0 .. o.expr.len {
		a << DumpNode(TaggedDumpNode{'If', [DumpNode(NodeBase(o.expr[i]))]})
		a << DumpNode(TaggedDumpNode{'Then', o.body[i].body.map(DumpNode(NodeBase(it)))})
	}
	if o.else_body {
		a << DumpNode(TaggedDumpNode{'Else', o.else_body.body.map(DumpNode(NodeBase(it)))})
	}
	return sc.dump(a, NodeBase(o))
}

// visit_break_stmt обрабатывает BreakStmt
pub fn (mut sc StrConv) visit_break_stmt(o BreakStmt) string {
	return sc.dump([], NodeBase(o))
}

// visit_continue_stmt обрабатывает ContinueStmt
pub fn (mut sc StrConv) visit_continue_stmt(o ContinueStmt) string {
	return sc.dump([], NodeBase(o))
}

// visit_pass_stmt обрабатывает PassStmt
pub fn (mut sc StrConv) visit_pass_stmt(o PassStmt) string {
	return sc.dump([], NodeBase(o))
}

// visit_try_stmt обрабатывает TryStmt
pub fn (mut sc StrConv) visit_try_stmt(o TryStmt) string {
	mut a := [DumpNode(NodeBase(o.body))]
	if o.is_star {
		a << DumpNode('*')
	}
	for i in 0 .. o.vars.len {
		if o.types.len > i {
			a << DumpNode(NodeBase(o.types[i]))
		}
		if o.vars[i] {
			a << DumpNode(NodeBase(o.vars[i]))
		}
		if o.handlers.len > i {
			a << DumpNode(NodeBase(o.handlers[i]))
		}
	}
	if o.else_body {
		a << DumpNode(TaggedDumpNode{'Else', o.else_body.body.map(DumpNode(NodeBase(it)))})
	}
	if o.finally_body {
		a << DumpNode(TaggedDumpNode{'Finally', o.finally_body.body.map(DumpNode(NodeBase(it)))})
	}
	return sc.dump(a, NodeBase(o))
}

// visit_int_expr обрабатывает IntExpr
pub fn (sc StrConv) visit_int_expr(o IntExpr) string {
	return 'IntExpr(${o.value})'
}

// visit_str_expr обрабатывает StrExpr
pub fn (sc StrConv) visit_str_expr(o StrExpr) string {
	return 'StrExpr(${str_repr(o.value)})'
}

// visit_float_expr обрабатывает FloatExpr
pub fn (sc StrConv) visit_float_expr(o FloatExpr) string {
	return 'FloatExpr(${o.value})'
}

// visit_name_expr обрабатывает NameExpr
pub fn (sc StrConv) visit_name_expr(o NameExpr) string {
	mut pretty := sc.pretty_name(o.name, o.kind, o.fullname, o.is_inferred_def || o.is_special_form,
		o.node)
	if o.node is VarNode {
		if o.node.is_final {
			if final_value := o.node.final_value {
				pretty += ' = ${final_value}'
			}
		}
	}
	return short_type_name(o) + '(' + pretty + ')'
}

// pretty_name форматирует имя с дополнительной информацией
pub fn (sc StrConv) pretty_name(name string, kind int, fullname string, is_inferred_def bool, target_node ?Node) string {
	mut n := name
	if is_inferred_def {
		n += '*'
	}
	mut id := ''
	if target_node {
		id = sc.format_id(target_node)
	}
	if target_node is MypyFile && name == fullname {
		n += id
	} else if kind == gdef || (fullname != name && fullname.len > 0) {
		n += ' [${fullname}${id}]'
	} else if kind == ldef {
		n += ' [l${id}]'
	} else if kind == mdef {
		n += ' [m${id}]'
	} else {
		n += id
	}
	return n
}

// visit_member_expr обрабатывает MemberExpr
pub fn (mut sc StrConv) visit_member_expr(o MemberExpr) string {
	pretty := sc.pretty_name(o.name, o.kind, o.fullname, o.is_inferred_def, o.node)
	return sc.dump([DumpNode(NodeBase(o.expr)), DumpNode(pretty)], NodeBase(o))
}

// visit_call_expr обрабатывает CallExpr
pub fn (mut sc StrConv) visit_call_expr(o CallExpr) string {
	if o.analyzed {
		return node_to_string(o.analyzed, mut sc)
	}
	mut args := []DumpNode{}
	mut extra := []DumpNode{}
	for i, kind in o.arg_kinds {
		if kind in [ArgKind.pos, ArgKind.star] {
			args << DumpNode(NodeBase(o.args[i]))
			if kind == ArgKind.star {
				extra << DumpNode('VarArg')
			}
		} else if kind == ArgKind.named {
			extra << DumpNode(TaggedDumpNode{'KwArgs', [DumpNode(o.arg_names[i]),
				DumpNode(NodeBase(o.args[i]))]})
		} else if kind == ArgKind.star2 {
			extra << DumpNode(TaggedDumpNode{'DictVarArg', [
				DumpNode(NodeBase(o.args[i])),
			]})
		}
	}
	mut a := [DumpNode(NodeBase(o.callee)), DumpNode(TaggedDumpNode{'Args', args})]
	a << extra
	return sc.dump(a, NodeBase(o))
}

// visit_op_expr обрабатывает OpExpr
pub fn (mut sc StrConv) visit_op_expr(o OpExpr) string {
	if o.analyzed {
		return node_to_string(o.analyzed, mut sc)
	}
	return sc.dump([DumpNode(o.op), DumpNode(NodeBase(o.left)), DumpNode(NodeBase(o.right))],
		NodeBase(o))
}

// visit_unary_expr обрабатывает UnaryExpr
pub fn (mut sc StrConv) visit_unary_expr(o UnaryExpr) string {
	return sc.dump([DumpNode(o.op), DumpNode(NodeBase(o.expr))], NodeBase(o))
}

// visit_list_expr обрабатывает ListExpr
pub fn (mut sc StrConv) visit_list_expr(o ListExpr) string {
	nodes := o.items.map(DumpNode(NodeBase(it)))
	return sc.dump(nodes, NodeBase(o))
}

// visit_tuple_expr обрабатывает TupleExpr
pub fn (mut sc StrConv) visit_tuple_expr(o TupleExpr) string {
	nodes := o.items.map(DumpNode(NodeBase(it)))
	return sc.dump(nodes, NodeBase(o))
}

// visit_dict_expr обрабатывает DictExpr
pub fn (mut sc StrConv) visit_dict_expr(o DictExpr) string {
	nodes := o.items.map(DumpNode([DumpNode(NodeBase(it[0])), DumpNode(NodeBase(it[1]))]))
	return sc.dump(nodes, NodeBase(o))
}

// type_param обрабатывает TypeParam
pub fn (sc StrConv) type_param(p TypeParam) DumpNode {
	mut a := []DumpNode{}
	mut prefix := ''
	if p.kind == param_spec_kind {
		prefix = '**'
	} else if p.kind == type_var_tuple_kind {
		prefix = '*'
	}
	a << DumpNode(prefix + p.name)
	if p.upper_bound {
		a << DumpNode(p.upper_bound)
	}
	if p.values.len > 0 {
		val_nodes := p.values.map(DumpNode(NodeBase(it)))
		a << DumpNode(TaggedDumpNode{'Values', val_nodes})
	}
	if p.default {
		a << DumpNode(TaggedDumpNode{'Default', [DumpNode(p.default)]})
	}
	return DumpNode(TaggedDumpNode{'TypeParam', a})
}

// str_repr экранирует спецсимволы в строке
fn str_repr(s string) string {
	// Заменяем не-ASCII символы на \uXXXX
	mut result := strings.new_builder(s.len * 2)
	for ch in s {
		if ch >= 0x20 && ch <= 0x7e {
			result.write_u8(ch)
		} else {
			hex := '0000${ch.hex()}'
			result.write_string('\\u')
			result.write_string(hex.substr(hex.len - 4, hex.len))
		}
	}
	return result.str()
}

// Вспомогательные типы и функции

// DumpNode — элемент для dump()
pub type DumpNode = Node | NodeBase | string | TaggedDumpNode

// TaggedDumpNode — пара (тег, список элементов)
pub struct TaggedDumpNode {
pub:
	tag   string
	nodes []DumpNode
}

// short_type_name возвращает короткое имя типа объекта
fn short_type_name(obj NodeBase) string {
	// Получаем имя типа из объекта
	if obj is MypyFile {
		return 'MypyFile'
	} else if obj is FuncDef {
		return 'FuncDef'
	} else if obj is ClassDef {
		return 'ClassDef'
	} else if obj is Var {
		return 'Var'
	} else if obj is Block {
		return 'Block'
	} else if obj is ExpressionStmt {
		return 'ExpressionStmt'
	} else if obj is AssignmentStmt {
		return 'AssignmentStmt'
	} else if obj is WhileStmt {
		return 'WhileStmt'
	} else if obj is ForStmt {
		return 'ForStmt'
	} else if obj is ReturnStmt {
		return 'ReturnStmt'
	} else if obj is IfStmt {
		return 'IfStmt'
	} else if obj is BreakStmt {
		return 'BreakStmt'
	} else if obj is ContinueStmt {
		return 'ContinueStmt'
	} else if obj is PassStmt {
		return 'PassStmt'
	} else if obj is TryStmt {
		return 'TryStmt'
	} else if obj is Decorator {
		return 'Decorator'
	} else if obj is Import {
		return 'Import'
	} else if obj is ImportFrom {
		return 'ImportFrom'
	} else if obj is ImportAll {
		return 'ImportAll'
	} else if obj is NameExpr {
		return 'NameExpr'
	} else if obj is MemberExpr {
		return 'MemberExpr'
	} else if obj is CallExpr {
		return 'CallExpr'
	} else if obj is IntExpr {
		return 'IntExpr'
	} else if obj is StrExpr {
		return 'StrExpr'
	} else if obj is FloatExpr {
		return 'FloatExpr'
	} else if obj is OpExpr {
		return 'OpExpr'
	} else if obj is UnaryExpr {
		return 'UnaryExpr'
	} else if obj is ListExpr {
		return 'ListExpr'
	} else if obj is TupleExpr {
		return 'TupleExpr'
	} else if obj is DictExpr {
		return 'DictExpr'
	} else if obj is TypeInfo {
		return 'TypeInfo'
	} else if obj is VarNode {
		return 'Var'
	}
	return 'Node'
}

// dump_tagged конвертирует массив в отформатированную строку
fn dump_tagged(nodes []DumpNode, tag string, mut str_conv StrConv) string {
	mut a := []string{}
	if tag.len > 0 {
		a << tag + '('
	}
	for n in nodes {
		match n {
			string {
				a << indent(n, 2)
			}
			NodeBase {
				a << indent(node_to_string(n, mut str_conv), 2)
			}
			Node {
				a << indent(node_to_string(n, mut str_conv), 2)
			}
			TaggedDumpNode {
				s := dump_tagged(n.nodes, n.tag, mut str_conv)
				a << indent(s, 2)
			}
		}
	}
	if tag.len > 0 {
		a[a.len - 1] += ')'
	}
	return a.join('\n')
}

// indent добавляет отступ ко всем строкам
fn indent(s string, n int) string {
	prefix := ' '.repeat(n)
	mut lines := s.split('\n')
	for i in 0 .. lines.len {
		lines[i] = prefix + lines[i]
	}
	return lines.join('\n')
}

// node_to_string конвертирует узел в строку (заглушка)
fn node_to_string(node Node, mut str_conv StrConv) string {
	// TODO: вызвать accept у узла
	return node.str()
}

// IdMapper — маппер для присвоения ID объектам
pub struct IdMapper {
pub mut:
	ids     map[string]int
	next_id int
}

// id возвращает ID объекта
pub fn (mut im IdMapper) id(o voidptr) int {
	key := '${o}'
	if key in im.ids {
		return im.ids[key]
	}
	im.next_id++
	im.ids[key] = im.next_id
	return im.next_id
}
