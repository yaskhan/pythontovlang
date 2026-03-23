// I, Cline, am working on this file. Started: 2026-03-22 14:58
// semanal_pass1.v — Block/import reachability analysis
// Translated from mypy/semanal_pass1.py

module mypy

// SemanticAnalyzerPreAnalysis analyzes reachability of blocks and imports
// Runs before semantic analysis, so names are not yet bound
// Determines static reachability of blocks and imports due to version and platform checks
pub struct SemanticAnalyzerPreAnalysis {
pub mut:
	platform        string
	cur_mod_id      string
	cur_mod_node    MypyFile
	options         Options
	is_global_scope bool
	skipped_lines   map[int]bool
}

// new_semanal_pre_analysis creates a new SemanticAnalyzerPreAnalysis
pub fn new_semanal_pre_analysis() SemanticAnalyzerPreAnalysis {
	return SemanticAnalyzerPreAnalysis{
		platform:        ''
		cur_mod_id:      ''
		cur_mod_node:    MypyFile{}
		options:         Options{}
		is_global_scope: true
		skipped_lines:   map[int]bool{}
	}
}

// visit_file — main entry point
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_file(file MypyFile, fnam string, mod_id string, options Options) {
	spa.platform = options.platform
	spa.cur_mod_id = mod_id
	spa.cur_mod_node = file
	spa.options = options
	spa.is_global_scope = true
	spa.skipped_lines = map[int]bool{}

	for i, defn in file.defs {
		spa.accept(defn)
		if defn is AssertStmt {
			if assert_will_always_fail(defn, options) {
				if i < file.defs.len - 1 {
					next_def := file.defs[i + 1]
					last := file.defs[file.defs.len - 1]
					if last.end_line != none {
						start := next_def.line
						end := last.end_line or { start }
						for line in start .. end + 1 {
							spa.skipped_lines[line] = true
						}
					}
				}
				file.imports = file.imports.filter(it.line < defn.line
					|| (it.line == defn.line && it.column <= defn.column))
				file.defs = file.defs[..i + 1]
				break
			}
		}
	}
	file.skipped_lines = spa.skipped_lines.keys()
}

// visit_func_def handles function definition
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_func_def(node FuncDef) {
	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	// TODO: call super().visit_func_def(node)
	spa.is_global_scope = old_global_scope

	file_node := spa.cur_mod_node
	if spa.is_global_scope && file_node.is_stub && node.name == '__getattr__'
		&& file_node.is_package_init_file() {
		file_node.is_partial_stub_package = true
	}
}

// visit_class_def handles class definition
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_class_def(node ClassDef) {
	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	// TODO: call super().visit_class_def(node)
	spa.is_global_scope = old_global_scope
}

// visit_import_from handles from ... import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_from(node ImportFrom) {
	node.is_top_level = spa.is_global_scope
}

// visit_import_all handles from ... import *
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_all(node ImportAll) {
	node.is_top_level = spa.is_global_scope
}

// visit_import handles import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import(node Import) {
	node.is_top_level = spa.is_global_scope
}

// visit_if_stmt handles if statement
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_if_stmt(s IfStmt) {
	infer_reachability_of_if_statement(s, spa.options)
	for expr in s.expr {
		spa.accept(expr)
	}
	for node in s.body {
		spa.accept(node)
	}
	if s.else_body {
		spa.accept(s.else_body)
	}
}

// visit_block handles block
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_block(b Block) {
	if b.is_unreachable {
		if b.end_line != none {
			start := b.line
			end := b.end_line or { start }
			for line in start .. end + 1 {
				spa.skipped_lines[line] = true
			}
		}
		return
	}
	for stmt in b.body {
		spa.accept(stmt)
	}
}

// visit_match_stmt handles match statement
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_match_stmt(s MatchStmt) {
	infer_reachability_of_match_statement(s, spa.options)
	for guard in s.guards {
		if guard != none {
			spa.accept(guard)
		}
	}
	for body in s.bodies {
		spa.accept(body)
	}
}

