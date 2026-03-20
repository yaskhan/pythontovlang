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
	p.write(p.indent() + 'args=arguments(),\n') // simplifed
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
	p.write(p.indent() + 'decorator_list=[],\n')
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
	p.write(p.indent() + 'bases=[],\n')
	p.write(p.indent() + 'keywords=[],\n')
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
	p.write(p.indent() + 'decorator_list=[])')
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
	p.write(p.indent() + 'keywords=[])')
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
		'is' { return 'Is()' }
		'in' { return 'In()' }
		else { return 'UnknownOp()' }
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
fn (mut p Printer) visit_with(node &With) { p.write('With(...)') }
fn (mut p Printer) visit_try(node &Try) { p.write('Try(...)') }
fn (mut p Printer) visit_match(node &Match) { p.write('Match(...)') }
fn (mut p Printer) visit_aug_assign(node &AugAssign) { p.write('AugAssign(...)') }
fn (mut p Printer) visit_return(node &Return) { p.write('Return(...)') }
fn (mut p Printer) visit_import(node &Import) { p.write('Import(...)') }
fn (mut p Printer) visit_import_from(node &ImportFrom) { p.write('ImportFrom(...)') }
fn (mut p Printer) visit_global(node &Global) { p.write('Global(...)') }
fn (mut p Printer) visit_nonlocal(node &Nonlocal) { p.write('Nonlocal(...)') }
fn (mut p Printer) visit_assert(node &Assert) { p.write('Assert(...)') }
fn (mut p Printer) visit_raise(node &Raise) { p.write('Raise(...)') }
fn (mut p Printer) visit_delete(node &Delete) { p.write('Delete(...)') }
fn (mut p Printer) visit_pass(node &Pass) { p.write('Pass()') }
fn (mut p Printer) visit_break(node &Break) { p.write('Break()') }
fn (mut p Printer) visit_continue(node &Continue) { p.write('Continue()') }
fn (mut p Printer) visit_subscript(node &Subscript) { p.write('Subscript(...)') }
fn (mut p Printer) visit_slice(node &Slice) { p.write('Slice(...)') }
fn (mut p Printer) visit_lambda(node &Lambda) { p.write('Lambda(...)') }
fn (mut p Printer) visit_list_comp(node &ListComp) { p.write('ListComp(...)') }
fn (mut p Printer) visit_dict_comp(node &DictComp) { p.write('DictComp(...)') }
fn (mut p Printer) visit_set_comp(node &SetComp) { p.write('SetComp(...)') }
fn (mut p Printer) visit_generator(node &GeneratorExp) { p.write('GeneratorExp(...)') }
fn (mut p Printer) visit_if_exp(node &IfExp) { p.write('IfExp(...)') }
fn (mut p Printer) visit_await(node &Await) { p.write('Await(...)') }
fn (mut p Printer) visit_yield(node &Yield) { p.write('Yield(...)') }
fn (mut p Printer) visit_yield_from(node &YieldFrom) { p.write('YieldFrom(...)') }
fn (mut p Printer) visit_starred(node &Starred) { p.write('Starred(...)') }
