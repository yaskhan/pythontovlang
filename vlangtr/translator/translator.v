module translator

import analyzer
import ast
import base
import expressions
import models

pub struct Translator {
pub mut:
	state    base.TranslatorState
	analyzer analyzer.Analyzer
	model    models.VType
	output   []string
}

fn noop_visit_expr(_ ast.Expression) string {
	return ''
}

pub fn new_translator() &Translator {
	return &Translator{
		state:    base.new_translator_state()
		analyzer: analyzer.new_analyzer(map[string]string{})
		model:    .unknown
		output:   []string{}
	}
}

fn (mut t Translator) emit(line string) {
	t.output << line
}

fn (mut t Translator) visit_expr(node ast.Expression) string {
	mut eg := expressions.new_expr_gen(&t.model, &t.analyzer)
	eg.state = t.state
	result := eg.visit(node)
	t.state = eg.state
	return result
}

fn (mut t Translator) visit_stmt(node ast.Statement) {
	match node {
		ast.Import { t.visit_import(node) }
		ast.ImportFrom { t.visit_import_from(node) }
		ast.Assign { t.visit_assign(node) }
		ast.AnnAssign { t.visit_ann_assign(node) }
		ast.Expr { t.visit_expr_stmt(node) }
		ast.AugAssign { t.visit_aug_assign(node) }
		ast.Delete { t.visit_delete_stmt(node) }
		ast.Pass {}
		ast.If { t.visit_if(node) }
		else {
			// Keep the output deterministic while surfacing unhandled nodes.
			t.emit('//##LLM@@ Unsupported statement: ${node.str()}')
		}
	}
}

fn (mut t Translator) visit_expr_stmt(node ast.Expr) {
	expr := t.visit_expr(node.value)
	if expr.len > 0 {
		t.emit(expr)
	}
}

fn (mut t Translator) visit_assign(node ast.Assign) {
	if node.targets.len == 0 {
		return
	}
	if node.targets.len > 1 {
		t.emit('//##LLM@@ Multiple assignment not fully lowered.')
		t.emit(t.visit_expr(node.value))
		return
	}
	target := node.targets[0]
	rhs := t.visit_expr(node.value)

	if target is ast.Name {
		lhs := base.sanitize_name(target.id, false, map[string]bool{}, '', map[string]bool{})
		t.emit('${lhs} := ${rhs}')
		return
	}

	t.emit('${t.visit_expr(target)} = ${rhs}')
}

fn (mut t Translator) visit_ann_assign(node ast.AnnAssign) {
	if value := node.value {
		if node.target is ast.Name {
			lhs := base.sanitize_name(node.target.id, false, map[string]bool{}, '', map[string]bool{})
			t.emit('${lhs} := ${t.visit_expr(value)}')
			return
		}
		t.emit('${t.visit_expr(node.target)} = ${t.visit_expr(value)}')
	}
}

fn (mut t Translator) visit_aug_assign(node ast.AugAssign) {
	target := t.visit_expr(node.target)
	value := t.visit_expr(node.value)
	t.emit('${target} ${node.op.value}= ${value}')
}

fn (mut t Translator) visit_delete_stmt(node ast.Delete) {
	_ = node
	t.emit('//##LLM@@ del statement not lowered.')
}

fn (mut t Translator) visit_if(node ast.If) {
	if node.test is ast.Compare {
		cmp := node.test
		if cmp.left is ast.Name && cmp.left.id == '__name__' && cmp.comparators.len == 1 {
			if cmp.comparators[0] is ast.Constant {
				right := cmp.comparators[0] as ast.Constant
				if right.value == '__main__' {
					for stmt in node.body {
						t.visit_stmt(stmt)
					}
					return
				}
			}
		}
	}
	t.emit('//##LLM@@ if statement lowered as comment')
}

fn usage_max(a int, b int) int {
	if a > b {
		return a
	}
	return b
}

