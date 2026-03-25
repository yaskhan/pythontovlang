// renaming.v — Variable renaming for redefinition support
// Translated from mypy/renaming.py

module mypy

// Constants for scope types
pub const file_scope = 0
pub const function_scope = 1
pub const class_scope = 2

// VariableRenameVisitor renames variables to support redefinition
pub struct VariableRenameVisitor {
pub mut:
	// Counter for numbering new blocks
	block_id int
	// Number of surrounding try operators that prohibit variable redefinition
	disallow_redef_depth int
	// Number of surrounding loops
	loop_depth int
	// Mapping block_id -> loop_depth
	block_loop_depth map[int]int
	// Stack of processed block_id
	blocks []int
	// List of scopes; each scope maps name -> block_id
	var_blocks []map[string]int

	// References to variables that may require renaming
	refs []map[string][][]NameExpr
	// Number of reads of the last variable definition (per scope)
	num_reads []map[string]int
	// Types of nested scopes (FILE, FUNCTION or CLASS)
	scope_kinds []int
}

// new_variable_rename_visitor creates a new VariableRenameVisitor
pub fn new_variable_rename_visitor() VariableRenameVisitor {
	return VariableRenameVisitor{
		block_id:             0
		disallow_redef_depth: 0
		loop_depth:           0
		block_loop_depth:     map[int]int{}
		blocks:               [0]
		var_blocks:           []map[string]int{}
		refs:                 []map[string][][]NameExpr{}
		num_reads:            []map[string]int{}
		scope_kinds:          []int{}
	}
}

// clear clears the state
pub fn (mut v VariableRenameVisitor) clear() {
	v.blocks = [0]
	v.var_blocks = []
}

// enter_block enters a new block
pub fn (mut v VariableRenameVisitor) enter_block() BlockGuard {
	v.block_id++
	v.blocks << v.block_id
	v.block_loop_depth[v.block_id] = v.loop_depth
	return BlockGuard{
		v: v
	}
}

// BlockGuard for automatic exit from block
pub struct BlockGuard {
pub mut:
	v &VariableRenameVisitor
}

// drop removes the block on exit
pub fn (mut bg BlockGuard) drop() {
	bg.v.blocks.pop()
}

// enter_try enters a try-block
pub fn (mut v VariableRenameVisitor) enter_try() TryGuard {
	v.disallow_redef_depth++
	return TryGuard{
		v: v
	}
}

// TryGuard for automatic exit from try
pub struct TryGuard {
pub mut:
	v &VariableRenameVisitor
}

// drop decreases try depth
pub fn (mut tg TryGuard) drop() {
	tg.v.disallow_redef_depth--
}

// enter_loop enters a loop
pub fn (mut v VariableRenameVisitor) enter_loop() LoopGuard {
	v.loop_depth++
	return LoopGuard{
		v: v
	}
}

// LoopGuard for automatic exit from loop
pub struct LoopGuard {
pub mut:
	v &VariableRenameVisitor
}

// drop decreases loop depth
pub fn (mut lg LoopGuard) drop() {
	lg.v.loop_depth--
}

// enter_scope enters a new scope
pub fn (mut v VariableRenameVisitor) enter_scope(kind int) ScopeGuard {
	v.var_blocks << map[string]int{}
	v.refs << map[string][][]NameExpr{}
	v.num_reads << map[string]int{}
	v.scope_kinds << kind
	return ScopeGuard{
		v: v
	}
}

// ScopeGuard for automatic exit from scope
pub struct ScopeGuard {
pub mut:
	v &VariableRenameVisitor
}

// drop executes flush_refs on exit
pub fn (mut sg ScopeGuard) drop() {
	sg.v.flush_refs()
	sg.v.var_blocks.pop()
	sg.v.num_reads.pop()
	sg.v.scope_kinds.pop()
}

// current_block returns the current block_id
fn (v VariableRenameVisitor) current_block() int {
	if v.blocks.len == 0 { return 0 }
	return v.blocks.last()
}

// flush_refs processes variable references
fn (mut v VariableRenameVisitor) flush_refs() {
	if v.refs.len == 0 {
		return
	}

	mut last_refs := v.refs.pop()
	mut last_reads := v.num_reads.pop()

	for name, mut collections in last_refs {
		reads := last_reads[name] or { 0 }

		if collections.len > 1 && reads <= 1 {
			for i, mut coll in collections {
				if i > 0 {
					for mut expr in coll {
						expr.is_special_form = true
					}
				}
			}
		}
	}
}

// record_definition_helper records a name definition
fn (mut v VariableRenameVisitor) record_definition_helper(name string) {
	if v.var_blocks.len > 0 {
		mut current := v.var_blocks.last()
		if name in current {
			if v.disallow_redef_depth == 0 {
				current[name] = v.current_block()
			}
		} else {
			current[name] = v.current_block()
		}
		if v.num_reads.len > 0 {
			v.num_reads.last()[name] = 0
		}
	}
}

// visit_name_expr handles variable name
pub fn (mut v VariableRenameVisitor) visit_name_expr(mut expr NameExpr) {
	if v.var_blocks.len == 0 {
		return
	}

	name := expr.name
	if name !in v.var_blocks.last() {
		v.var_blocks.last()[name] = v.current_block()
	} else {
		def_block := v.var_blocks.last()[name]
		if def_block != v.current_block() {
			if name !in v.refs.last() {
				v.refs.last()[name] = [][]NameExpr{}
			}
			v.refs.last()[name] << [expr]
		}
	}
}

