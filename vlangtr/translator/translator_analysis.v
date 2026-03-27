module translator

import ast

fn (t &Translator) collect_mutable_locals(stmts []ast.Statement) map[string]bool {
	mut names := map[string]bool{}
	for stmt in stmts {
		t.collect_mutable_locals_stmt(stmt, mut names)
	}
	return names
}

fn (t &Translator) collect_mutable_locals_stmt(stmt ast.Statement, mut names map[string]bool) {
	match stmt {
		ast.Assign {
			for target in stmt.targets {
				if target is ast.Attribute {
					if target.value is ast.Name {
						names[target.value.id] = true
					}
				}
			}
		}
		ast.AnnAssign {
			if stmt.target is ast.Attribute {
				if stmt.target.value is ast.Name {
					names[stmt.target.value.id] = true
				}
			}
		}
		ast.AugAssign {
			if stmt.target is ast.Attribute {
				if stmt.target.value is ast.Name {
					names[stmt.target.value.id] = true
				}
			}
		}
		ast.Expr {
			if stmt.value is ast.Call {
				if stmt.value.func is ast.Attribute {
					if stmt.value.func.value is ast.Name {
						names[stmt.value.func.value.id] = true
					}
				}
			}
		}
		ast.If {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.For {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.While {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
		}
		ast.Try {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
			other2 := t.collect_mutable_locals(stmt.orelse)
			for k in other2.keys() {
				names[k] = true
			}
			other3 := t.collect_mutable_locals(stmt.finalbody)
			for k in other3.keys() {
				names[k] = true
			}
		}
		ast.With {
			other := t.collect_mutable_locals(stmt.body)
			for k in other.keys() {
				names[k] = true
			}
		}
		else {}
	}
}
