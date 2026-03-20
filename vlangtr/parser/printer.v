module main

// ==================== AST PRINTER ====================

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
	p.output += p.indent() + s + '\n'
}

fn (mut p Printer) visit_module(node &Module) {
	p.writeln('Module(filename="${node.filename}")')
	p.indent_level++
	for stmt in node.body {
		walk_stmt(mut p, stmt)
	}
	p.indent_level--
}

fn (mut p Printer) visit_expression_stmt(node &ExpressionStmt) {
	p.writeln('ExpressionStmt')
	p.indent_level++
	walk_expr(mut p, node.expression)
	p.indent_level--
}

fn (mut p Printer) visit_function_def(node &FunctionDef) {
	async_str := if node.is_async { 'async ' } else { '' }
	p.writeln('${async_str}FunctionDef name="${node.name}"')
	p.indent_level++
	for dec in node.decorators {
		p.writeln('@decorator')
		p.indent_level++
		walk_expr(mut p, dec)
		p.indent_level--
	}
	for param in node.params {
		mut kind_str := ''
		match param.kind {
			.var_positional { kind_str = '*' }
			.var_keyword    { kind_str = '**' }
			.keyword_only   { kind_str = 'kw-only ' }
			else             {}
		}
		p.writeln('Param: ${kind_str}${param.name}')
	}
	if ret := node.returns {
		p.writeln('returns:')
		p.indent_level++
		walk_expr(mut p, ret)
		p.indent_level--
	}
	p.writeln('body:')
	p.indent_level++
	for stmt in node.body { walk_stmt(mut p, stmt) }
	p.indent_level--
	p.indent_level--
}

fn (mut p Printer) visit_class_def(node &ClassDef) {
	p.writeln('ClassDef name="${node.name}"')
	p.indent_level++
	for b in node.bases {
		p.writeln('base:')
		p.indent_level++
		walk_expr(mut p, b)
		p.indent_level--
	}
	for stmt in node.body { walk_stmt(mut p, stmt) }
	p.indent_level--
}

fn (mut p Printer) visit_if(node &If) {
	p.writeln('If')
	p.indent_level++
	p.writeln('test:')
	p.indent_level++
	walk_expr(mut p, node.test)
	p.indent_level--
	p.writeln('body:')
	p.indent_level++
	for s in node.body { walk_stmt(mut p, s) }
	p.indent_level--
	if node.orelse.len > 0 {
		p.writeln('else:')
		p.indent_level++
		for s in node.orelse { walk_stmt(mut p, s) }
		p.indent_level--
	}
	p.indent_level--
}

fn (mut p Printer) visit_for(node &For) {
	async_str := if node.is_async { 'async ' } else { '' }
	p.writeln('${async_str}For')
	p.indent_level++
	p.writeln('target:')
	p.indent_level++
	walk_expr(mut p, node.target)
	p.indent_level--
	p.writeln('iter:')
	p.indent_level++
	walk_expr(mut p, node.iter)
	p.indent_level--
	p.writeln('body:')
	p.indent_level++
	for s in node.body { walk_stmt(mut p, s) }
	p.indent_level--
	p.indent_level--
}

fn (mut p Printer) visit_while(node &While) {
	p.writeln('While')
	p.indent_level++
	walk_expr(mut p, node.test)
	for s in node.body { walk_stmt(mut p, s) }
	p.indent_level--
}

fn (mut p Printer) visit_with(node &With) {
	async_str := if node.is_async { 'async ' } else { '' }
	p.writeln('${async_str}With')
	p.indent_level++
	for item in node.items {
		p.writeln('context:')
		p.indent_level++
		walk_expr(mut p, item.context_expr)
		p.indent_level--
	}
	for s in node.body { walk_stmt(mut p, s) }
	p.indent_level--
}

fn (mut p Printer) visit_try(node &Try) {
	p.writeln('Try')
	p.indent_level++
	p.writeln('body:')
	p.indent_level++
	for s in node.body { walk_stmt(mut p, s) }
	p.indent_level--
	for h in node.handlers {
		p.writeln('except:')
		p.indent_level++
		if t := h.typ { walk_expr(mut p, t) }
		for s in h.body { walk_stmt(mut p, s) }
		p.indent_level--
	}
	if node.orelse.len > 0 {
		p.writeln('else:')
		p.indent_level++
		for s in node.orelse { walk_stmt(mut p, s) }
		p.indent_level--
	}
	if node.finalbody.len > 0 {
		p.writeln('finally:')
		p.indent_level++
		for s in node.finalbody { walk_stmt(mut p, s) }
		p.indent_level--
	}
	p.indent_level--
}