fn (t &Translator) expr_name_usage(node ast.Expression, name string) int {
	match node {
		ast.Name {
			return if node.id == name { 2 } else { 0 }
		}
		ast.Constant {
			return 0
		}
		ast.Call {
			if node.func is ast.Name && node.func.id == 'len' && node.args.len == 1 && node.keywords.len == 0 {
				if node.args[0] is ast.Name && node.args[0].id == name {
					return 1
				}
			}
			mut usage := t.expr_name_usage(node.func, name)
			for arg in node.args {
				usage = usage_max(usage, t.expr_name_usage(arg, name))
			}
			for kw in node.keywords {
				usage = usage_max(usage, t.expr_name_usage(kw.value, name))
			}
			return usage
		}
		ast.Attribute {
			return t.expr_name_usage(node.value, name)
		}
		ast.Subscript {
			return usage_max(t.expr_name_usage(node.value, name), t.expr_name_usage(node.slice, name))
		}
		ast.UnaryOp {
			return t.expr_name_usage(node.operand, name)
		}
		ast.BinaryOp {
			return usage_max(t.expr_name_usage(node.left, name), t.expr_name_usage(node.right, name))
		}
		ast.Compare {
			mut usage := t.expr_name_usage(node.left, name)
			for comparator in node.comparators {
				usage = usage_max(usage, t.expr_name_usage(comparator, name))
			}
			return usage
		}
		ast.IfExp {
			mut usage := t.expr_name_usage(node.test, name)
			usage = usage_max(usage, t.expr_name_usage(node.body, name))
			usage = usage_max(usage, t.expr_name_usage(node.orelse, name))
			return usage
		}
		ast.JoinedStr {
			mut usage := 0
			for value in node.values {
				usage = usage_max(usage, t.expr_name_usage(value, name))
			}
			return usage
		}
		ast.FormattedValue {
			mut usage := t.expr_name_usage(node.value, name)
			if format_spec := node.format_spec {
				usage = usage_max(usage, t.expr_name_usage(format_spec, name))
			}
			return usage
		}
		ast.List {
			mut usage := 0
			for elt in node.elements {
				usage = usage_max(usage, t.expr_name_usage(elt, name))
			}
			return usage
		}
		ast.Tuple {
			mut usage := 0
			for elt in node.elements {
				usage = usage_max(usage, t.expr_name_usage(elt, name))
			}
			return usage
		}
		ast.Set {
			mut usage := 0
			for elt in node.elements {
				usage = usage_max(usage, t.expr_name_usage(elt, name))
			}
			return usage
		}
		ast.Dict {
			mut usage := 0
			for key in node.keys {
				if key is ast.NoneExpr {
					continue
				}
				usage = usage_max(usage, t.expr_name_usage(key, name))
			}
			for value in node.values {
				usage = usage_max(usage, t.expr_name_usage(value, name))
			}
			return usage
		}
		else {
			return 0
		}
	}
}

fn (t &Translator) stmt_name_usage(stmt ast.Statement, name string) int {
	match stmt {
		ast.Assign {
			mut usage := t.expr_name_usage(stmt.value, name)
			for target in stmt.targets {
				usage = usage_max(usage, t.expr_name_usage(target, name))
			}
			return usage
		}
		ast.AnnAssign {
			mut usage := t.expr_name_usage(stmt.annotation, name)
			if value := stmt.value {
				usage = usage_max(usage, t.expr_name_usage(value, name))
			}
			return usage
		}
		ast.Expr {
			return t.expr_name_usage(stmt.value, name)
		}
		ast.If {
			mut usage := t.expr_name_usage(stmt.test, name)
			for inner in stmt.body {
				usage = usage_max(usage, t.stmt_name_usage(inner, name))
			}
			for inner in stmt.orelse {
				usage = usage_max(usage, t.stmt_name_usage(inner, name))
			}
			return usage
		}
		else {
			return 0
		}
	}
}

fn (t &Translator) is_pure_literal_expr(node ast.Expression) bool {
	return node is ast.Constant || node is ast.List || node is ast.Tuple || node is ast.Set
		|| node is ast.Dict
}

fn (mut t Translator) append_helpers() {
	if 'py_sorted' in t.state.used_builtins {
		t.output << ''
		t.output << 'fn py_sorted[T](a []T, reverse bool) []T {'
		t.output << '    // ...'
		t.output << '}'
	}
	if 'py_reversed' in t.state.used_builtins {
		t.output << ''
		t.output << 'fn py_reversed[T](a []T) []T {'
		t.output << '    // ...'
		t.output << '}'
	}
}

pub fn (mut t Translator) translate(source string) string {
	t.state = base.new_translator_state()
	t.analyzer = analyzer.new_analyzer(map[string]string{})
	t.output = []string{}
	t.model = .unknown

	mut lexer := ast.new_lexer(source, 'test.py')
	mut parser := ast.new_parser(lexer)
	module_node := parser.parse_module()

	for i, stmt in module_node.body {
		if stmt is ast.Assign && stmt.targets.len == 1 && stmt.targets[0] is ast.Name
			&& t.is_pure_literal_expr(stmt.value) {
			target := stmt.targets[0] as ast.Name
			if t.stmt_name_usage_list(module_node.body[i + 1..].clone(), target.id) == 1 {
				continue
			}
		}
		t.visit_stmt(stmt)
	}

	t.append_helpers()
	return t.output.join('\n')
}

fn (t &Translator) stmt_name_usage_list(stmts []ast.Statement, name string) int {
	mut usage := 0
	for stmt in stmts {
		usage = usage_max(usage, t.stmt_name_usage(stmt, name))
	}
	return usage
}
