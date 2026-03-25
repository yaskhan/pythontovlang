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
	cur_mod_node    ?&MypyFile
	options         Options
	is_global_scope bool
	skipped_lines   map[int]bool
}

// new_semanal_pre_analysis creates a new SemanticAnalyzerPreAnalysis
pub fn new_semanal_pre_analysis() SemanticAnalyzerPreAnalysis {
	return SemanticAnalyzerPreAnalysis{
		platform:        ''
		cur_mod_id:      ''
		cur_mod_node:    none
		options:         Options{}
		is_global_scope: true
		skipped_lines:   map[int]bool{}
	}
}

// visit_file — main entry point
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_file(mut file MypyFile, fnam string, mod_id string, options Options) {
	spa.platform = options.platform
	spa.cur_mod_id = mod_id
	spa.cur_mod_node = &file
	spa.options = options
	spa.is_global_scope = true
	spa.skipped_lines = map[int]bool{}

	for i, mut defn in file.defs {
		spa.accept(mut Node(defn))
		if defn is AssertStmt {
			if assert_will_always_fail(defn as AssertStmt, options) {
				if i < file.defs.len - 1 {
					next_def := file.defs[i + 1]
					last := file.defs[file.defs.len - 1]
					if end_ln := last.get_context().end_line {
						start := next_def.get_context().line
						for line in start .. end_ln + 1 {
							spa.skipped_lines[line] = true
						}
					}
				}
				file.imports = file.imports.filter(it.get_context().line < defn.get_context().line
					|| (it.get_context().line == defn.get_context().line && it.get_context().column <= defn.get_context().column))
				file.defs = file.defs[..i + 1]
				break
			}
		}
	}
	file.ignored_lines = spa.skipped_lines.keys()
}

// visit_func_def handles function definition
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_func_def(mut node FuncDef) {
	for mut arg in node.arguments {
		spa.visit_argument(mut arg)
	}

	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	spa.accept(mut Node(node.body))
	spa.is_global_scope = old_global_scope
	mut file_node := spa.cur_mod_node or { return }
	if spa.is_global_scope && file_node.is_stub && node.name == '__getattr__'
		&& file_node.is_package_init_file() {
		file_node.is_partial_stub_package = true
	}
}

// visit_class_def handles class definition
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_class_def(mut node ClassDef) {
	for mut dec in node.decorators {
		spa.accept(mut Node(dec))
	}

	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	spa.accept(mut Node(node.defs))
	spa.is_global_scope = old_global_scope
}

// visit_decorator handles decorator
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_decorator(mut node Decorator) {
	for mut dec in node.decorators {
		spa.accept(mut Node(dec))
	}
	spa.visit_func_def(mut node.func)
}

// visit_argument handles function argument
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_argument(mut node Argument) {
	if mut init := node.initializer {
		spa.accept(mut Node(init))
	}
}

// visit_import_from handles from ... import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_from(mut node ImportFrom) {
	node.is_top_level = spa.is_global_scope
}

// visit_import_all handles from ... import *
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_all(mut node ImportAll) {
	node.is_top_level = spa.is_global_scope
}

// visit_import handles import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import(mut node Import) {
	node.is_top_level = spa.is_global_scope
}

// visit_if_stmt handles if statement
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_if_stmt(mut s IfStmt) {
	infer_reachability_of_if_statement(mut s, spa.options)
	for mut expr in s.expr {
		spa.accept(mut Node(expr))
	}
	for mut node in s.body {
		spa.accept(mut Node(node))
	}
	if mut eb := s.else_body {
		spa.accept(mut Node(eb))
	}
}

// visit_block handles block
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_block(mut b Block) {
	if b.is_unreachable {
		if end_ln := b.get_context().end_line {
			start := b.get_context().line
			for line in start .. end_ln + 1 {
				spa.skipped_lines[line] = true
			}
		}
		return
	}
	for mut stmt in b.body {
		spa.accept(mut Node(stmt))
	}
}

// visit_match_stmt handles match statement
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_match_stmt(mut s MatchStmt) {
	infer_reachability_of_match_statement(mut s, spa.options)
	for mut guard in s.guards {
		if mut g := guard {
			spa.accept(mut g)
		}
	}
	for mut body in s.bodies {
		spa.accept(mut body)
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

pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_for_stmt(mut s ForStmt) {
	spa.accept(mut Node(s.body))
	if mut eb := s.else_body {
		spa.accept(mut Node(eb))
	}
}

// accept calls the corresponding visit_ method for the node
pub fn (mut spa SemanticAnalyzerPreAnalysis) accept(mut node Node) {
	if mut node is FuncDef {
		spa.visit_func_def(mut node)
	} else if mut node is ClassDef {
		spa.visit_class_def(mut node)
	} else if mut node is Decorator {
		spa.visit_decorator(mut node)
	} else if mut node is ImportFrom {
		spa.visit_import_from(mut node)
	} else if mut node is ImportAll {
		spa.visit_import_all(mut node)
	} else if mut node is Import {
		spa.visit_import(mut node)
	} else if mut node is IfStmt {
		spa.visit_if_stmt(mut node)
	} else if mut node is Block {
		spa.visit_block(mut node)
	} else if mut node is MatchStmt {
		spa.visit_match_stmt(mut node)
	} else if mut node is AssignmentStmt {
		spa.visit_assignment_stmt(node)
	} else if mut node is ExpressionStmt {
		spa.visit_expression_stmt(node)
	} else if mut node is ReturnStmt {
		spa.visit_return_stmt(node)
	} else if mut node is ForStmt {
		spa.visit_for_stmt(mut node)
	}
}

