module analyzer

import ast

pub struct YieldFinder {
pub mut:
	found bool
}

pub fn new_yield_finder() YieldFinder {
	return YieldFinder{}
}

pub fn (mut y YieldFinder) scan_module(node ast.Module) {
	for stmt in node.body {
		y.scan_stmt_for_generators(stmt)
		if y.found {
			return
		}
	}
}

fn (mut y YieldFinder) has_yield_in_function(node ast.FunctionDef) bool {
	y.found = false
	for stmt in node.body {
		y.visit_stmt(stmt)
		if y.found {
			return true
		}
	}
	return y.found
}

fn (mut y YieldFinder) visit_block(stmts []ast.Statement) {
	for stmt in stmts {
		y.visit_stmt(stmt)
		if y.found {
			return
		}
	}
}

fn (mut y YieldFinder) scan_stmt_for_generators(node ast.Statement) {
	if y.found {
		return
	}
	match node {
		ast.FunctionDef {
			if y.has_yield_in_function(node) {
				y.found = true
				return
			}
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.ClassDef {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.If {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for stmt in node.orelse {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.While {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for stmt in node.orelse {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.For {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for stmt in node.orelse {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.With {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.Try {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for handler in node.handlers {
				for stmt in handler.body {
					y.scan_stmt_for_generators(stmt)
					if y.found {
						return
					}
				}
			}
			for stmt in node.orelse {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for stmt in node.finalbody {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.TryStar {
			for stmt in node.body {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for handler in node.handlers {
				for stmt in handler.body {
					y.scan_stmt_for_generators(stmt)
					if y.found {
						return
					}
				}
			}
			for stmt in node.orelse {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
			for stmt in node.finalbody {
				y.scan_stmt_for_generators(stmt)
				if y.found {
					return
				}
			}
		}
		ast.Match {
			for case in node.cases {
				for stmt in case.body {
					y.scan_stmt_for_generators(stmt)
					if y.found {
						return
					}
				}
			}
		}
		else {}
	}
}

fn (mut y YieldFinder) visit_stmt(node ast.Statement) {
	if y.found {
		return
	}
	match node {
		ast.Module {
			y.scan_module(node)
		}
		ast.Expr {
			y.visit_expr(node.value)
		}
		ast.FunctionDef {
			// Stop at nested function boundaries.
		}
		ast.ClassDef {
			for stmt in node.body {
				y.visit_stmt(stmt)
				if y.found {
					return
				}
			}
		}
		ast.If {
			y.visit_expr(node.test)
			y.visit_block(node.body)
			y.visit_block(node.orelse)
		}
		ast.While {
			y.visit_expr(node.test)
			y.visit_block(node.body)
			y.visit_block(node.orelse)
		}
		ast.For {
			y.visit_expr(node.target)
			y.visit_expr(node.iter)
			y.visit_block(node.body)
			y.visit_block(node.orelse)
		}
		ast.With {
			for item in node.items {
				y.visit_expr(item.context_expr)
				if opt := item.optional_vars {
					y.visit_expr(opt)
				}
			}
			y.visit_block(node.body)
		}
		ast.Try {
			y.visit_block(node.body)
			for handler in node.handlers {
				if typ := handler.typ {
					y.visit_expr(typ)
				}
				y.visit_block(handler.body)
			}
			y.visit_block(node.orelse)
			y.visit_block(node.finalbody)
		}
		ast.TryStar {
			y.visit_block(node.body)
			for handler in node.handlers {
				if typ := handler.typ {
					y.visit_expr(typ)
				}
				y.visit_block(handler.body)
			}
			y.visit_block(node.orelse)
			y.visit_block(node.finalbody)
		}
		ast.Match {
			y.visit_expr(node.subject)
			for case in node.cases {
				y.visit_pattern(case.pattern)
				if guard := case.guard {
					y.visit_expr(guard)
				}
				y.visit_block(case.body)
			}
		}
		ast.Assign {
			for target in node.targets {
				y.visit_expr(target)
			}
			y.visit_expr(node.value)
		}
		ast.AugAssign {
			y.visit_expr(node.target)
			y.visit_expr(node.value)
		}
		ast.AnnAssign {
			y.visit_expr(node.target)
			y.visit_expr(node.annotation)
			if value := node.value {
				y.visit_expr(value)
			}
		}
		ast.Return {
			if value := node.value {
				y.visit_expr(value)
			}
		}
		ast.Assert {
			y.visit_expr(node.test)
			if msg := node.msg {
				y.visit_expr(msg)
			}
		}
		ast.Raise {
			if exc := node.exc {
				y.visit_expr(exc)
			}
			if cause := node.cause {
				y.visit_expr(cause)
			}
		}
		ast.Delete {
			for target in node.targets {
				y.visit_expr(target)
			}
		}
		ast.TypeAlias {
			y.visit_expr(node.value)
		}
		else {}
	}
}

fn (mut y YieldFinder) visit_pattern(node ast.Pattern) {
	match node {
		ast.MatchValue {
			y.visit_expr(node.value)
		}
		ast.MatchSequence {
			for pat in node.patterns {
				y.visit_pattern(pat)
			}
		}
		ast.MatchMapping {
			for key in node.keys {
				y.visit_expr(key)
			}
			for pat in node.patterns {
				y.visit_pattern(pat)
			}
		}
		ast.MatchClass {
			y.visit_expr(node.cls)
			for pat in node.patterns {
				y.visit_pattern(pat)
			}
			for pat in node.kwd_patterns {
				y.visit_pattern(pat)
			}
		}
		ast.MatchAs {
			if pat := node.pattern {
				y.visit_pattern(pat)
			}
		}
		ast.MatchOr {
			for pat in node.patterns {
				y.visit_pattern(pat)
			}
		}
		else {}
	}
}

fn (mut y YieldFinder) visit_expr(node ast.Expression) {
	if y.found {
		return
	}
	match node {
		ast.List {
			for elt in node.elements {
				y.visit_expr(elt)
			}
		}
		ast.Tuple {
			for elt in node.elements {
				y.visit_expr(elt)
			}
		}
		ast.Set {
			for elt in node.elements {
				y.visit_expr(elt)
			}
		}
		ast.Dict {
			for key in node.keys {
				y.visit_expr(key)
			}
			for value in node.values {
				y.visit_expr(value)
			}
		}
		ast.BinaryOp {
			y.visit_expr(node.left)
			y.visit_expr(node.right)
		}
		ast.UnaryOp {
			y.visit_expr(node.operand)
		}
		ast.Compare {
			y.visit_expr(node.left)
			for expr in node.comparators {
				y.visit_expr(expr)
			}
		}
		ast.Call {
			y.visit_expr(node.func)
			for arg in node.args {
				y.visit_expr(arg)
			}
			for kw in node.keywords {
				y.visit_expr(kw.value)
			}
		}
		ast.Attribute {
			y.visit_expr(node.value)
		}
		ast.Subscript {
			y.visit_expr(node.value)
			y.visit_expr(node.slice)
		}
		ast.Slice {
			if lower := node.lower {
				y.visit_expr(lower)
			}
			if upper := node.upper {
				y.visit_expr(upper)
			}
			if step := node.step {
				y.visit_expr(step)
			}
		}
		ast.Lambda {
			y.visit_expr(node.body)
		}
		ast.ListComp {
			y.visit_expr(node.elt)
		}
		ast.DictComp {
			y.visit_expr(node.key)
			y.visit_expr(node.value)
		}
		ast.SetComp {
			y.visit_expr(node.elt)
		}
		ast.GeneratorExp {
			y.visit_expr(node.elt)
		}
		ast.Await {
			y.visit_expr(node.value)
		}
		ast.Yield {
			y.found = true
		}
		ast.YieldFrom {
			y.found = true
		}
		ast.Starred {
			y.visit_expr(node.value)
		}
		ast.IfExp {
			y.visit_expr(node.test)
			y.visit_expr(node.body)
			y.visit_expr(node.orelse)
		}
		ast.NamedExpr {
			y.visit_expr(node.target)
			y.visit_expr(node.value)
		}
		ast.JoinedStr {
			for value in node.values {
				y.visit_expr(value)
			}
		}
		ast.FormattedValue {
			y.visit_expr(node.value)
			if spec := node.format_spec {
				y.visit_expr(spec)
			}
		}
		else {}
	}
}

pub struct CoroutineHandler {
pub mut:
	generators       map[string]string
	active_channel   ?string
	active_in_channel ?string
	temp_var_counter int
}

pub fn new_coroutine_handler() CoroutineHandler {
	return CoroutineHandler{
		generators:       map[string]string{}
		active_channel:   none
		active_in_channel: none
		temp_var_counter:  0
	}
}

pub fn (mut c CoroutineHandler) scan_module(node ast.Module) {
	mut finder := new_yield_finder()
	for stmt in node.body {
		c.scan_statement(stmt, mut finder)
	}
}

fn (mut c CoroutineHandler) scan_statement(node ast.Statement, mut finder YieldFinder) {
	match node {
		ast.FunctionDef {
			if c.has_yield(node, mut finder) {
				c.generators[node.name] = c.get_yield_type(node)
			}
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.ClassDef {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.If {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
			for stmt in node.orelse {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.While {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
			for stmt in node.orelse {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.For {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
			for stmt in node.orelse {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.With {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.Try {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
			for handler in node.handlers {
				for stmt in handler.body {
					c.scan_statement(stmt, mut finder)
				}
			}
			for stmt in node.orelse {
				c.scan_statement(stmt, mut finder)
			}
			for stmt in node.finalbody {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.TryStar {
			for stmt in node.body {
				c.scan_statement(stmt, mut finder)
			}
			for handler in node.handlers {
				for stmt in handler.body {
					c.scan_statement(stmt, mut finder)
				}
			}
			for stmt in node.orelse {
				c.scan_statement(stmt, mut finder)
			}
			for stmt in node.finalbody {
				c.scan_statement(stmt, mut finder)
			}
		}
		ast.Match {
			for case in node.cases {
				for stmt in case.body {
					c.scan_statement(stmt, mut finder)
				}
			}
		}
		else {}
	}
}

fn (mut c CoroutineHandler) has_yield(node ast.FunctionDef, mut finder YieldFinder) bool {
	return finder.has_yield_in_function(node)
}

pub fn (c CoroutineHandler) is_generator(name string) bool {
	return name in c.generators
}

pub fn (mut c CoroutineHandler) enter_generator(channel_name string, in_channel_name string) {
	c.active_channel = channel_name
	c.active_in_channel = in_channel_name
}

pub fn (mut c CoroutineHandler) exit_generator() {
	c.active_channel = none
	c.active_in_channel = none
}

pub fn (mut c CoroutineHandler) get_temp_channel_name() string {
	c.temp_var_counter++
	return 'ch_${c.temp_var_counter}'
}

pub fn (c CoroutineHandler) get_yield_type(node ast.FunctionDef) string {
	if node.returns == none {
		return 'int'
	}
	ret := node.returns or { return 'int' }
	if ret is ast.Subscript {
		base := ret.value
		if base is ast.Name && base.id in ['Iterator', 'Generator', 'Iterable'] {
			if ret.slice is ast.Tuple {
				tup := ret.slice
				if tup.elements.len > 0 {
					return map_type(tup.elements[0])
				}
			}
			return map_type(ret.slice)
		}
	}
	return 'int'
}

fn map_type(node ast.Expression) string {
	match node {
		ast.Name {
			return match node.id {
				'str' { 'string' }
				'int' { 'int' }
				'bool' { 'bool' }
				'float' { 'f64' }
				else { node.id }
			}
		}
		ast.Constant {
			return match node.value {
				'str' { 'string' }
				'int' { 'int' }
				'bool' { 'bool' }
				'float' { 'f64' }
				else { node.value }
			}
		}
		else {
			return 'int'
		}
	}
}
