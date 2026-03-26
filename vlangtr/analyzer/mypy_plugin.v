module analyzer

import json
import mypy

pub struct MypyCollectedMutability {
pub mut:
	is_reassigned bool
	is_final      bool
	is_mutated    bool
}

pub struct MypyPluginStore {
pub mut:
	collected_types      map[string]map[string]string
	collected_sigs       map[string]map[string]string
	collected_mutability map[string]map[string]MypyCollectedMutability
	processed_files      map[string]bool
}

pub fn new_mypy_plugin_store() MypyPluginStore {
	return MypyPluginStore{
		collected_types:      map[string]map[string]string{}
		collected_sigs:       map[string]map[string]string{}
		collected_mutability: map[string]map[string]MypyCollectedMutability{}
		processed_files:      map[string]bool{}
	}
}

pub fn (mut s MypyPluginStore) collect_type(name string, loc string, typ string) {
	if name.len == 0 || loc.len == 0 || typ.len == 0 {
		return
	}
	if name !in s.collected_types {
		s.collected_types[name] = map[string]string{}
	}
	s.collected_types[name][loc] = typ
	if '@' !in s.collected_types {
		s.collected_types['@'] = map[string]string{}
	}
	s.collected_types['@'][loc] = typ
	s.collected_types['${name}@${loc}'] = {'${loc}': typ}
}

pub fn (mut s MypyPluginStore) collect_signature(name string, loc string, sig map[string]string) {
	if name.len == 0 || loc.len == 0 {
		return
	}
	encoded := json.encode(sig)
	if name !in s.collected_sigs {
		s.collected_sigs[name] = map[string]string{}
	}
	s.collected_sigs[name][loc] = encoded
	if loc !in s.collected_sigs {
		s.collected_sigs[loc] = map[string]string{}
	}
	s.collected_sigs[loc][loc] = encoded
}

pub fn (mut s MypyPluginStore) collect_mutability(name string, loc string, info MypyCollectedMutability) {
	if name.len == 0 || loc.len == 0 {
		return
	}
	if name !in s.collected_mutability {
		s.collected_mutability[name] = map[string]MypyCollectedMutability{}
	}
	s.collected_mutability[name][loc] = info
}

pub struct MypyPluginAnalyzer {
pub mut:
	store            MypyPluginStore
	mutating_methods []string
	visited          map[string]bool
	checker          ?&mypy.TypeChecker
}

pub fn new_mypy_plugin_analyzer() MypyPluginAnalyzer {
	return MypyPluginAnalyzer{
		store:            new_mypy_plugin_store()
		mutating_methods: ['append', 'extend', 'insert', 'pop', 'remove', 'clear', 'update', 'setdefault',
			'delete', 'add', 'discard', 'intersection_update']
		visited:          map[string]bool{}
		checker:          none
	}
}

pub fn (mut a MypyPluginAnalyzer) collect_file(file mypy.MypyFile) {
	a.collect_file_with_checker(file, none)
}

pub fn (mut a MypyPluginAnalyzer) collect_file_with_checker(file mypy.MypyFile, checker ?&mypy.TypeChecker) {
	file_key := if file.fullpath.len > 0 { file.fullpath } else { file.path }
	if file_key.len > 0 {
		if file_key in a.store.processed_files {
			return
		}
		a.store.processed_files[file_key] = true
	}
	a.checker = checker
	a.visit_mypy_file(file)
}

fn bool_string(value bool) string {
	if value {
		return 'true'
	}
	return 'false'
}

fn ctx_key(ctx mypy.Context, tag string) string {
	return '${ctx.line}:${ctx.column}:${tag}'
}

fn (mut a MypyPluginAnalyzer) remember(node_key string) bool {
	if node_key in a.visited {
		return false
	}
	a.visited[node_key] = true
	return true
}

fn (mut a MypyPluginAnalyzer) record_checker_type(expr mypy.Expression) {
	if checker := a.checker {
		if typ := checker.lookup_type_or_none(expr) {
			ctx := expr.get_context()
			key := '${ctx.line}:${ctx.column}'
			a.store.collect_type(expr.str(), key, typ.type_str())
		}
	}
}

