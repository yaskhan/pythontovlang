// Я Cline работаю над этим файлом. Начало: 2026-03-22 14:45
// partially_defined.v — Detects partially defined variables
// Переведён из mypy/partially_defined.py

module mypy

// BranchState содержит информацию об определении переменных в конце ветвящегося оператора
// `if` и `match` — примеры ветвящихся операторов
// `may_be_defined` — переменные, определённые только в некоторых ветках
// `must_be_defined` — переменные, определённые во всех ветках
pub struct BranchState {
pub mut:
	may_be_defined  map[string]bool
	must_be_defined map[string]bool
	skipped         bool
}

// new_branch_state создаёт новый BranchState
pub fn new_branch_state(must_be_defined map[string]bool, may_be_defined map[string]bool, skipped bool) BranchState {
	return BranchState{
		may_be_defined:  may_be_defined.clone()
		must_be_defined: must_be_defined.clone()
		skipped:         skipped
	}
}

// copy создаёт копию BranchState
pub fn (bs BranchState) copy() BranchState {
	return BranchState{
		may_be_defined:  bs.may_be_defined.clone()
		must_be_defined: bs.must_be_defined.clone()
		skipped:         bs.skipped
	}
}

// BranchStatement управляет состоянием ветвления
pub struct BranchStatement {
pub mut:
	initial_state BranchState
	branches      []BranchState
}

// new_branch_statement создаёт новый BranchStatement
pub fn new_branch_statement(initial_state ?BranchState) BranchStatement {
	init := initial_state or { BranchState{} }
	return BranchStatement{
		initial_state: init
		branches:      [
			BranchState{
				must_be_defined: init.must_be_defined.clone()
				may_be_defined:  init.may_be_defined.clone()
			},
		]
	}
}

// copy создаёт копию BranchStatement
pub fn (bs BranchStatement) copy() BranchStatement {
	mut result := new_branch_statement(bs.initial_state)
	result.branches = bs.branches.map(it.copy())
	return result
}

// next_branch начинает новую ветку
pub fn (mut bs BranchStatement) next_branch() {
	bs.branches << BranchState{
		must_be_defined: bs.initial_state.must_be_defined.clone()
		may_be_defined:  bs.initial_state.may_be_defined.clone()
	}
}

// record_definition записывает определение переменной
pub fn (mut bs BranchStatement) record_definition(name string) {
	if bs.branches.len > 0 {
		bs.branches[bs.branches.len - 1].must_be_defined[name] = true
		bs.branches[bs.branches.len - 1].may_be_defined.delete(name)
	}
}

// delete_var удаляет переменную из отслеживания
pub fn (mut bs BranchStatement) delete_var(name string) {
	if bs.branches.len > 0 {
		bs.branches[bs.branches.len - 1].must_be_defined.delete(name)
		bs.branches[bs.branches.len - 1].may_be_defined.delete(name)
	}
}

// record_nested_branch записывает результат вложенного ветвления
pub fn (mut bs BranchStatement) record_nested_branch(state BranchState) {
	if bs.branches.len > 0 {
		mut current := bs.branches[bs.branches.len - 1]
		if state.skipped {
			current.skipped = true
			return
		}
		for k in state.must_be_defined.keys() {
			current.must_be_defined[k] = true
		}
		for k in state.may_be_defined.keys() {
			current.may_be_defined[k] = true
		}
		for k in current.must_be_defined.keys() {
			current.may_be_defined.delete(k)
		}
	}
}

// skip_branch пропускает текущую ветку
pub fn (mut bs BranchStatement) skip_branch() {
	if bs.branches.len > 0 {
		bs.branches[bs.branches.len - 1].skipped = true
	}
}

// is_possibly_undefined проверяет, может ли переменная быть неопределённой
pub fn (bs BranchStatement) is_possibly_undefined(name string) bool {
	if bs.branches.len > 0 {
		return name in bs.branches[bs.branches.len - 1].may_be_defined
	}
	return false
}

// is_undefined проверяет, неопределённа ли переменная
pub fn (bs BranchStatement) is_undefined(name string) bool {
	if bs.branches.len > 0 {
		branch := bs.branches[bs.branches.len - 1]
		return name !in branch.may_be_defined && name !in branch.must_be_defined
	}
	return true
}

