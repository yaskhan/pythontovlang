# Python → V 0.5.x Translation Guide
## Для проекта mypy → V transpiler

---

## 1. Что уже транслировано

| Python модуль | V файл | Статус |
|---|---|---|
| `visitor.py` | `mypy/visitor.v` | ✅ Полностью |
| `patterns.py` | `mypy/patterns.v` | ✅ Полностью |
| `nodes.py` | `mypy/nodes.v` | ✅ Ядро (без cache/serialize) |
| `types.py` | `mypy/types.v` | ✅ Все типы + TypeTranslator + BoolTypeQuery |
| `type_visitor.py` | `mypy/types.v` | ✅ Включён в types.v |
| `traverser.py` | `mypy/traverser.v` | ✅ Полностью + dispatch helpers |
| `util.py` | `mypy/util.v` | ✅ Полностью (кроме JUNIT/orjson) |
| `checker.py` | `mypy/checker.v` | 📝 TypeChecker: все Statements (classes, funcs, ifs, loops, imports, assignments) |
| `checkexpr.py` | `mypy/checkexpr.v` | 📝 Завершены визиторы: все базовые Expressions (в т.ч. Slice, Lambda, Yield) |
| `argmap.py` | `mypy/argmap.v` | 📝 Разрешение аргументов вызова функции |
| `checkmember.py`| `mypy/checkmember.v` | 📝 Начало: `analyze_instance_member_access` (методы и переменные) |
| `binder.py` | `mypy/binder.v` | ✅ Narrowing типов и управление фреймами |
| `errors.py` | `mypy/errors.v` | ✅ Полностью (ErrorInfo, ErrorWatcher, Errors, CompileError) |
| `options.py` | `mypy/options.v` | ✅ Полностью (Options, BuildType, все флаги) |
| `errorcodes.py` | `mypy/errorcodes.v` | ✅ Полностью (ErrorCode и все константы) |
| `message_registry.py` | `mypy/message_registry.v` | ✅ Полностью (ErrorMessage и константы) |
| `semanal_shared.py` | `mypy/semanal_shared.v` | ✅ Интерфейсы и общие функции анализатора |
| `semanal_classprop.py` | `mypy/semanal_classprop.v` | ✅ Вычисление свойств классов (абстрактность, ClassVar) |
| `typetraverser.py` | `mypy/typetraverser.v` | ✅ Полный обходчик типов |
| `mixedtraverser.py` | `mypy/mixedtraverser.v` | ✅ Обходчик узлов и типов (через встраивание) |
| `semanal_typeargs.py` | `mypy/semanal_typeargs.v` | ✅ Полностью (проверка аргументов типов) |
| `semanal_enum.py` | `mypy/semanal_enum.v` | ✅ Трансляция вызовов Enum |
| `semanal_typeddict.py` | `mypy/semanal_typeddict.v` | 📝 Частично (анализ ClassDef для TypedDict) |
| `semanal_namedtuple.py` | `mypy/semanal_namedtuple.v` | 📝 Частично (анализ ClassDef для NamedTuple) |
| `semanal_newtype.py` | `mypy/semanal_newtype.v` | ✅ Полностью (анализ NewType) |
| `semanal_main.py` | `mypy/semanal_main.v` | ✅ Полностью (анализ SCC для семантического анализа) |
| `mro.py` | `mypy/mro.v` | ✅ Полностью (C3 linearization для MRO) |
| `literals.py` | `mypy/literals.v` | ✅ Полностью (literal_hash, _Hasher visitor) |
| `typevars.py` | `mypy/typevars.v` | ✅ Полностью (fill_typevars, fill_typevars_with_any, has_no_typevars) |
| `tvar_scope.py` | `mypy/tvar_scope.v` | ✅ Полностью (TypeVarLikeScope, TypeVarLikeDefaultFixer) |
| `erasetype.py` | `mypy/erasetype.v` | ✅ Полностью (erase_type, erase_typevars, TypeVarEraser, LastKnownValueEraser) |
| `typestate.py` | `mypy/typestate.v` | ✅ Полностью (TypeState, subtype caches, protocol dependencies) |
| `state.py` | `mypy/state.v` | ✅ Полностью (StrictOptionalState, global state, with_strict_optional) |
| `defaults.py` | `mypy/defaults.v` | ✅ Полностью (константы: версии Python, cache, config, reporter names) |
| `operators.py` | `mypy/operators.v` | ✅ Полностью (op_methods, reverse_op_methods, inplace_operator_methods, утилиты) |
| `split_namespace.py` | `mypy/split_namespace.v` | ✅ Полностью (SplitNamespace для argparse с префиксами) |
| `version.py` | `mypy/version.v` | ✅ Полностью (__version__, VersionInfo, parse_version, compare_versions) |
| `pyinfo.py` | `mypy/pyinfo.v` | ✅ Полностью (getsitepackages, getsyspath, getsearchdirs, утилиты) |
| `stubinfo.py` | `mypy/stubinfo.v` | ✅ Полностью (stub_distribution_name, is_module_from_legacy_bundled_package) |
| `sharedparse.py` | `mypy/sharedparse.v` | ✅ Полностью (magic_methods, special_function_elide_names, argument_elide_name) |
| `build.py` | `mypy/build.v` | 📝 Полуготово: State, BuildManager, SCC, BuildResult, topological sort |
| `bogus_type.py` | `mypy/bogus_type.v` | ✅ Полностью (константа `mypyc`, alias helpers `bogus`/`bogus_erased`) |
| `__init__.py` | `mypy/__init__.v` | ? ��������� (������ ������-�������� ��� � Python) |
| `__main__.py` | `mypy/__main__.v` | 📝 Каркас перенесён (entry wrapper: `console_entry`, `run_dunder_main`) |
| `checker_state.py` | `mypy/checker_state.v` | ✅ Полностью (TypeCheckerState + временная установка контекста) |
| `error_formatter.py` | `mypy/error_formatter.v` | ✅ Полностью (ErrorFormatter + JSONFormatter + `output_choices`) |
| `api.py` | `mypy/api.v` | 📝 Каркас API (`_run`, `run`) до переноса `main.py` |
| `fswatcher.py` | `mypy/fswatcher.v` | ✅ Полностью (FileSystemWatcher, FileData, изменения файлов по stat/hash) |
| `semanal_infer.py` | `mypy/semanal_infer.v` | 📝 Перенесены ключевые эвристики для декораторов (`infer_decorator_signature_if_simple`) |
| `parse.py` | `mypy/parse.v` | 📝 Каркас парсинга и `load_from_raw` (native/fast parser hooks) |
| `infer.py` | `mypy/infer.v` | 📝 Заглушки: `infer_type_arguments`, `infer_function_type_arguments`, `Constraint` |
| `solve.py` | `mypy/solve.v` | 📝 Решатель ограничений (solve_one, join of lowers, meet of uppers) |
| `copytype.py` | `mypy/copytype.v` | ✅ Полностью (copy_type, TypeShallowCopier через match) |
| `maptype.py` | `mypy/maptype.v` | ✅ Полностью (map_instance_to_supertype, map_instance_to_supertypes, class_derivation_paths) |
| `typevartuples.py` | `mypy/typevartuples.v` | ✅ Полностью (split_with_instance, erased_vars) |
| `graph_utils.py` | `mypy/graph_utils.v` | ✅ Полностью (strongly_connected_components, prepare_sccs, TopSort) |
| `refinfo.py` | `mypy/refinfo.v` | ✅ Полностью (RefInfoVisitor, type_fullname, get_undocumented_ref_info_json) |
| `scope.py` | `mypy/scope.v` | ✅ Полностью (Scope, SavedScope, module/class/function scopes) |
| `lookup.py` | `mypy/lookup.v` | ✅ Полностью (lookup_fully_qualified) |
| `state.py` | `mypy/state.v` | ✅ Полностью (StrictOptionalState, state, find_occurrences) |
| `defaults.py` | `mypy/defaults.v` | ✅ Полностью (Python3_VERSION, CACHE_DIR, CONFIG_NAMES, reporter_names, timeouts) |
| `stubinfo.py` | `mypy/stubinfo.v` | ✅ Полностью (stub_distribution_name, is_module_from_legacy_bundled_package) |
| `freetree.py` | `mypy/freetree.v` | ✅ Полностью (TreeFreer, free_tree) |
| `pyinfo.py` | `mypy/pyinfo.v` | ✅ Полностью (getsite_packages, getsyspath, getsearch_dirs) |
| `version.py` | `mypy/version.v` | ✅ Полностью (__version__, base_version) |
| `meet.py` | `mypy/meet.v` | 📝 Базовые `meet_types`, `is_overlapping_types` |
| `join.py` | `mypy/join.v` | 📝 Базовые `join_types`, `join_type_list` |
| `subtypes.py` | `mypy/subtypes.v` | 📝 Основная логика `is_subtype` (Instance, Callable, Union) |
| `checkpattern.py` | `mypy/checkpattern.v` | 📝 PatternChecker: `visit_match_stmt` |
| `expandtype.py` | `mypy/expandtype.v` | 📝 Подстановка `TypeVar` через контекст инстанса (`expand_type`) |
| `lookup.py` | `mypy/lookup.v` | 📝 Поиск символов в глобальной таблице (lookup_fully_qualified) |
| `plugin.py` | `mypy/plugin.v` | 📝 Система плагинов (Contexts, Interfaces, ChainedPlugin) |
| `typeanal.py` | `mypy/typeanal.v` | 📝 Семантический анализатор для типов (TypeAnalyser, UnboundType -> Instance) |
| `constraints.py` | `mypy/constraints.v` | 📝 Вывод ограничений типов: Constraint, infer_constraints, any_constraints, filter_imprecise_kinds |
| `constant_fold.py` | `mypy/constant_fold.v` | ✅ Полностью (constant_fold_expr, binary/unary ops, int/float/string) |
| `strconv.py` | `mypy/strconv.v` | 📝 StrConv visitor: dump, visit_* для узлов AST, func_helper, pretty_name, IdMapper |
| `partially_defined.py` | `mypy/partially_defined.v` | 📝 BranchState, BranchStatement, DefinedVariableTracker, Scope, Loop |
| `renaming.py` | `mypy/renaming.v` | 📝 VariableRenameVisitor, BlockGuard/TryGuard/LoopGuard/ScopeGuard |
| `config_parser.py` | `mypy/config_parser.v` | 📝 parse_version, try_split, expand_path, ini/toml_config_types, split_directive |
| `types_utils.py` | `mypy/types_utils.v` | 📝 flatten_types, strip_type, is_union_with_any, remove_optional, store_argument_type |
| `semanal_pass1.py` | `mypy/semanal_pass1.v` | 📝 SemanticAnalyzerPreAnalysis: visit_file, visit_if_stmt, visit_block, reachability |
| `semanal_infer.py` | `mypy/semanal_infer.v` | 📝 infer_decorator_signature_if_simple, is_identity_signature, calculate_return_type |
| `checkstrformat.py` | `mypy/checkstrformat.v` | 📝 StringFormatterChecker, ConversionSpecifier, parse_conversion_specifiers, conversion_type |
| `cache.py` | `mypy/cache.v` | 📝 CacheMeta, ErrorInfo, FF serialization tags, read/write literals, lists, JSON |
| `indirection.py` | `mypy/indirection.v` | ✅ Полностью (TypeIndirectionVisitor для анализа зависимостей модулей) |
| `stats.py` | `mypy/stats.v` | ✅ Полностью (StatisticsVisitor для сбора статистики о типах) |
| `ipc.py` | `mypy/ipc.v` | ✅ Полностью (IPCBase, IPCClient, IPCServer, IPCMessage, WriteBuffer, ReadBuffer) |
| `reachability.py` | `mypy/reachability.v` | ✅ Полностью (infer_reachability_of_if_statement, infer_condition_value, mark_block_unreachable) |
| `evalexpr.py` | `mypy/evalexpr.v` | ✅ Полностью (NodeEvaluator, evaluate_expression для вычисления выражений) |
| `moduleinspect.py` | `mypy/moduleinspect.v` | ✅ Полностью (ModuleProperties, ModuleInspect, get_package_properties, is_c_module) |
| `find_sources.py` | `mypy/find_sources.v` | ✅ Полностью (SourceFinder, create_source_list, crawl_up, find_sources_in_dir) |
| `metastore.py` | `mypy/metastore.v` | ✅ Полностью (MetadataStore интерфейс, FilesystemMetadataStore, SqliteMetadataStore) |

