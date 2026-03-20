module main

// ==================== AST PRINTER ====================
// Matches Python's ast.dump(..., indent=2) style

struct Printer {
mut:
	indent_level int
	output       string
}

fn (mut p Printer) indent() string {
	return '  '.repeat(p.indent_level)
}

fn (mut p Printer) write(s string) {
	p.output += s
}

fn (mut p Printer) writeln(s string) {
	p.output += s + '\n'
}

fn (mut p Printer) visit_module(node &Module) {
	p.write('Module(\n')
	p.indent_level++
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, stmt in node.body {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.body.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '])\n')
	p.indent_level--
}

fn (mut p Printer) visit_expr(node &Expr) {
	p.write('Expr(\n')
	p.indent_level++
	p.write(p.indent() + 'value=')
	walk_expr(mut p, node.value)
	p.write(')')
	p.indent_level--
}

fn (mut p Printer) visit_function_def(node &FunctionDef) {
	p.write('FunctionDef(\n')
	p.indent_level++
	p.write(p.indent() + 'name=\'${node.name}\',\n')
	p.write(p.indent() + 'args=')
	p.visit_arguments(node.args)
	p.write(',\n')
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, s in node.body {
		p.write(p.indent())
		walk_stmt(mut p, s)
		if i < node.body.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'decorator_list=[\n')
	p.indent_level++
	for i, dec in node.decorator_list {
		p.write(p.indent())
		walk_expr(mut p, dec)
		if i < node.decorator_list.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'returns=')
	if ret := node.returns {
		walk_expr(mut p, ret)
	} else {
		p.write('None')
	}
	p.write(')')
	p.indent_level--
}