// is_defined_in_a_branch проверяет, определена ли переменная хотя бы в одной ветке
pub fn (bs BranchStatement) is_defined_in_a_branch(name string) bool {
	for b in bs.branches {
		if name in b.must_be_defined || name in b.may_be_defined {
			return true
		}
	}
	return false
}

// done завершает ветвление и возвращает итоговое состояние
pub fn (bs BranchStatement) done() BranchState {
	mut all_vars := map[string]bool{}
	for b in bs.branches {
		for k in b.may_be_defined.keys() {
			all_vars[k] = true
		}
		for k in b.must_be_defined.keys() {
			all_vars[k] = true
		}
	}
	non_skipped := bs.branches.filter(!it.skipped)
	mut must_be_defined := map[string]bool{}
	if non_skipped.len > 0 {
		for k in non_skipped[0].must_be_defined.keys() {
			must_be_defined[k] = true
		}
		for i in 1 .. non_skipped.len {
			mut to_remove := []string{}
			for k in must_be_defined.keys() {
				if k !in non_skipped[i].must_be_defined {
					to_remove << k
				}
			}
			for k in to_remove {
				must_be_defined.delete(k)
			}
		}
	}
	mut may_be_defined := map[string]bool{}
	for k in all_vars.keys() {
		if k !in must_be_defined {
			may_be_defined[k] = true
		}
	}
	return BranchState{
		must_be_defined: must_be_defined
		may_be_defined:  may_be_defined
		skipped:         non_skipped.len == 0
	}
}

// ScopeType — тип области видимости
pub enum ScopeType {
	global
	class
	func
	generator
}

// Scope — область видимости с отслеживанием ветвлений
pub struct Scope {
pub mut:
	branch_stmts   []BranchStatement
	scope_type     ScopeType
	undefined_refs map[string][]NameExpr
}

// new_scope создаёт новую Scope
pub fn new_scope(stmts []BranchStatement, scope_type ScopeType) Scope {
	return Scope{
		branch_stmts:   stmts
		scope_type:     scope_type
		undefined_refs: map[string][]NameExpr{}
	}
}

// copy создаёт копию Scope
pub fn (s Scope) copy() Scope {
	mut result := new_scope(s.branch_stmts.map(it.copy()), s.scope_type)
	for k, v in s.undefined_refs {
		result.undefined_refs[k] = v.clone()
	}
	return result
}

// record_undefined_ref записывает неопределённую ссылку
pub fn (mut s Scope) record_undefined_ref(o NameExpr) {
	if o.name !in s.undefined_refs {
		s.undefined_refs[o.name] = []NameExpr{}
	}
	s.undefined_refs[o.name] << o
}

// pop_undefined_ref извлекает неопределённые ссылки для имени
pub fn (mut s Scope) pop_undefined_ref(name string) []NameExpr {
	if name in s.undefined_refs {
		refs := s.undefined_refs[name]
		s.undefined_refs.delete(name)
		return refs
	}
	return []
}

// DefinedVariableTracker управляет состоянием и областью видимости для UndefinedVariablesVisitor
pub struct DefinedVariableTracker {
pub mut:
	scopes              []Scope
	disable_branch_skip bool
	in_finally          bool
}

// new_defined_variable_tracker создаёт новый трекер
pub fn new_defined_variable_tracker() DefinedVariableTracker {
	return DefinedVariableTracker{
		scopes:              [
			new_scope([new_branch_statement(none)], ScopeType.global),
		]
		disable_branch_skip: false
		in_finally:          false
	}
}

// copy создаёт копию трекера
pub fn (dvt DefinedVariableTracker) copy() DefinedVariableTracker {
	return DefinedVariableTracker{
		scopes:              dvt.scopes.map(it.copy())
		disable_branch_skip: dvt.disable_branch_skip
		in_finally:          dvt.in_finally
	}
}

// _scope возвращает текущую область видимости
fn (dvt DefinedVariableTracker) _scope() Scope {
	return dvt.scopes[dvt.scopes.len - 1]
}

// enter_scope входит в новую область видимости
pub fn (mut dvt DefinedVariableTracker) enter_scope(scope_type ScopeType) {
	mut initial_state := ?BranchState(none)
	if scope_type == ScopeType.generator {
		initial_state = dvt._scope().branch_stmts[dvt._scope().branch_stmts.len - 1].branches.last()
	}
	dvt.scopes << new_scope([new_branch_statement(initial_state)], scope_type)
}