---



---

## 3. Ключевые правила трансляции Python → V 0.5.x

### 3.1 Иерархия классов → интерфейсы + sum-types

```python
# Python
class Node:
    pass
class Statement(Node):
    pass
class AssignmentStmt(Statement):
    lvalues: list[Expression]
    rvalue: Expression
```

```v
// V: базовые классы → интерфейсы или встраиваемые структуры
pub interface Node {
    get_context() Context
    accept(v NodeVisitor) !string
}

// Конкретные узлы — обычные struct
pub struct AssignmentStmt {
pub mut:
    base    NodeBase
    lvalues []Expression
    rvalue  Expression
}

// "Полиморфизм" через sum-type
pub type Statement = AssignmentStmt | ForStmt | IfStmt | ...
```

### 3.2 Опциональные поля (X | None)

```python
# Python
end_line: int | None = None
expr: Expression | None
```

```v
// V: ?Type
pub mut:
    end_line ?int
    expr     ?Expression
```

Работа с опциональными полями:
```v
// V: if let аналог
if e := o.expr {
    expr_accept(e, v)!
}

// Или через or {}
val := o.expr or { return '' }
```

### 3.3 Методы с default-реализацией (@abstractmethod / pass)

```python
# Python
class NodeVisitor(Generic[T]):
    def visit_int_expr(self, o: IntExpr) -> T:
        raise NotImplementedError()
```