fn (mut a MypyPluginAnalyzer) visit_mypy_file(file mypy.MypyFile) {
	key := ctx_key(file.get_context(), 'MypyFile:${file.fullname}')
	if !a.remember(key) {
		return
	}
	a.visit_symbol_table(file.names)
	for stmt in file.defs {
		a.visit_stmt(stmt)
	}
}

fn (mut a MypyPluginAnalyzer) visit_symbol_table(table mypy.SymbolTable) {
	for _, sym in table.symbols {
		if node := sym.node {
			a.visit_mypy_node(node.as_mypy_node())
		}
	}
}

fn (mut a MypyPluginAnalyzer) visit_mypy_node(node mypy.MypyNode) {
	match node {
		mypy.Var { a.visit_var(node) }
		mypy.FuncDef { a.visit_func_def(node) }
		mypy.OverloadedFuncDef { a.visit_overloaded_func_def(node) }
		mypy.Decorator { a.visit_decorator(node) }
		mypy.ClassDef { a.visit_class_def(node) }
		mypy.TypeInfo { a.visit_type_info(node) }
		mypy.TypeAlias { a.visit_type_alias(node) }
		mypy.MypyFile { a.visit_mypy_file(node) }
		mypy.PlaceholderNode {}
		else {}
	}
}

fn (mut a MypyPluginAnalyzer) visit_stmt(stmt mypy.Statement) {
	match stmt {
		mypy.Block {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_block(stmt)
		}
		mypy.ExpressionStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.expr)
		}
		mypy.AssignmentStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_assignment_stmt(stmt)
		}
		mypy.OperatorAssignmentStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_operator_assignment_stmt(stmt)
		}
		mypy.WhileStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.expr)
			a.visit_block(stmt.body)
			if else_body := stmt.else_body {
				a.visit_block(else_body)
			}
		}
		mypy.ForStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.index)
			a.visit_expr(stmt.expr)
			a.visit_block(stmt.body)
			if else_body := stmt.else_body {
				a.visit_block(else_body)
			}
		}
		mypy.IfStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			for expr in stmt.expr {
				a.visit_expr(expr)
			}
			for body in stmt.body {
				a.visit_block(body)
			}
			if else_body := stmt.else_body {
				a.visit_block(else_body)
			}
		}
		mypy.ReturnStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			if expr := stmt.expr {
				a.visit_expr(expr)
			}
		}
		mypy.AssertStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.expr)
			if msg := stmt.msg {
				a.visit_expr(msg)
			}
		}
		mypy.RaiseStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			if expr := stmt.expr {
				a.visit_expr(expr)
			}
			if from_expr := stmt.from {
				a.visit_expr(from_expr)
			}
		}
		mypy.TryStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_block(stmt.body)
			for i, typ in stmt.types {
				if exp := typ {
					a.visit_expr(exp)
				}
				if i < stmt.vars.len {
					if var_expr := stmt.vars[i] {
						a.visit_name_expr(var_expr)
					}
				}
			}
			for handler in stmt.handlers {
				a.visit_block(handler)
			}
			if else_body := stmt.else_body {
				a.visit_block(else_body)
			}
			if finally_body := stmt.finally_body {
				a.visit_block(finally_body)
			}
		}
		mypy.WithStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			for expr in stmt.expr {
				a.visit_expr(expr)
			}
			for target in stmt.target {
				if expr := target {
					a.visit_expr(expr)
				}
			}
			a.visit_block(stmt.body)
		}
		mypy.DelStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.expr)
			a.mark_mutated(stmt.expr)
		}
		mypy.GlobalDecl {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.NonlocalDecl {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.BreakStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.ContinueStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.PassStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.TypeAliasStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.value)
		}
		mypy.MatchStmt {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_expr(stmt.subject)
			for i in 0 .. stmt.bodies.len {
				if guard := stmt.guards[i] {
					a.visit_expr(guard)
				}
				a.visit_block(stmt.bodies[i])
			}
		}
		mypy.FuncDef {
			key := ctx_key(stmt.get_context(), typeof(stmt).name + ':' + stmt.fullname)
			if !a.remember(key) { return }
			a.visit_func_def(stmt)
		}
		mypy.OverloadedFuncDef {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_overloaded_func_def(stmt)
		}
		mypy.Decorator {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
			a.visit_decorator(stmt)
		}
		mypy.ClassDef {
			key := ctx_key(stmt.get_context(), typeof(stmt).name + ':' + stmt.fullname)
			if !a.remember(key) { return }
			a.visit_class_def(stmt)
		}
		mypy.Import {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.ImportFrom {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
		mypy.ImportAll {
			key := ctx_key(stmt.get_context(), typeof(stmt).name)
			if !a.remember(key) { return }
		}
	}
}