fn (mut p Printer) visit_match(node &Match) {
	p.writeln('Match')
	p.indent_level++
	walk_expr(mut p, node.subject)
	for c in node.cases {
		p.writeln('case:')
		p.indent_level++
		p.writeln(c.pattern.str())
		for s in c.body { walk_stmt(mut p, s) }
		p.indent_level--
	}
	p.indent_level--
}

fn (mut p Printer) visit_assignment(node &Assignment) {
	p.writeln('Assignment')
	p.indent_level++
	p.writeln('targets:')
	p.indent_level++
	for t in node.targets { walk_expr(mut p, t) }
	p.indent_level--
	p.writeln('value:')
	p.indent_level++
	walk_expr(mut p, node.value)
	p.indent_level--
	p.indent_level--
}

fn (mut p Printer) visit_aug_assignment(node &AugmentedAssignment) {
	p.writeln('AugAssignment op="${node.operator.value}"')
	p.indent_level++
	walk_expr(mut p, node.target)
	walk_expr(mut p, node.value)
	p.indent_level--
}

fn (mut p Printer) visit_ann_assignment(node &AnnAssignment) {
	p.writeln('AnnAssignment')
	p.indent_level++
	walk_expr(mut p, node.target)
	walk_expr(mut p, node.annotation)
	if v := node.value { walk_expr(mut p, v) }
	p.indent_level--
}

fn (mut p Printer) visit_return(node &Return) {
	p.writeln('Return')
	if v := node.value {
		p.indent_level++
		walk_expr(mut p, v)
		p.indent_level--
	}
}

fn (mut p Printer) visit_import(node &Import) {
	names := node.names.map(it.name).join(', ')
	p.writeln('Import(${names})')
}

fn (mut p Printer) visit_import_from(node &ImportFrom) {
	names := node.names.map(it.name).join(', ')
	p.writeln('ImportFrom module="${node.module}" names=[${names}]')
}

fn (mut p Printer) visit_global(node &Global) {
	p.writeln('Global(${node.names.join(', ')})')
}

fn (mut p Printer) visit_nonlocal(node &Nonlocal) {
	p.writeln('Nonlocal(${node.names.join(', ')})')
}

fn (mut p Printer) visit_assert(node &Assert) {
	p.writeln('Assert')
	p.indent_level++
	walk_expr(mut p, node.test)
	p.indent_level--
}

fn (mut p Printer) visit_raise(node &Raise) {
	p.writeln('Raise')
	if e := node.exception {
		p.indent_level++
		walk_expr(mut p, e)
		p.indent_level--
	}
}

fn (mut p Printer) visit_try_handler(node &ExceptHandler) {
	p.writeln('ExceptHandler')
}

fn (mut p Printer) visit_delete(node &Delete) {
	p.writeln('Delete')
	p.indent_level++
	for t in node.targets { walk_expr(mut p, t) }
	p.indent_level--
}

fn (mut p Printer) visit_pass(node &Pass) {
	p.writeln('Pass')
}

fn (mut p Printer) visit_break(node &Break) {
	p.writeln('Break')
}

fn (mut p Printer) visit_continue(node &Continue) {
	p.writeln('Continue')
}

fn (mut p Printer) visit_binary_op(node &BinaryOp) {
	p.writeln('BinaryOp op="${node.operator.value}"')
	p.indent_level++
	walk_expr(mut p, node.left)
	walk_expr(mut p, node.right)
	p.indent_level--
}

fn (mut p Printer) visit_unary_op(node &UnaryOp) {
	p.writeln('UnaryOp op="${node.operator.value}"')
	p.indent_level++
	walk_expr(mut p, node.operand)
	p.indent_level--
}

fn (mut p Printer) visit_compare(node &Compare) {
	ops := node.operators.map(it.value).join(', ')
	p.writeln('Compare ops=[${ops}]')
	p.indent_level++
	walk_expr(mut p, node.left)
	for c in node.comparators { walk_expr(mut p, c) }
	p.indent_level--
}

fn (mut p Printer) visit_call(node &Call) {
	p.writeln('Call')
	p.indent_level++
	walk_expr(mut p, node.func)
	for arg in node.args {
		p.writeln('arg:')
		p.indent_level++
		walk_expr(mut p, arg)
		p.indent_level--
	}
	for kw in node.keywords {
		p.writeln('kwarg ${kw.name}=')
		p.indent_level++
		walk_expr(mut p, kw.value)
		p.indent_level--
	}
	p.indent_level--
}

fn (mut p Printer) visit_identifier(node &Identifier) {
	p.writeln('Identifier "${node.name}"')
}