```v
// V: интерфейс — все методы обязательны для реализации
pub interface NodeVisitor {
    visit_int_expr(o &IntExpr) !string
    // ...
}

// Конкретный traverser — struct, реализующий все методы
pub struct NodeTraverser {}

pub fn (t &NodeTraverser) visit_int_expr(o &IntExpr) !string { return '' }
```

### 3.4 Generic[T] → !string + обёртка

Python использует `Generic[T]` чтобы visitor возвращал разные типы.
В V используем `!string` как универсальный возврат. Для типизированных результатов:

```v
// Visitor возвращающий реальные структуры — оберните в свой struct
pub struct TypeStrVisitor {
pub mut:
    result string
}

pub fn (mut v TypeStrVisitor) visit_int_expr(o &IntExpr) !string {
    v.result = o.value.str()
    return v.result
}
```

### 3.5 isinstance() → match на sum-type

```python
# Python
if isinstance(target, int):
    self.line = target
elif isinstance(target, Context):
    self.line = target.line
```

```v
// V: match на sum-type или интерфейсный is
match target {
    int     { c.line = target }
    Context { c.line = target.line }
}

// Или для интерфейса:
if target is MyStruct {
    // target автоматически приведён к MyStruct
}
```

### 3.6 @property с lazy init

```python
# Python
@property
def can_be_true(self) -> bool:
    if self._can_be_true == -1:
        self._can_be_true = self.can_be_true_default()
    return bool(self._can_be_true)
```