fn (mut a MypyPluginAnalyzer) visit_block(block mypy.Block) {
	key := ctx_key(block.get_context(), typeof(block).name)
	if !a.remember(key) {
		return
	}
	for stmt in block.body {
		a.visit_stmt(stmt)
	}
}

fn (mut a MypyPluginAnalyzer) visit_expr(expr mypy.Expression) {
	key := ctx_key(expr.get_context(), typeof(expr).name)
	if !a.remember(key) { return }
	a.record_checker_type(expr)
	match expr {
		mypy.NameExpr {
			a.visit_name_expr(expr)
		}
		mypy.MemberExpr {
			a.visit_member_expr(expr)
		}
		mypy.IndexExpr {
			a.visit_index_expr(expr)
		}
		mypy.CallExpr {
			a.visit_call_expr(expr)
		}
		mypy.TupleExpr {
			for item in expr.items {
				a.visit_expr(item)
			}
		}
		mypy.ListExpr {
			for item in expr.items {
				a.visit_expr(item)
			}
		}
		mypy.DictExpr {
			for entry in expr.items {
				if key_expr := entry.key {
					a.visit_expr(key_expr)
				}
				a.visit_expr(entry.value)
			}
		}
		mypy.SetExpr {
			for item in expr.items {
				a.visit_expr(item)
			}
		}
		mypy.OpExpr {
			a.visit_expr(expr.left)
			a.visit_expr(expr.right)
		}
		mypy.ComparisonExpr {
			for item in expr.operands {
				a.visit_expr(item)
			}
		}
		mypy.UnaryExpr {
			a.visit_expr(expr.expr)
		}
		mypy.ConditionalExpr {
			a.visit_expr(expr.cond)
			a.visit_expr(expr.if_expr)
			a.visit_expr(expr.else_expr)
		}
		mypy.AssignmentExpr {
			a.visit_expr(expr.target)
			a.visit_expr(expr.value)
		}
		mypy.LambdaExpr {
			a.visit_expr(expr.body)
		}
		mypy.GeneratorExpr {
			a.visit_expr(expr.left_expr)
			for item in expr.indices {
				a.visit_expr(item)
			}
			for seq in expr.sequences {
				a.visit_expr(seq)
			}
			for conds in expr.condlists {
				for cond in conds {
					a.visit_expr(cond)
				}
			}
		}
		mypy.ListComprehension {
			a.visit_expr(expr.generator.left_expr)
		}
		mypy.SetComprehension {
			a.visit_expr(expr.generator.left_expr)
		}
		mypy.DictionaryComprehension {
			a.visit_expr(expr.key)
			a.visit_expr(expr.value)
		}
		mypy.SliceExpr {
			if begin := expr.begin {
				a.visit_expr(begin)
			}
			if end := expr.end {
				a.visit_expr(end)
			}
			if step := expr.step {
				a.visit_expr(step)
			}
		}
		mypy.TemplateStrExpr {}
		mypy.FormatStringExpr {}
		mypy.IntExpr {}
		mypy.StrExpr {}
		mypy.BytesExpr {}
		mypy.FloatExpr {}
		mypy.ComplexExpr {}
		mypy.EllipsisExpr {}
		mypy.StarExpr {
			a.visit_expr(expr.expr)
		}
		mypy.TypeApplication {
			a.visit_expr(expr.expr)
			for arg in expr.types {
				a.visit_type_node(arg)
			}
		}
		mypy.YieldExpr {
			if value := expr.expr {
				a.visit_expr(value)
			}
		}
		mypy.YieldFromExpr {
			a.visit_expr(expr.expr)
		}
		mypy.AwaitExpr {
			a.visit_expr(expr.expr)
		}
		else {}
	}
}