// visit_assignment_stmt handles assignment
pub fn (mut v VariableRenameVisitor) visit_assignment_stmt(mut stmt AssignmentStmt) {
	for mut lval in stmt.lvalues {
		match mut lval {
			NameExpr, MemberExpr, ListExpr, TupleExpr, StarExpr {
				v.visit_lvalue(mut lval)
			}
			else {}
		}
	}
	v.visit_expression(mut stmt.rvalue)
}

// visit_lvalue handles lvalue
fn (mut v VariableRenameVisitor) visit_lvalue(mut lval Lvalue) {
	match mut lval {
		NameExpr {
			v.visit_expression(mut Expression(lval))
		}
		TupleExpr, ListExpr {
			for mut item in lval.items {
				match mut item {
					NameExpr, MemberExpr, TupleExpr, ListExpr, StarExpr {
						v.visit_lvalue(mut Lvalue(item))
					}
					else {}
				}
			}
		}
		MemberExpr {
			v.visit_expression(mut Expression(lval))
		}
		StarExpr {
			match mut lval.expr {
				NameExpr, MemberExpr, TupleExpr, ListExpr, StarExpr {
					v.visit_lvalue(mut Lvalue(lval.expr))
				}
				else {}
			}
		}
	}
}

// visit_expression handles expression
fn (mut v VariableRenameVisitor) visit_expression(mut expr Expression) {
	match mut expr {
		NameExpr {
			v.visit_name_expr(mut expr)
			if v.num_reads.len > 0 && v.var_blocks.len > 0 {
				name := expr.name
				if name in v.var_blocks.last() {
					reads := v.num_reads.last()[name] or { 0 }
					v.num_reads.last()[name] = reads + 1
				}
			}
		}
		MemberExpr {
			v.visit_expression(mut expr.expr)
		}
		CallExpr {
			v.visit_expression(mut expr.callee)
			for mut arg in expr.args {
				v.visit_expression(mut arg)
			}
		}
		TupleExpr {
			for mut item in expr.items {
				v.visit_expression(mut item)
			}
		}
		ListExpr {
			for mut item in expr.items {
				v.visit_expression(mut item)
			}
		}
		DictExpr {
			for mut entry in expr.items {
				if mut k := entry.key {
					v.visit_expression(mut k)
				}
				v.visit_expression(mut entry.value)
			}
		}
		else {}
	}
}

// visit_func_def handles function definition
pub fn (mut v VariableRenameVisitor) visit_func_def(mut defn FuncDef) {
	mut sg := v.enter_scope(function_scope)
	defer {
		sg.drop()
	}

	for arg in defn.arguments {
		v.record_definition_helper(arg.variable.name)
	}

	v.visit_block(mut defn.body)
}

// visit_class_def handles class definition
pub fn (mut v VariableRenameVisitor) visit_class_def(mut defn ClassDef) {
	mut sg := v.enter_scope(class_scope)
	defer {
		sg.drop()
	}

	v.visit_block(mut defn.defs)
}

// visit_block handles block
pub fn (mut v VariableRenameVisitor) visit_block(mut block Block) {
	mut bg := v.enter_block()
	defer {
		bg.drop()
	}

	for mut stmt in block.body {
		v.visit_statement(mut stmt)
	}
}

// visit_statement handles statement
fn (mut v VariableRenameVisitor) visit_statement(mut stmt Statement) {
	match mut stmt {
		AssignmentStmt {
			v.visit_assignment_stmt(mut stmt)
		}
		ExpressionStmt {
			v.visit_expression(mut stmt.expr)
		}
		ReturnStmt {
			if mut e := stmt.expr {
				v.visit_expression(mut e)
			}
		}
		IfStmt {
			for mut e in stmt.expr {
				v.visit_expression(mut e)
			}
			for mut b in stmt.body {
				v.visit_block(mut b)
			}
			if mut eb := stmt.else_body {
				v.visit_block(mut eb)
			}
		}
		WhileStmt {
			v.visit_expression(mut stmt.expr)
			mut lg := v.enter_loop()
			defer {
				lg.drop()
			}
			v.visit_block(mut stmt.body)
		}
		ForStmt {
			v.visit_expression(mut stmt.expr)
			match mut stmt.index {
				NameExpr, MemberExpr, ListExpr, TupleExpr, StarExpr {
					v.visit_lvalue(mut stmt.index)
				}
				else {}
			}
			mut lg := v.enter_loop()
			defer {
				lg.drop()
			}
			v.visit_block(mut stmt.body)
		}
		TryStmt {
			mut tg := v.enter_try()
			defer {
				tg.drop()
			}
			v.visit_block(mut stmt.body)
			for mut h in stmt.handlers {
				v.visit_block(mut h)
			}
		}
		FuncDef {
			v.visit_func_def(mut stmt)
		}
		ClassDef {
			v.visit_class_def(mut stmt)
		}
		Block {
			v.visit_block(mut stmt)
		}
		else {}
	}
}