```v
// V: обычный mut метод с кэшем
pub fn (mut t TypeBase) can_be_true() bool {
    if t._can_be_true == -1 {
        t._can_be_true = 1 // или вызов логики
    }
    return t._can_be_true == 1
}
```

### 3.7 ClassVar / Final → константы модуля

```python
# Python
class TypeOfAny:
    unannotated: Final = 1
    explicit: Final = 2
```

```v
// V: enum (предпочтительно) или module-level const
pub enum TypeOfAny {
    unannotated
    explicit
    from_unimported_type
    // ...
}

// Или const если нужны конкретные int значения:
pub const type_of_any_unannotated = 1
pub const type_of_any_explicit    = 2
```

### 3.8 dict[str, Any] / map → map с конкретным типом

```python
# Python
names: dict[str, SymbolTableNode]
items: dict[str, Type]
```

```v
// V: типизированные map
pub mut:
    names map[string]SymbolTableNode
    items map[string]MypyTypeNode

// Инициализация
names := map[string]SymbolTableNode{}
```

### 3.9 list comprehension → map/filter или явный цикл

```python
# Python
result = [t.accept(self) for t in types]
filtered = [x for x in items if x is not None]
```

```v
// V: arrays module или явный for
result := types.map(it.accept(v) or { panic('visitor error') })

// С фильтром:
mut filtered := []MyType{}
for x in items {
    if x != none {
        filtered << x
    }
}

// Более идиоматично через arrays:
// import arrays — если нужен filter
filtered := items.filter(it != MyType(none))
```

### 3.10 try/except → or {} / !Type

```python
# Python
try:
    result = do_something()
except ValueError as e:
    handle(e)
```

