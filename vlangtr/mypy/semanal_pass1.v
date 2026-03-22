// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:58
// semanal_pass1.v — Block/import reachability analysis
// Переведён из mypy/semanal_pass1.py

module mypy

// SemanticAnalyzerPreAnalysis анализирует достижимость блоков и импортов
// Выполняется до семантического анализа, поэтому имена ещё не привязаны
// Определяет статическую достижимость блоков и импортов из-за проверок версии и платформы
pub struct SemanticAnalyzerPreAnalysis {
pub mut:
	platform        string
	cur_mod_id      string
	cur_mod_node    MypyFile
	options         Options
	is_global_scope bool
	skipped_lines   map[int]bool
}

// new_semanal_pre_analysis создаёт новый SemanticAnalyzerPreAnalysis
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

// visit_file — главная точка входа
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_file(file MypyFile, fnam string, mod_id string, options Options) {
	spa.platform = options.platform
	spa.cur_mod_id = mod_id
	spa.cur_mod_node = file
	spa.options = options
	spa.is_global_scope = true
	spa.skipped_lines = map[int]bool{}

	for i, defn in file.defs {
		// TODO: вызвать accept у defn
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

// visit_func_def обрабатывает определение функции
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_func_def(node FuncDef) {
	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	// TODO: вызвать super().visit_func_def(node)
	spa.is_global_scope = old_global_scope

	file_node := spa.cur_mod_node
	if spa.is_global_scope && file_node.is_stub && node.name == '__getattr__'
		&& file_node.is_package_init_file() {
		file_node.is_partial_stub_package = true
	}
}

// visit_class_def обрабатывает определение класса
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_class_def(node ClassDef) {
	old_global_scope := spa.is_global_scope
	spa.is_global_scope = false
	// TODO: вызвать super().visit_class_def(node)
	spa.is_global_scope = old_global_scope
}

// visit_import_from обрабатывает from ... import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_from(node ImportFrom) {
	node.is_top_level = spa.is_global_scope
}

// visit_import_all обрабатывает from ... import *
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import_all(node ImportAll) {
	node.is_top_level = spa.is_global_scope
}

// visit_import обрабатывает import
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_import(node Import) {
	node.is_top_level = spa.is_global_scope
}

// visit_if_stmt обрабатывает if-оператор
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_if_stmt(s IfStmt) {
	infer_reachability_of_if_statement(s, spa.options)
	for expr in s.expr {
		// TODO: вызвать accept у expr
	}
	for node in s.body {
		// TODO: вызвать accept у node
	}
	if s.else_body {
		// TODO: вызвать accept у s.else_body
	}
}

// visit_block обрабатывает блок
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
	// TODO: вызвать super().visit_block(b)
}

// visit_match_stmt обрабатывает match-оператор
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_match_stmt(s MatchStmt) {
	infer_reachability_of_match_statement(s, spa.options)
	for guard in s.guards {
		if guard != none {
			// TODO: вызвать accept у guard
		}
	}
	for body in s.bodies {
		// TODO: вызвать accept у body
	}
}

// visit_assignment_stmt — оптимизация: не посещаем вложенные выражения
pub fn (spa SemanticAnalyzerPreAnalysis) visit_assignment_stmt(s AssignmentStmt) {
	// Ничего не делаем
}

// visit_expression_stmt — оптимизация: не посещаем вложенные выражения
pub fn (spa SemanticAnalyzerPreAnalysis) visit_expression_stmt(s ExpressionStmt) {
	// Ничего не делаем
}

// visit_return_stmt — оптимизация: не посещаем вложенные выражения
pub fn (spa SemanticAnalyzerPreAnalysis) visit_return_stmt(s ReturnStmt) {
	// Ничего не делаем
}

// visit_for_stmt обрабатывает for-цикл
pub fn (mut spa SemanticAnalyzerPreAnalysis) visit_for_stmt(s ForStmt) {
	// TODO: вызвать accept у s.body
	if s.else_body != none {
		// TODO: вызвать accept у s.else_body
	}
}

// Вспомогательные функции-заглушки
fn assert_will_always_fail(node AssertStmt, options Options) bool {
	// TODO: реализация из mypy/reachability.v
	return false
}

fn infer_reachability_of_if_statement(s IfStmt, options Options) {
	// TODO: реализация из mypy/reachability.v
}

fn infer_reachability_of_match_statement(s MatchStmt, options Options) {
	// TODO: реализация из mypy/reachability.v
}