fn (mut a MypyPluginAnalyzer) visit_type_node(typ mypy.MypyTypeNode) {
	key := typ.type_str()
	if key.len == 0 {
		return
	}
	_ = key
}

fn (mut a MypyPluginAnalyzer) visit_name_expr(expr mypy.NameExpr) {
	a.mark_name_mutability(expr.name, expr.fullname, expr.get_context(), false, false)
	if node := expr.node {
		a.visit_mypy_node(node)
	}
}

fn (mut a MypyPluginAnalyzer) visit_member_expr(expr mypy.MemberExpr) {
	a.visit_expr(expr.expr)
	if node := expr.node {
		a.visit_mypy_node(node)
	}
}

fn (mut a MypyPluginAnalyzer) visit_index_expr(expr mypy.IndexExpr) {
	a.visit_expr(expr.base_)
	a.visit_expr(expr.index)
}

fn (mut a MypyPluginAnalyzer) visit_call_expr(expr mypy.CallExpr) {
	if expr.callee is mypy.MemberExpr {
		if expr.callee.name in a.mutating_methods {
			a.mark_mutated(expr.callee.expr)
		}
	}
	a.visit_expr(expr.callee)
	for arg in expr.args {
		a.visit_expr(arg)
	}
}

fn (mut a MypyPluginAnalyzer) visit_var(node mypy.Var) {
	loc := '${node.get_context().line}:${node.get_context().column}'
	if typ := node.type_ {
		a.store.collect_type(node.fullname, loc, typ.type_str())
		if node.name.len > 0 && node.name != node.fullname {
			a.store.collect_type(node.name, loc, typ.type_str())
		}
	}
	mut info := MypyCollectedMutability{
		is_reassigned: false
		is_final: node.is_final
		is_mutated: false
	}
	a.store.collect_mutability(node.fullname, loc, info)
	if node.name.len > 0 && node.name != node.fullname {
		a.store.collect_mutability(node.name, loc, info)
	}
}

fn (mut a MypyPluginAnalyzer) visit_func_def(node mypy.FuncDef) {
	key := ctx_key(node.get_context(), 'FuncDef:${node.fullname}')
	if !a.remember(key) {
		return
	}
	loc := '${node.get_context().line}:${node.get_context().column}'
	sig := a.build_function_signature(node)
	a.store.collect_signature(node.fullname, loc, sig)
	if node.name.len > 0 && node.name != node.fullname {
		a.store.collect_signature(node.name, loc, sig)
	}
	if typ := node.type_ {
		a.store.collect_type(node.fullname, loc, typ.type_str())
		if node.name.len > 0 && node.name != node.fullname {
			a.store.collect_type(node.name, loc, typ.type_str())
		}
	}
	for arg in node.arguments {
		if typ := arg.type_annotation {
			arg_loc := '${arg.get_context().line}:${arg.get_context().column}'
			a.store.collect_type(arg.variable.fullname, arg_loc, typ.type_str())
			if arg.variable.name.len > 0 && arg.variable.name != arg.variable.fullname {
				a.store.collect_type(arg.variable.name, arg_loc, typ.type_str())
			}
		}
	}
	a.visit_block(node.body)
}

fn (mut a MypyPluginAnalyzer) visit_overloaded_func_def(node mypy.OverloadedFuncDef) {
	loc := '${node.get_context().line}:${node.get_context().column}'
	if typ := node.type_ {
		a.store.collect_type('overload', loc, typ.type_str())
	}
	for item in node.items {
		a.visit_func_def(item)
	}
}

fn (mut a MypyPluginAnalyzer) visit_decorator(node mypy.Decorator) {
	a.visit_func_def(node.func)
	if typ := node.var_.type_ {
		loc := '${node.var_.get_context().line}:${node.var_.get_context().column}'
		a.store.collect_type(node.var_.fullname, loc, typ.type_str())
	}
	for decorator in node.decorators {
		a.visit_expr(decorator)
	}
}