```v
// V: результирующий тип !T
result := do_something() or {
    handle_error(err)
    return
}

// Или propagate:
result := do_something()!
```

### 3.11 Множественное наследование

```python
# Python
class FuncDef(FuncItem, SymbolNode, Statement):
    pass
```

```v
// V: нет множественного наследования.
// Решение: embedded structs + интерфейсы

pub struct FuncDef {
pub mut:
    base       NodeBase   // встраиваем общую базу
    func_base  FuncBase   // поля из FuncItem/FuncBase
    name       string
    // ... остальные поля
}

// Принадлежность к Statement и SymbolNode
// выражена через включение FuncDef в sum-types Statement / SymbolNodeRef
```

### 3.12 Circular imports → forward declarations через интерфейс

```python
# Python (nodes.py и types.py импортируют друг друга)
if TYPE_CHECKING:
    import mypy.types
```

```v
// V: определите интерфейс MypyType в nodes.v,
// реализуйте его в types.v через MypyTypeNode.
// Конкретный тип остаётся непрозрачным для nodes.v.

pub interface MypyType {
    type_str() string
}
```

---

## 4. Dispatch helpers — обязательный паттерн

Поскольку V требует явного `match` для sum-types,
для каждого sum-type создайте dispatch helper:

```v
// В traverser.v или отдельном dispatch.v
pub fn stmt_accept(s Statement, v NodeVisitor) !string {
    return match s {
        AssignmentStmt { v.visit_assignment_stmt(&s)! }
        ForStmt        { v.visit_for_stmt(&s)! }
        // ... все варианты
    }
}

pub fn expr_accept(e Expression, v NodeVisitor) !string {
    return match e {
        IntExpr  { v.visit_int_expr(&e)! }
        StrExpr  { v.visit_str_expr(&e)! }
        // ...
    }
}
```

---

## 5. Структура модулей V

```
mypy_v/
  mypy/
    visitor.v       ← NodeVisitor, ExpressionVisitor, StatementVisitor, PatternVisitor
    nodes.v         ← AST node structs, Statement/Expression sum-types, MypyFile
    patterns.v      ← Pattern structs and PatternNode sum-type
    types.v         ← Type structs, MypyTypeNode sum-type, TypeVisitor, BoolTypeQuery
    traverser.v     ← NodeTraverser (default no-op), stmt_accept, expr_accept
    errors.v        ← ✅ ErrorInfo, ErrorWatcher, Errors, CompileError
    options.v       ← ✅ Options, BuildType, все флаги конфигурации
    errorcodes.v    ← ✅ ErrorCode и все константы кодов ошибок
    util.v          ← (следующий шаг)
    checker.v       ← (позже, разбить на несколько файлов)
    build.v         ← (позже)
```

---

## 6. Известные ограничения V 0.5.x

| Проблема | Решение |
|---|---|
| Нет generics на интерфейсах как в Python | Используй `!string` + явные конверсии |
| Sum-type не может содержать рекурсивные ссылки на себя | Используй `?&T` или вспомогательный wrapper struct |
| Нет `__hash__` → нельзя использовать struct как ключ map | Используй string-ключи (fullname, id.str()) |
| `mut` строго проверяется | Не помечай `mut` поля которые не мутируются |
| Нет ключевых аргументов в функциях с default | Используй именованные struct init `Foo{ field: val }` |
| Python `set` → V нет встроенного set | Используй `map[K]bool` |

---

## 7. Пример конкретной трансляции: checker.py фрагмент

```python
# Python checker.py
class TypeChecker(NodeVisitor[None]):
    def visit_assignment_stmt(self, s: AssignmentStmt) -> None:
        self.check_assignment(s.lvalues, s.rvalue)
    
    def check_assignment(self, lvalues: list[Lvalue], rvalue: Expression) -> None:
        for lvalue in lvalues:
            self.check_lvalue(lvalue)
```

```v
// V checker.v
pub struct TypeChecker {
pub mut:
    errors  Errors
    options Options
    // ...
}

pub fn (mut tc TypeChecker) visit_assignment_stmt(s &AssignmentStmt) !string {
    tc.check_assignment(s.lvalues, s.rvalue)!
    return ''
}

pub fn (mut tc TypeChecker) check_assignment(lvalues []Expression, rvalue Expression) ! {
    for lv in lvalues {
        tc.check_lvalue(lv)!
    }
}
```