// exit_scope выходит из текущей области видимости
pub fn (mut dvt DefinedVariableTracker) exit_scope() {
	dvt.scopes.pop()
}

// in_scope проверяет, находимся ли мы в указанной области видимости
pub fn (dvt DefinedVariableTracker) in_scope(scope_type ScopeType) bool {
	return dvt._scope().scope_type == scope_type
}

// start_branch_statement начинает новое ветвящееся оператор
pub fn (mut dvt DefinedVariableTracker) start_branch_statement() {
	dvt.scopes[dvt.scopes.len - 1].branch_stmts << new_branch_statement(dvt._scope().branch_stmts.last().branches.last())
}

// next_branch переходит к следующей ветке
pub fn (mut dvt DefinedVariableTracker) next_branch() {
	if dvt._scope().branch_stmts.len > 1 {
		dvt.scopes[dvt.scopes.len - 1].branch_stmts[dvt._scope().branch_stmts.len - 1].next_branch()
	}
}

// end_branch_statement завершает ветвящееся оператор
pub fn (mut dvt DefinedVariableTracker) end_branch_statement() {
	if dvt._scope().branch_stmts.len > 1 {
		result := dvt.scopes[dvt.scopes.len - 1].branch_stmts.pop().done()
		dvt.scopes[dvt.scopes.len - 1].branch_stmts[dvt._scope().branch_stmts.len - 1].record_nested_branch(result)
	}
}

// skip_branch пропускает текущую ветку
pub fn (mut dvt DefinedVariableTracker) skip_branch() {
	if dvt._scope().branch_stmts.len > 1 && !dvt.disable_branch_skip {
		dvt.scopes[dvt.scopes.len - 1].branch_stmts[dvt._scope().branch_stmts.len - 1].skip_branch()
	}
}

// record_definition записывает определение переменной
pub fn (mut dvt DefinedVariableTracker) record_definition(name string) {
	dvt.scopes[dvt.scopes.len - 1].branch_stmts[dvt._scope().branch_stmts.len - 1].record_definition(name)
}

// delete_var удаляет переменную
pub fn (mut dvt DefinedVariableTracker) delete_var(name string) {
	dvt.scopes[dvt.scopes.len - 1].branch_stmts[dvt._scope().branch_stmts.len - 1].delete_var(name)
}

// record_undefined_ref записывает неопределённую ссылку
pub fn (mut dvt DefinedVariableTracker) record_undefined_ref(o NameExpr) {
	dvt.scopes[dvt.scopes.len - 1].record_undefined_ref(o)
}

// pop_undefined_ref извлекает неопределённые ссылки
pub fn (mut dvt DefinedVariableTracker) pop_undefined_ref(name string) []NameExpr {
	return dvt.scopes[dvt.scopes.len - 1].pop_undefined_ref(name)
}

// is_possibly_undefined проверяет, может ли переменная быть неопределённой
pub fn (dvt DefinedVariableTracker) is_possibly_undefined(name string) bool {
	return dvt._scope().branch_stmts[dvt._scope().branch_stmts.len - 1].is_possibly_undefined(name)
}

// is_defined_in_different_branch проверяет, определена ли переменная в другой ветке
pub fn (dvt DefinedVariableTracker) is_defined_in_different_branch(name string) bool {
	stmt := dvt._scope().branch_stmts[dvt._scope().branch_stmts.len - 1]
	if !stmt.is_undefined(name) {
		return false
	}
	for s in dvt._scope().branch_stmts {
		if s.is_defined_in_a_branch(name) {
			return true
		}
	}
	return false
}

// is_undefined проверяет, неопределённа ли переменная
pub fn (dvt DefinedVariableTracker) is_undefined(name string) bool {
	return dvt._scope().branch_stmts[dvt._scope().branch_stmts.len - 1].is_undefined(name)
}

// Loop — информация о цикле
pub struct Loop {
pub mut:
	has_break  bool
	break_vars ?map[string]bool
}

// new_loop создаёт новый Loop
pub fn new_loop() Loop {
	return Loop{
		has_break:  false
		break_vars: none
	}
}