fn (mut p Printer) visit_number(node &NumberLiteral) {
	p.writeln('Number(${node.raw})')
}

fn (mut p Printer) visit_string(node &StringLiteral) {
	p.writeln("String('${node.value}')")
}

fn (mut p Printer) visit_bool(node &BoolLiteral) {
	p.writeln('Bool(${node.value})')
}

fn (mut p Printer) visit_none(node &NoneLiteral) {
	p.writeln('None')
}

fn (mut p Printer) visit_list(node &ListLiteral) {
	p.writeln('List(len=${node.elements.len})')
	p.indent_level++
	for e in node.elements { walk_expr(mut p, e) }
	p.indent_level--
}

fn (mut p Printer) visit_dict(node &DictLiteral) {
	p.writeln('Dict(len=${node.pairs.len})')
	p.indent_level++
	for pair in node.pairs {
		p.writeln('key:')
		p.indent_level++
		walk_expr(mut p, pair.key)
		p.indent_level--
		p.writeln('val:')
		p.indent_level++
		walk_expr(mut p, pair.value)
		p.indent_level--
	}
	p.indent_level--
}

fn (mut p Printer) visit_tuple(node &TupleLiteral) {
	p.writeln('Tuple(len=${node.elements.len})')
	p.indent_level++
	for e in node.elements { walk_expr(mut p, e) }
	p.indent_level--
}

fn (mut p Printer) visit_set(node &SetLiteral) {
	p.writeln('Set(len=${node.elements.len})')
	p.indent_level++
	for e in node.elements { walk_expr(mut p, e) }
	p.indent_level--
}

fn (mut p Printer) visit_attribute(node &Attribute) {
	p.writeln('Attribute .${node.attr}')
	p.indent_level++
	walk_expr(mut p, node.value)
	p.indent_level--
}

fn (mut p Printer) visit_subscript(node &Subscript) {
	p.writeln('Subscript')
	p.indent_level++
	walk_expr(mut p, node.value)
	walk_expr(mut p, node.slice)
	p.indent_level--
}

fn (mut p Printer) visit_slice(node &Slice) {
	p.writeln('Slice')
	p.indent_level++
	if lo := node.lower { walk_expr(mut p, lo) }
	if hi := node.upper { walk_expr(mut p, hi) }
	if st := node.step  { walk_expr(mut p, st) }
	p.indent_level--
}

fn (mut p Printer) visit_lambda(node &Lambda) {
	p.writeln('Lambda')
	p.indent_level++
	walk_expr(mut p, node.body)
	p.indent_level--
}

fn (mut p Printer) visit_list_comp(node &ListComp) {
	p.writeln('ListComp')
	p.indent_level++
	walk_expr(mut p, node.elt)
	p.indent_level--
}

fn (mut p Printer) visit_dict_comp(node &DictComp) {
	p.writeln('DictComp')
	p.indent_level++
	walk_expr(mut p, node.key)
	walk_expr(mut p, node.value)
	p.indent_level--
}

fn (mut p Printer) visit_set_comp(node &SetComp) {
	p.writeln('SetComp')
	p.indent_level++
	walk_expr(mut p, node.elt)
	p.indent_level--
}

fn (mut p Printer) visit_generator(node &GeneratorExp) {
	p.writeln('GeneratorExp')
	p.indent_level++
	walk_expr(mut p, node.elt)
	p.indent_level--
}

fn (mut p Printer) visit_if_expr(node &IfExpr) {
	p.writeln('IfExpr')
	p.indent_level++
	p.writeln('test:')
	p.indent_level++
	walk_expr(mut p, node.test)
	p.indent_level--
	p.writeln('body:')
	p.indent_level++
	walk_expr(mut p, node.body)
	p.indent_level--
	p.writeln('else:')
	p.indent_level++
	walk_expr(mut p, node.orelse)
	p.indent_level--
	p.indent_level--
}

fn (mut p Printer) visit_await(node &Await) {
	p.writeln('Await')
	p.indent_level++
	walk_expr(mut p, node.value)
	p.indent_level--
}

fn (mut p Printer) visit_yield(node &Yield) {
	p.writeln('Yield')
	if v := node.value {
		p.indent_level++
		walk_expr(mut p, v)
		p.indent_level--
	}
}

fn (mut p Printer) visit_yield_from(node &YieldFrom) {
	p.writeln('YieldFrom')
	p.indent_level++
	walk_expr(mut p, node.value)
	p.indent_level--
}

fn (mut p Printer) visit_starred(node &StarredExpr) {
	p.writeln('Starred')
	p.indent_level++
	walk_expr(mut p, node.value)
	p.indent_level--
}