// visit_assignment_stmt — optimization: do not visit nested expressions
pub fn (spa SemanticAnalyzerPreAnalysis) visit_assignment_stmt(s AssignmentStmt) {
	// Do nothing
}

// visit_expression_stmt — optimization: do not visit nested expressions
pub fn (spa SemanticAnalyzerPreAnalysis) visit_expression_stmt(s ExpressionStmt) {
	// Do nothing
}

// visit_return_stmt — optimization: do not visit nested expressions
pub fn (spa SemanticAnalyzerPreAnalysis) visit_return_stmt(s ReturnStmt) {
	// Do nothing
}

// visit_for_stmt handles for loop
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_for_stmt(s ForStmt) {
	spa.accept(s.body)
	if s.else_body != none {
		spa.accept(s.else_body)
	}
}

// accept calls the corresponding visit_ method for the node
pub fn (mut spa SemanticAnalyzerPreAnalysis) accept(node Node) {
	if node is FuncDef {
		spa.visit_func_def(node)
	} else if node is ClassDef {
		spa.visit_class_def(node)
	} else if node is ImportFrom {
		spa.visit_import_from(node)
	} else if node is ImportAll {
		spa.visit_import_all(node)
	} else if node is Import {
		spa.visit_import(node)
	} else if node is IfStmt {
		spa.visit_if_stmt(node)
	} else if node is Block {
		spa.visit_block(node)
	} else if node is MatchStmt {
		spa.visit_match_stmt(node)
	} else if node is AssignmentStmt {
		spa.visit_assignment_stmt(node)
	} else if node is ExpressionStmt {
		spa.visit_expression_stmt(node)
	} else if node is ReturnStmt {
		spa.visit_return_stmt(node)
	} else if node is ForStmt {
		spa.visit_for_stmt(node)
	}
}

// assert_will_always_fail checks if assert will always fail
fn assert_will_always_fail(node AssertStmt, options Options) bool {
	if node.expr is NameExpr {
		if node.expr.name == 'False' || node.expr.name == 'false' {
			return true
		}
	}
	if node.expr is LiteralExpr {
		if node.expr.value == 'False' || node.expr.value == 'false' {
			return true
		}
	}
	return false
}

// infer_reachability_of_if_statement determines reachability of if branches
fn infer_reachability_of_if_statement(s IfStmt, options Options) {
	for i, expr in s.expr {
		if expr is NameExpr {
			if expr.name == 'False' || expr.name == 'false' {
				if i < s.body.len {
					s.body[i].is_unreachable = true
				}
			} else if expr.name == 'True' || expr.name == 'true' {
				if s.else_body != none {
					s.else_body.is_unreachable = true
				}
			}
		} else if expr is LiteralExpr {
			if expr.value == 'False' || expr.value == 'false' {
				if i < s.body.len {
					s.body[i].is_unreachable = true
				}
			} else if expr.value == 'True' || expr.value == 'true' {
				if s.else_body != none {
					s.else_body.is_unreachable = true
				}
			}
		}
	}
	// Check sys.platform
	if options.platform != '' {
		for i, expr in s.expr {
			if expr is ComparisonExpr {
				if expr.operands.len == 2 {
					left := expr.operands[0]
					right := expr.operands[1]
					if left is NameExpr && left.name == 'sys.platform' {
						if right is StrExpr {
							match_platform := right.value == options.platform
							if expr.operators[0] == '==' {
								if !match_platform && i < s.body.len {
									s.body[i].is_unreachable = true
								}
							} else if expr.operators[0] == '!=' {
								if match_platform && i < s.body.len {
									s.body[i].is_unreachable = true
								}
							}
						}
					}
				}
			}
		}
	}
}

// infer_reachability_of_match_statement determines reachability of match branches
fn infer_reachability_of_match_statement(s MatchStmt, options Options) {
	// Basic implementation - mark guards that are always false
	for i, guard in s.guards {
		if guard != none {
			if guard is NameExpr {
				if guard.name == 'False' || guard.name == 'false' {
					if i < s.bodies.len {
						s.bodies[i].is_unreachable = true
					}
				}
			}
		}
	}
}