fn (mut a MypyPluginAnalyzer) visit_class_def(node mypy.ClassDef) {
	key := ctx_key(node.get_context(), 'ClassDef:${node.fullname}')
	if !a.remember(key) {
		return
	}
	loc := '${node.get_context().line}:${node.get_context().column}'
	sig := a.build_class_signature(node)
	a.store.collect_signature(node.fullname, loc, sig)
	if node.name.len > 0 && node.name != node.fullname {
		a.store.collect_signature(node.name, loc, sig)
	}
	if info := node.info {
		a.visit_type_info(*info)
	}
	for base in node.base_type_exprs {
		a.visit_expr(base)
	}
	for removed in node.removed_base_type_exprs {
		a.visit_expr(removed)
	}
	for decorator in node.decorators {
		a.visit_expr(decorator)
	}
	a.visit_block(node.defs)
}

fn (mut a MypyPluginAnalyzer) visit_type_info(info mypy.TypeInfo) {
	key := ctx_key(info.get_context(), 'TypeInfo:${info.fullname}')
	if !a.remember(key) {
		return
	}
	loc := '${info.get_context().line}:${info.get_context().column}'
	mut sig := map[string]string{}
	sig['args'] = '[]'
	sig['return'] = info.fullname
	sig['is_class'] = 'true'
	sig['has_init'] = if '__init__' in info.names.symbols { 'true' } else { 'false' }
	sig['has_vararg'] = 'false'
	sig['has_kwarg'] = 'false'
	sig['arg_names'] = '[]'
	sig['defaults'] = '{}'
	a.store.collect_signature(info.fullname, loc, sig)
	if info.name.len > 0 && info.name != info.fullname {
		a.store.collect_signature(info.name, loc, sig)
	}
	a.visit_symbol_table(info.names)
}

fn (mut a MypyPluginAnalyzer) visit_type_alias(node mypy.TypeAlias) {
	loc := '${node.get_context().line}:${node.get_context().column}'
	a.store.collect_type(node.fullname, loc, node.target.type_str())
	if node.name.len > 0 && node.name != node.fullname {
		a.store.collect_type(node.name, loc, node.target.type_str())
	}
	for alias_tvar in node.alias_tvars {
		a.visit_type_node(alias_tvar)
	}
}

fn (mut a MypyPluginAnalyzer) visit_assignment_stmt(node mypy.AssignmentStmt) {
	loc := '${node.get_context().line}:${node.get_context().column}'
	if typ := node.type_annotation {
		for lvalue in node.lvalues {
			a.collect_annotation_for_lvalue(lvalue, typ, loc)
		}
	}
	for lvalue in node.lvalues {
		if nested := lvalue.as_lvalue() {
			a.visit_lvalue(nested, true)
		}
	}
	a.visit_expr(node.rvalue)
}

fn (mut a MypyPluginAnalyzer) visit_operator_assignment_stmt(node mypy.OperatorAssignmentStmt) {
	a.visit_lvalue(node.lvalue, true)
	a.visit_expr(node.rvalue)
}

fn (mut a MypyPluginAnalyzer) visit_lvalue(lvalue mypy.Lvalue, is_store bool) {
	match lvalue {
		mypy.NameExpr {
			a.mark_name_mutability(lvalue.name, lvalue.fullname, lvalue.get_context(), true, false)
			if node := lvalue.node {
				a.visit_mypy_node(node)
			}
		}
		mypy.MemberExpr {
			if is_store {
				a.mark_mutated(lvalue.expr)
			}
			a.visit_expr(lvalue.expr)
		}
		mypy.TupleExpr {
			for item in lvalue.items {
				if nested := item.as_lvalue() {
					a.visit_lvalue(nested, is_store)
				}
			}
		}
		mypy.ListExpr {
			for item in lvalue.items {
				if nested := item.as_lvalue() {
					a.visit_lvalue(nested, is_store)
				}
			}
		}
		mypy.StarExpr {
			if nested := lvalue.expr.as_lvalue() {
				a.visit_lvalue(nested, is_store)
			}
		}
	}
}

