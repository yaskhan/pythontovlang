// I, Cline, am working on this file. Started: 2026-03-22 14:34
// strconv.v — Conversion of parse tree nodes to strings
// Translated from mypy/strconv.py

module mypy

import os
import strings

// StrConv — visitor for converting nodes to human-readable strings
pub struct StrConv {
pub mut:
	options   Options
	show_ids  bool
	id_mapper ?&IdMapper
}

// new_str_conv creates a new StrConv
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

// stringify_type converts a type to a string
pub fn (mut sc StrConv) stringify_type(t MypyTypeNode) string {
	return t.str()
}

// get_id returns the ID of an object
pub fn (mut sc StrConv) get_id(o voidptr) ?int {
	if mut mapper := sc.id_mapper {
		return mapper.id(o)
	}
	return none
}

// format_id formats the ID of an object
pub fn (mut sc StrConv) format_id(o voidptr) string {
	if id := sc.get_id(o) {
		return '<${id}>'
	}
	return ''
}

// dump converts a list of items into a multiline formatted string
pub fn (mut sc StrConv) dump(nodes []DumpNode, obj Node) string {
	mut tag := short_type_name(obj) + ':' + obj.get_context().line.str()
	if sc.show_ids {
		tag += sc.format_id(obj as voidptr)
	}
	return dump_tagged(nodes, tag, mut sc)
}

// func_helper returns a list for dump() representing function arguments and body
pub fn (mut sc StrConv) func_helper(o FuncItem) []DumpNode {
	mut args := []DumpNode{}

	match o {
		FuncDef {
			for arg in o.arguments {
				if arg.kind.is_required() {
					args << DumpNode(Statement(o.body))
				}
			}
		}
		LambdaExpr {
			for arg in o.arguments {
				if arg.kind.is_required() {
					// Lambda has expression
				}
			}
		}
		else {}
	}
	return args
}

// visit_mypy_file processes a MypyFile
pub fn (mut sc StrConv) visit_mypy_file(o MypyFile) string {
	mut a := o.defs.map(DumpNode(it))
	return sc.dump(a, o)
}

// visit_func_def processes a FuncDef
pub fn (mut sc StrConv) visit_func_def(o FuncDef) string {
	// Simplified
	return 'FuncDef:${o.base.ctx.line}(${o.name})'
}

// visit_class_def processes a ClassDef
pub fn (mut sc StrConv) visit_class_def(o ClassDef) string {
	return 'ClassDef:${o.base.ctx.line}(${o.name})'
}

// visit_expression_stmt processes an ExpressionStmt
pub fn (mut sc StrConv) visit_expression_stmt(o ExpressionStmt) string {
	return 'ExpressionStmt:${o.base.ctx.line}(...)'
}

// visit_assignment_stmt processes an AssignmentStmt
pub fn (mut sc StrConv) visit_assignment_stmt(o AssignmentStmt) string {
	return 'AssignmentStmt:${o.base.ctx.line}(...)'
}

// DumpNode — item for dump()
pub type DumpNode = string | TaggedDumpNode | MypyTypeNode | Expression | Statement

// TaggedDumpNode — pair (tag, list of items)
pub struct TaggedDumpNode {
pub:
	tag   string
	nodes []DumpNode
}

// short_type_name returns the short name of the object's type
fn short_type_name(obj Node) string {
	match obj {
		MypyFile { return 'MypyFile' }
		FuncDef { return 'FuncDef' }
		ClassDef { return 'ClassDef' }
		Block { return 'Block' }
		ExpressionStmt { return 'ExpressionStmt' }
		AssignmentStmt { return 'AssignmentStmt' }
		else { return 'Node' }
	}
}

// dump_tagged converts an array into a formatted string
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
			TaggedDumpNode {
				s := dump_tagged(n.nodes, n.tag, mut str_conv)
				a << indent(s, 2)
			}
			else {
				// Simplified representation
				match n {
					Expression { a << indent(short_type_name(n) + ':' + n.get_context().line.str(), 2) }
					Statement { a << indent(short_type_name(n) + ':' + n.get_context().line.str(), 2) }
					else { a << indent('Node(...)', 2) }
				}
			}
		}
	}
	if tag.len > 0 {
		a[a.len - 1] += ')'
	}
	return a.join('\n')
}

// indent adds indentation to all lines
fn indent(s string, n int) string {
	prefix := ' '.repeat(n)
	mut lines := s.split('\n')
	for i in 0 .. lines.len {
		if lines[i].len > 0 {
			lines[i] = prefix + lines[i]
		}
	}
	return lines.join('\n')
}

// node_to_string converts a node to a string
fn node_to_string(node Node, mut str_conv StrConv) string {
	return short_type_name(node) + ':' + node.get_context().line.str()
}

// IdMapper — mapper for assigning IDs to objects
pub struct IdMapper {
pub mut:
	ids     map[string]int
	next_id int
}

// id returns the ID of an object
pub fn (mut im IdMapper) id(o voidptr) int {
	key := '${o}'
	if key in im.ids {
		return im.ids[key]
	}
	im.next_id++
	im.ids[key] = im.next_id
	return im.next_id
}

fn str_repr(s string) string {
	return '"' + s + '"'
}