fn (mut p Printer) visit_class_def(node &ClassDef) {
	p.write('ClassDef(\n')
	p.indent_level++
	p.write(p.indent() + 'name=\'${node.name}\',\n')
	p.write(p.indent() + 'bases=[\n')
	p.indent_level++
	for i, b in node.bases {
		p.write(p.indent())
		walk_expr(mut p, b)
		if i < node.bases.len - 1 {
			p.write(',')
		}
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'keywords=[\n')
	p.indent_level++
	for i, kw in node.keywords {
		p.write(p.indent() + 'keyword(arg=\'${kw.arg}\', value=')
		walk_expr(mut p, kw.value)
		p.write(')')
		if i < node.keywords.len - 1 {
			p.write(',')
		}
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, s in node.body {
		p.write(p.indent())
		walk_stmt(mut p, s)
		if i < node.body.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'decorator_list=[\n')
	p.indent_level++
	for i, dec in node.decorator_list {
		p.write(p.indent())
		walk_expr(mut p, dec)
		if i < node.decorator_list.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '])')
	p.indent_level--
}

fn (mut p Printer) visit_if(node &If) {
	p.write('If(\n')
	p.indent_level++
	p.write(p.indent() + 'test=')
	walk_expr(mut p, node.test)
	p.write(',\n')
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, s in node.body {
		p.write(p.indent())
		walk_stmt(mut p, s)
		if i < node.body.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'orelse=[])')
	p.indent_level--
}

fn (mut p Printer) visit_assign(node &Assign) {
	p.write('Assign(\n')
	p.indent_level++
	p.write(p.indent() + 'targets=[\n')
	p.indent_level++
	for i, t in node.targets {
		p.write(p.indent())
		walk_expr(mut p, t)
		if i < node.targets.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'value=')
	walk_expr(mut p, node.value)
	p.write(')')
	p.indent_level--
}

fn (mut p Printer) visit_ann_assign(node &AnnAssign) {
	p.write('AnnAssign(\n')
	p.indent_level++
	p.write(p.indent() + 'target=')
	walk_expr(mut p, node.target)
	p.write(',\n')
	p.write(p.indent() + 'annotation=')
	walk_expr(mut p, node.annotation)
	p.write(',\n')
	p.write(p.indent() + 'value=')
	if v := node.value { walk_expr(mut p, v) } else { p.write('None') }
	p.write(',\n')
	p.write(p.indent() + 'simple=${node.simple})')
	p.indent_level--
}

fn (mut p Printer) visit_name(node &Name) {
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write('Name(id=\'${node.id}\', ctx=${ctx_str})')
}

fn (mut p Printer) visit_constant(node &Constant) {
	p.write('Constant(value=${node.value})')
}

fn (mut p Printer) visit_none_expr(node &NoneExpr) {
	p.write('None')
}

fn (mut p Printer) visit_attribute(node &Attribute) {
	p.write('Attribute(\n')
	p.indent_level++
	p.write(p.indent() + 'value=')
	walk_expr(mut p, node.value)
	p.write(',\n')
	p.write(p.indent() + 'attr=\'${node.attr}\',\n')
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write(p.indent() + 'ctx=${ctx_str})')
	p.indent_level--
}

fn (mut p Printer) visit_call(node &Call) {
	p.write('Call(\n')
	p.indent_level++
	p.write(p.indent() + 'func=')
	walk_expr(mut p, node.func)
	p.write(',\n')
	p.write(p.indent() + 'args=[\n')
	p.indent_level++
	for i, arg in node.args {
		p.write(p.indent())
		walk_expr(mut p, arg)
		if i < node.args.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '],\n')
	p.write(p.indent() + 'keywords=[')
	if node.keywords.len > 0 {
		p.write('\n')
		p.indent_level++
		for i, kw in node.keywords {
			p.write(p.indent() + 'keyword(')
			if kw.arg != '' && kw.arg != '**' {
				p.write('arg=\'${kw.arg}\', ')
			}
			p.write('value=')
			walk_expr(mut p, kw.value)
			p.write(')')
			if i < node.keywords.len - 1 {
				p.write(',\n')
			}
		}
		p.indent_level--
		p.write('\n' + p.indent())
	}
	p.write('])')
	p.indent_level--
}

fn (mut p Printer) visit_compare(node &Compare) {
	p.write('Compare(\n')
	p.indent_level++
	p.write(p.indent() + 'left=')
	walk_expr(mut p, node.left)
	p.write(',\n')
	p.write(p.indent() + 'ops=[')
	for i, op in node.ops {
		p.write(op_to_ast(op))
		if i < node.ops.len - 1 { p.write(', ') }
	}
	p.write('],\n')
	p.write(p.indent() + 'comparators=[\n')
	p.indent_level++
	for i, c in node.comparators {
		p.write(p.indent())
		walk_expr(mut p, c)
		if i < node.comparators.len - 1 { p.write(',') }
		p.write('\n')
	}
	p.indent_level--
	p.write(p.indent() + '])')
	p.indent_level--
}

fn op_to_ast(tok Token) string {
	match tok.value {
		'==' { return 'Eq()' }
		'!=' { return 'NotEq()' }
		'<'  { return 'Lt()' }
		'<=' { return 'LtE()' }
		'>'  { return 'Gt()' }
		'>=' { return 'GtE()' }
		'is'     { return 'Is()' }
		'is not' { return 'IsNot()' }
		'in'     { return 'In()' }
		'not in' { return 'NotIn()' }
		else     { return 'UnknownOp()' }
	}
}


fn (mut p Printer) visit_binary_op(node &BinaryOp) {
	p.write('BinOp(\n')
	p.indent_level++
	p.write(p.indent() + 'left=')
	walk_expr(mut p, node.left)
	p.write(',\n')
	p.write(p.indent() + 'op=${node.op.value}(),\n')
	p.write(p.indent() + 'right=')
	walk_expr(mut p, node.right)
	p.write(')')
	p.indent_level--
}
fn (mut p Printer) visit_unary_op(node &UnaryOp) { p.write('UnaryOp(...)') }
fn (mut p Printer) visit_list(node &List) {
	p.write('List(\n')
	p.indent_level++
	p.write(p.indent() + 'elts=[\n')
	p.indent_level++
	for i, elt in node.elements {
		p.write(p.indent())
		walk_expr(mut p, elt)
		if i < node.elements.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write(p.indent() + 'ctx=${ctx_str})')
	p.indent_level--
}

fn (mut p Printer) visit_dict(node &Dict) {
	p.write('Dict(\n')
	p.indent_level++
	p.write(p.indent() + 'keys=[\n')
	p.indent_level++
	for i, k in node.keys {
		p.write(p.indent())
		walk_expr(mut p, k)
		if i < node.keys.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'values=[\n')
	p.indent_level++
	for i, v in node.values {
		p.write(p.indent())
		walk_expr(mut p, v)
		if i < node.values.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}

fn (mut p Printer) visit_tuple(node &Tuple) {
	p.write('Tuple(\n')
	p.indent_level++
	p.write(p.indent() + 'elts=[\n')
	p.indent_level++
	for i, elt in node.elements {
		p.write(p.indent())
		walk_expr(mut p, elt)
		if i < node.elements.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write(p.indent() + 'ctx=${ctx_str})')
	p.indent_level--
}

fn (mut p Printer) visit_set(node &Set) {
	p.write('Set(\n')
	p.indent_level++
	p.write(p.indent() + 'elts=[\n')
	p.indent_level++
	for i, elt in node.elements {
		p.write(p.indent())
		walk_expr(mut p, elt)
		if i < node.elements.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}
// Fallback for other nodes to keep it compiling
fn (mut p Printer) visit_for(node &For) {
	name := if node.is_async { 'AsyncFor' } else { 'For' }
	p.write('${name}(\n')
	p.indent_level++
	p.write(p.indent() + 'target=')
	walk_expr(mut p, node.target)
	p.write(',\n')
	p.write(p.indent() + 'iter=')
	walk_expr(mut p, node.iter)
	p.write(',\n')
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, stmt in node.body {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.body.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'orelse=[\n')
	p.indent_level++
	for i, stmt in node.orelse {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.orelse.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}

fn (mut p Printer) visit_while(node &While) {
	p.write('While(\n')
	p.indent_level++
	p.write(p.indent() + 'test=')
	walk_expr(mut p, node.test)
	p.write(',\n')
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, stmt in node.body {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.body.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'orelse=[\n')
	p.indent_level++
	for i, stmt in node.orelse {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.orelse.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}
fn (mut p Printer) visit_if_exp(node &IfExp) {
	p.write('IfExp(\n')
	p.indent_level++
	p.write(p.indent() + 'test=')
	walk_expr(mut p, node.test)
	p.write(',\n')
	p.write(p.indent() + 'body=')
	walk_expr(mut p, node.body)
	p.write(',\n')
	p.write(p.indent() + 'orelse=')
	walk_expr(mut p, node.orelse)
	p.write(')')
	p.indent_level--
}
fn (mut p Printer) visit_pass(node &Pass) { p.write('Pass()') }
fn (mut p Printer) visit_break(node &Break) { p.write('Break()') }
fn (mut p Printer) visit_continue(node &Continue) { p.write('Continue()') }
fn (mut p Printer) visit_import(node &Import) {
	p.write('Import(names=[\n')
	p.indent_level++
	for i, alias in node.names {
		p.write(p.indent() + 'alias(name=\'${alias.name}\'')
		if asname := alias.asname {
			p.write(', asname=\'${asname}\'')
		}
		p.write(')')
		if i < node.names.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_import_from(node &ImportFrom) {
	p.write('ImportFrom(\n')
	p.indent_level++
	p.write(p.indent() + 'module=\'${node.module}\',\n')
	p.write(p.indent() + 'names=[\n')
	p.indent_level++
	for i, alias in node.names {
		p.write(p.indent() + 'alias(name=\'${alias.name}\'')
		if asname := alias.asname {
			p.write(', asname=\'${asname}\'')
		}
		p.write(')')
		if i < node.names.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'level=${node.level})')
	p.indent_level--
}
fn (mut p Printer) visit_with(node &With) {
	name := if node.is_async { 'AsyncWith' } else { 'With' }
	p.write('${name}(items=[\n')
	p.indent_level++
	for i, item in node.items {
		p.write(p.indent() + 'withitem(\n')
		p.indent_level++
		p.write(p.indent() + 'context_expr=')
		walk_expr(mut p, item.context_expr)
		p.write(',\n')
		p.write(p.indent() + 'optional_vars=')
		if opt := item.optional_vars {
			walk_expr(mut p, opt)
		} else {
			p.write('None')
		}
		p.write(')')
		p.indent_level--
		if i < node.items.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '], body=[\n')
	p.indent_level++
	for i, stmt in node.body {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.body.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_try(node &Try) {
	p.write('Try(\n')
	p.indent_level++
	p.write(p.indent() + 'body=[\n')
	p.indent_level++
	for i, stmt in node.body {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.body.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'handlers=[\n')
	p.indent_level++
	for i, h in node.handlers {
		p.write(p.indent() + 'ExceptHandler(')
		if t := h.typ {
			p.write('type=')
			walk_expr(mut p, t)
			if n := h.name {
				p.write(', name=\'${n}\'')
			}
		}
		p.write(', body=[\n')
		p.indent_level++
		for j, stmt in h.body {
			p.write(p.indent())
			walk_stmt(mut p, stmt)
			if j < h.body.len - 1 { p.write(',\n') }
		}
		p.indent_level--
		p.write('\n' + p.indent() + '])')
		if i < node.handlers.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'orelse=[\n')
	p.indent_level++
	for i, stmt in node.orelse {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.orelse.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'finalbody=[\n')
	p.indent_level++
	for i, stmt in node.finalbody {
		p.write(p.indent())
		walk_stmt(mut p, stmt)
		if i < node.finalbody.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}

fn (mut p Printer) visit_named_expr(node &NamedExpr) {
	p.write('NamedExpr(target=')
	walk_expr(mut p, node.target)
	p.write(', value=')
	walk_expr(mut p, node.value)
	p.write(')')
}

fn (mut p Printer) visit_match(node &Match) {
	p.write('Match(\n')
	p.indent_level++
	p.write(p.indent() + 'subject=')
	walk_expr(mut p, node.subject)
	p.write(',\n')
	p.write(p.indent() + 'cases=[\n')
	p.indent_level++
	for i, c in node.cases {
		p.write(p.indent() + 'match_case(\n')
		p.indent_level++
		p.write(p.indent() + 'pattern=')
		walk_pattern(mut p, c.pattern)
		p.write(',\n')
		p.write(p.indent() + 'guard=')
		if g := c.guard {
			walk_expr(mut p, g)
		} else {
			p.write('None')
		}
		p.write(',\n')
		p.write(p.indent() + 'body=[\n')
		p.indent_level++
		for j, stmt in c.body {
			p.write(p.indent())
			walk_stmt(mut p, stmt)
			if j < c.body.len - 1 { p.write(',\n') }
		}
		p.indent_level--
		p.write('\n' + p.indent() + '])')
		p.indent_level--
		if i < node.cases.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}

// Patterns
fn (mut p Printer) visit_match_value(node &MatchValue) {
	p.write('MatchValue(value=')
	walk_expr(mut p, node.value)
	p.write(')')
}

fn (mut p Printer) visit_match_singleton(node &MatchSingleton) {
	val := match node.value.value {
		'None' { 'None' }
		'True' { 'True' }
		'False' { 'False' }
		else { node.value.value }
	}
	p.write('MatchSingleton(value=${val})')
}

fn (mut p Printer) visit_match_sequence(node &MatchSequence) {
	p.write('MatchSequence(patterns=[\n')
	p.indent_level++
	for i, pattern in node.patterns {
		p.write(p.indent())
		walk_pattern(mut p, pattern)
		if i < node.patterns.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_match_mapping(node &MatchMapping) {
	p.write('MatchMapping(keys=[\n')
	p.indent_level++
	for i, k in node.keys {
		p.write(p.indent())
		walk_expr(mut p, k)
		if i < node.keys.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '], patterns=[\n')
	p.indent_level++
	for i, pat in node.patterns {
		p.write(p.indent())
		walk_pattern(mut p, pat)
		if i < node.patterns.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + ']')
	if r := node.rest {
		p.write(', rest=\'${r}\'')
	}
	p.write(')')
}

fn (mut p Printer) visit_match_class(node &MatchClass) {
	p.write('MatchClass(\n')
	p.indent_level++
	p.write(p.indent() + 'cls=')
	walk_expr(mut p, node.cls)
	p.write(',\n' + p.indent() + 'patterns=[\n')
	p.indent_level++
	for i, pat in node.patterns {
		p.write(p.indent())
		walk_pattern(mut p, pat)
		if i < node.patterns.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n' + p.indent() + 'kwd_attrs=[\n')
	p.indent_level++
	for i, attr in node.kwd_attrs {
		p.write(p.indent() + '\'${attr}\'')
		if i < node.kwd_attrs.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n' + p.indent() + 'kwd_patterns=[\n')
	p.indent_level++
	for i, pat in node.kwd_patterns {
		p.write(p.indent())
		walk_pattern(mut p, pat)
		if i < node.kwd_patterns.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
	p.indent_level--
}

fn (mut p Printer) visit_match_star(node &MatchStar) {
	p.write('MatchStar(name=\'${node.name or { '' }}\')')
}

fn (mut p Printer) visit_match_as(node &MatchAs) {
	p.write('MatchAs(')
	if pat := node.pattern {
		p.write('pattern=')
		walk_pattern(mut p, pat)
		if n := node.name {
			p.write(', name=\'${n}\'')
		}
	} else {
		if n := node.name {
			p.write('name=\'${n}\'')
		}
	}
	p.write(')')
}

fn (mut p Printer) visit_match_or(node &MatchOr) {
	p.write('MatchOr(patterns=[\n')
	p.indent_level++
	for i, pattern in node.patterns {
		p.write(p.indent())
		walk_pattern(mut p, pattern)
		if i < node.patterns.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}
fn (mut p Printer) visit_starred(node &Starred) {
	p.write('Starred(value=')
	walk_expr(mut p, node.value)
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write(', ctx=${ctx_str})')
}

fn (mut p Printer) visit_list_comp(node &ListComp) {
	p.write('ListComp(elt=')
	walk_expr(mut p, node.elt)
	p.write(', generators=[\n')
	p.indent_level++
	for i, gen in node.generators {
		p.print_comprehension(gen)
		if i < node.generators.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_dict_comp(node &DictComp) {
	p.write('DictComp(key=')
	walk_expr(mut p, node.key)
	p.write(', value=')
	walk_expr(mut p, node.value)
	p.write(', generators=[\n')
	p.indent_level++
	for i, gen in node.generators {
		p.print_comprehension(gen)
		if i < node.generators.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_set_comp(node &SetComp) {
	p.write('SetComp(elt=')
	walk_expr(mut p, node.elt)
	p.write(', generators=[\n')
	p.indent_level++
	for i, gen in node.generators {
		p.print_comprehension(gen)
		if i < node.generators.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_generator(node &GeneratorExp) {
	p.write('GeneratorExp(elt=')
	walk_expr(mut p, node.elt)
	p.write(', generators=[\n')
	p.indent_level++
	for i, gen in node.generators {
		p.print_comprehension(gen)
		if i < node.generators.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) print_comprehension(node Comprehension) {
	p.write(p.indent() + 'comprehension(target=')
	walk_expr(mut p, node.target)
	p.write(', iter=')
	walk_expr(mut p, node.iter)
	p.write(', ifs=[\n')
	p.indent_level++
	for j, if_ in node.ifs {
		p.write(p.indent())
		walk_expr(mut p, if_)
		if j < node.ifs.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '], is_async=${node.is_async})')
}

fn (mut p Printer) visit_slice(node &Slice) {
	p.write('Slice(')
	if l := node.lower {
		p.write('lower=')
		walk_expr(mut p, l)
		p.write(', ')
	} else {
		p.write('lower=None, ')
	}
	if u := node.upper {
		p.write('upper=')
		walk_expr(mut p, u)
		p.write(', ')
	} else {
		p.write('upper=None, ')
	}
	if s := node.step {
		p.write('step=')
		walk_expr(mut p, s)
	} else {
		p.write('step=None')
	}
	p.write(')')
}

fn (mut p Printer) visit_lambda(node &Lambda) {
	p.write('Lambda(args=')
	p.visit_arguments(node.args)
	p.write(', body=')
	walk_expr(mut p, node.body)
	p.write(')')
}

fn (mut p Printer) visit_arguments(args Arguments) {
	p.write('arguments(\n')
	p.indent_level++
	
	p.write(p.indent() + 'posonlyargs=[\n')
	p.indent_level++
	for i, arg in args.posonlyargs {
		p.write(p.indent())
		p.visit_parameter(arg)
		if i < args.posonlyargs.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')

	p.write(p.indent() + 'args=[\n')
	p.indent_level++
	for i, arg in args.args {
		p.write(p.indent())
		p.visit_parameter(arg)
		if i < args.args.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')
	p.write(p.indent() + 'vararg=')
	if va := args.vararg {
		p.visit_parameter(va)
	} else {
		p.write('None')
	}
	p.write(',\n')

	p.write(p.indent() + 'kwonlyargs=[\n')
	p.indent_level++
	for i, arg in args.kwonlyargs {
		p.write(p.indent())
		p.visit_parameter(arg)
		if i < args.kwonlyargs.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '],\n')

	p.write(p.indent() + 'kwarg=')
	if kwa := args.kwarg {
		p.visit_parameter(kwa)
	} else {
		p.write('None')
	}
	p.write(')')
	p.indent_level--
}

fn (mut p Printer) visit_parameter(arg Parameter) {
	p.write('arg(arg=\'${arg.arg}\'')
	if ann := arg.annotation {
		p.write(', annotation=')
		walk_expr(mut p, ann)
	}
	if def_ := arg.default_ {
		p.write(', default=')
		walk_expr(mut p, def_)
	}
	p.write(')')
}

fn (mut p Printer) visit_aug_assign(node &AugAssign) {
	p.write('AugAssign(target=')
	walk_expr(mut p, node.target)
	op_name := match node.op.value {
		'+=' { 'Add()' }
		'-=' { 'Sub()' }
		'*=' { 'Mult()' }
		'/=' { 'Div()' }
		'//=' { 'FloorDiv()' }
		'%=' { 'Mod()' }
		'**=' { 'Pow()' }
		'<<=' { 'LShift()' }
		'>>=' { 'RShift()' }
		'&=' { 'BitAnd()' }
		'|=' { 'BitOr()' }
		'^=' { 'BitXor()' }
		else { node.op.value }
	}
	p.write(', op=${op_name}, value=')
	walk_expr(mut p, node.value)
	p.write(')')
}

fn (mut p Printer) visit_return(node &Return) {
	p.write('Return(value=')
	if v := node.value {
		walk_expr(mut p, v)
	} else {
		p.write('None')
	}
	p.write(')')
}

fn (mut p Printer) visit_global(node &Global) {
	p.write('Global(names=${node.names})')
}

fn (mut p Printer) visit_nonlocal(node &Nonlocal) {
	p.write('Nonlocal(names=${node.names})')
}

fn (mut p Printer) visit_assert(node &Assert) {
	p.write('Assert(test=')
	walk_expr(mut p, node.test)
	if msg := node.msg {
		p.write(', msg=')
		walk_expr(mut p, msg)
	}
	p.write(')')
}

fn (mut p Printer) visit_raise(node &Raise) {
	p.write('Raise(')
	if exc := node.exc {
		p.write('exc=')
		walk_expr(mut p, exc)
		if cause := node.cause {
			p.write(', cause=')
			walk_expr(mut p, cause)
		}
	}
	p.write(')')
}

fn (mut p Printer) visit_delete(node &Delete) {
	p.write('Delete(targets=[\n')
	p.indent_level++
	for i, target in node.targets {
		p.write(p.indent())
		walk_expr(mut p, target)
		if i < node.targets.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_subscript(node &Subscript) {
	p.write('Subscript(value=')
	walk_expr(mut p, node.value)
	p.write(', slice=')
	walk_expr(mut p, node.slice)
	ctx_str := match node.ctx {
		.load  { 'Load()' }
		.store { 'Store()' }
		.del   { 'Del()' }
	}
	p.write(', ctx=${ctx_str})')
}

fn (mut p Printer) visit_await(node &Await) {
	p.write('Await(value=')
	walk_expr(mut p, node.value)
	p.write(')')
}

fn (mut p Printer) visit_yield(node &Yield) {
	p.write('Yield(value=')
	if v := node.value {
		walk_expr(mut p, v)
	} else {
		p.write('None')
	}
	p.write(')')
}

fn (mut p Printer) visit_yield_from(node &YieldFrom) {
	p.write('YieldFrom(value=')
	walk_expr(mut p, node.value)
	p.write(')')
}

fn (mut p Printer) visit_joined_str(node &JoinedStr) {
	p.write('JoinedStr(values=[\n')
	p.indent_level++
	for i, val in node.values {
		p.write(p.indent())
		walk_expr(mut p, val)
		if i < node.values.len - 1 { p.write(',\n') }
	}
	p.indent_level--
	p.write('\n' + p.indent() + '])')
}

fn (mut p Printer) visit_formatted_value(node &FormattedValue) {
	p.write('FormattedValue(value=')
	walk_expr(mut p, node.value)
	conversion_str := match node.conversion {
		115 { "'s'" }
		114 { "'r'" }
		97  { "'a'" }
		else { '-1' }
	}
	p.write(', conversion=${conversion_str}')
	if spec := node.format_spec {
		p.write(', format_spec=')
		walk_expr(mut p, spec)
	} else {
		p.write(', format_spec=None')
	}
	p.write(')')
}