fn (mut a MypyPluginAnalyzer) collect_annotation_for_lvalue(lvalue mypy.Expression, typ mypy.MypyTypeNode, loc string) {
	if name_lvalue := lvalue.as_lvalue() {
		match name_lvalue {
			mypy.NameExpr {
				a.store.collect_type(name_lvalue.fullname, loc, typ.type_str())
				if name_lvalue.name.len > 0 && name_lvalue.name != name_lvalue.fullname {
					a.store.collect_type(name_lvalue.name, loc, typ.type_str())
				}
			}
			mypy.TupleExpr {
				for item in name_lvalue.items {
					a.collect_annotation_for_lvalue(item, typ, loc)
				}
			}
			mypy.ListExpr {
				for item in name_lvalue.items {
					a.collect_annotation_for_lvalue(item, typ, loc)
				}
			}
			mypy.StarExpr {
				a.collect_annotation_for_lvalue(name_lvalue.expr, typ, loc)
			}
			else {}
		}
	}
}

fn (mut a MypyPluginAnalyzer) mark_name_mutability(name string, fullname string, ctx mypy.Context, is_reassigned bool, is_mutated bool) {
	if name.len == 0 && fullname.len == 0 {
		return
	}
	loc := '${ctx.line}:${ctx.column}'
	key := if fullname.len > 0 { fullname } else { name }
	mut info := a.store.collected_mutability[key][loc] or {
		MypyCollectedMutability{
			is_reassigned: false
			is_final:      false
			is_mutated:    false
		}
	}
	info.is_reassigned = info.is_reassigned || is_reassigned
	info.is_mutated = info.is_mutated || is_mutated
	a.store.collect_mutability(key, loc, info)
	if fullname.len > 0 && fullname != name {
		a.store.collect_mutability(name, loc, info)
	}
}

fn (mut a MypyPluginAnalyzer) mark_mutated(expr mypy.Expression) {
	match expr {
		mypy.NameExpr {
			a.mark_name_mutability(expr.name, expr.fullname, expr.get_context(), false, true)
		}
		mypy.MemberExpr {
			a.mark_mutated(expr.expr)
		}
		mypy.TupleExpr {
			for item in expr.items {
				a.mark_mutated(item)
			}
		}
		mypy.ListExpr {
			for item in expr.items {
				a.mark_mutated(item)
			}
		}
		else {}
	}
}

fn (a &MypyPluginAnalyzer) build_function_signature(node mypy.FuncDef) map[string]string {
	mut args := []string{}
	mut arg_names := []string{}
	mut defaults := map[string]string{}
	for arg in node.arguments {
		arg_names << arg.variable.name
		if typ := arg.type_annotation {
			args << typ.type_str()
		} else if var_typ := arg.variable.type_ {
			args << var_typ.type_str()
		} else {
			args << 'Any'
		}
		if arg.initializer != none {
			defaults[arg.variable.name] = 'default'
		}
	}
	ret_type := if typ := node.type_ {
		if typ is mypy.CallableType {
			typ.ret_type.type_str()
		} else {
			typ.type_str()
		}
	} else {
		'Any'
	}
	return {
		'args':       json.encode(args)
		'return':     ret_type
		'is_class':   bool_string(node.is_class)
		'has_init':   'false'
		'has_vararg': bool_string(false)
		'has_kwarg':  bool_string(false)
		'arg_names':  json.encode(arg_names)
		'defaults':   json.encode(defaults)
	}
}

fn (a &MypyPluginAnalyzer) build_class_signature(node mypy.ClassDef) map[string]string {
	mut has_init := false
	if info := node.info {
		has_init = '__init__' in info.names.symbols
	}
	return {
		'args':       '[]'
		'return':     node.fullname
		'is_class':   'true'
		'has_init':   bool_string(has_init)
		'has_vararg': 'false'
		'has_kwarg':  'false'
		'arg_names':  '[]'
		'defaults':   '{}'
	}
}
