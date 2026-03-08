# LLM-комментарии для доработки кода

Транслятор Python → V автоматически вставляет специальные комментарии `//##LLM@@` в сгенерированный V-код. Эти комментарии помогают разработчикам и ИИ-ассистентам быстро находить места, где требуется ручная доработка из-за фундаментальных различий между Python и V.

## Формат комментариев

Все LLM-комментарии начинаются с префикса `//##LLM@@` и содержат:
- Описание проблемы или особенности Python-кода
- Рекомендации по ручной доработке на V
- При необходимости — примеры кода или временные решения

**Пример:**
```v
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
pub fn wrapper(args ...Any, kwargs map[string]Any) {
    // ...
}
```

## Категории LLM-комментариев

### 1. Функции и параметры

| Ситуация | Комментарий |
|----------|-------------|
| Функция с `*args` и `**kwargs` одновременно | Требует перестановки параметров (variadic должен быть последним) |
| Необычное имя функции после транслитерации | Рекомендуется упростить имя |
| Перегруженные функции | Рекомендуется консолидировать или упростить имена |
| `global`/`nonlocal` в функциях | V не поддерживает глобальное состояние напрямую |
| Немаппированные dunder-методы | Требуется ручная реализация поведения |

**Пример Python:**
```python
def wrapper(*args, **kwargs):
    pass
```

**Сгенерированный V:**
```v
//##LLM@@ Function `wrapper` has both *args and **kwargs. V requires the variadic parameter (...args) to be the final parameter. Please reorder the parameters so that the variadic parameter is last, and update all calls to this function accordingly.
pub fn wrapper(args ...Any, kwargs map[string]Any) {
    // ...
}
```

### 2. Динамические операции

| Ситуация | Комментарий |
|----------|-------------|
| `getattr`/`setattr`/`hasattr` | V требует статической типизации полей |
| `eval()`/`exec()`/`compile()` | Динамическое выполнение кода не поддерживается в V |
| `del` для переменных | V не поддерживает удаление переменных из scope |
| `del` для атрибутов | V не поддерживает удаление атрибутов структур |

**Пример Python:**
```python
value = getattr(obj, 'attr', None)
```

**Сгенерированный V:**
```v
//##LLM@@ Dynamic attribute access (getattr/setattr/hasattr) used here. V structs are strictly typed at compile time. Please refactor using explicit struct fields, V's compile-time reflection ($for field in struct), or interfaces.
value := $if obj.has_field('attr') { true } $else { false }
```

### 3. Исключения и обработка ошибок

| Ситуация | Комментарий |
|----------|-------------|
| `try/except/finally` | V использует Result/Option типы вместо исключений |
| Bare `except:` | Может ловить неожиданные V panic/error |
| `except*` (ExceptionGroup) | V не поддерживает групповую обработку исключений |
| `continue` в `finally` | V `defer` не может использоваться здесь |
| Bare `raise` вне exception block | V не может re-raise без активной ошибки |

**Пример Python:**
```python
try:
    risky_operation()
except:
    print("Error occurred")
```

**Сгенерированный V:**
```v
//##LLM@@ Python try/except/finally block detected. V uses Result/Option types for error handling. Please refactor this function to return a Result (!Type) or Option (?Type), and handle errors using V's 'or { ... }' or '?' syntax.
risky_operation() or {
    //##LLM@@ Bare 'except:' block detected. This is generally bad practice and may inadvertently catch unexpected V panics/errors. Please review and restrict the caught exception types if possible.
    println('Error occurred')
}
```

### 4. Циклы и итерации

| Ситуация | Комментарий |
|----------|-------------|
| `enumerate()` с одной переменной | Требуется распаковать индекс и значение |
| Async comprehensions | Требуется реализовать семантику async итератора |
| Сложные вложенные comprehensions | Рекомендуется развернуть в явные циклы |

**Пример Python:**
```python
for item in enumerate(data):
    print(item)
```

**Сгенерированный V:**
```v
//##LLM@@ Enumerate used with a single target variable instead of unpacking. Please rewrite to unpack the index and value properly.
for item in py_enumerate(data) {
    println(item)
}
```

### 5. Типы и аннотации

| Ситуация | Комментарий |
|----------|-------------|
| `LiteralString` с `input()` | Потеря гарантии LiteralString |
| `LiteralString` с non-literal значением | Требуется проверить security implications |
| Обработка аннотации не удалась | Требуется вручную указать тип |
| Union типы (суммарные типы) | Рекомендуется дать осмысленное имя типу |

**Пример Python:**
```python
from typing import LiteralString
s: LiteralString = input()
```

**Сгенерированный V:**
```v
//##LLM@@ LiteralString variable 's' receives value from input() (loss of guarantee). Please review the security implications.
mut s := io.read_line()
```

### 6. Comprehensions

| Ситуация | Комментарий |
|----------|-------------|
| List comprehension | Поддержка отсутствует, требуется ручная транслитерация |
| Set comprehension | Поддержка отсутствует, требуется ручная транслитерация |
| Dict comprehension | Поддержка отсутствует, требуется ручная транслитерация |
| Generator expression | Поддержка отсутствует, требуется ручная транслитерация |

**Пример Python:**
```python
result = [x * 2 for x in data if x > 0]
```

**Сгенерированный V:**
```v
//##LLM@@ List comprehension support is missing in the transpiler. Please manually transpile this list comprehension.
result := []int{cap: data.len}
for x in data {
    if x > 0 {
        result << x * 2
    }
}
```

### 7. Стандартная библиотека

| Модуль | Комментарий |
|--------|-------------|
| `struct` | Методы заглушены, требуется реализовать packing/unpacking |
| `pickle` | Частичная маппинг на JSON, может не работать для сложных объектов |
| `fractions` | Парсинг из строки неполный |
| `threading` | PyThread — placeholder, требуется использовать V `spawn` |
| `bytes` форматирование | Заглушено, может быть некорректным |

**Пример Python:**
```python
import pickle
data = pickle.dumps(obj)
```

**Сгенерированный V:**
```v
//##LLM@@ Pickle operations are partially mapped to JSON serialization. This may not handle complex objects or exact pickle semantics. Please review and manually implement correct binary serialization if required.
data := json.encode(obj) or { panic(err) }
```

### 8. Pydantic

| Ситуация | Комментарий |
|----------|-------------|
| Generic модели `BaseModel[T]` | Требуется ручная аннотация типов в V |
| `Field(default_factory=...)` | Требуется вручную инициализировать значение |
| Nested model fields | Валидация не вызывает `.validate()` для вложенных моделей |
| Validator с `mode='wrap'` | Требуется рефакторинг логики валидации |
| `@computed_field` | Генерируется как обычный метод без кэширования |

**Пример Python:**
```python
from pydantic import BaseModel, Field

class Config(BaseModel):
    items: list[str] = Field(default_factory=list)
```

**Сгенерированный V:**
```v
//##LLM@@ Pydantic Generic model (BaseModel[T]) detected in 'Config'. This requires manual type annotation and adjustments in V. Please review the generated struct.
pub struct Config {
    //##LLM@@ Pydantic 'Field(default_factory=...)' detected on field 'items'. This is not fully supported by the transpiler. Please manually initialize the default value in the V struct or factory.
    items []string
}
```

### 9. Destructuring и распаковка

| Ситуация | Комментарий |
|----------|-------------|
| Неподдерживаемый target destructuring | Требуется ручная реализация распаковки |

**Пример Python:**
```python
a, *b, c = [1, 2, 3, 4, 5]
```

**Сгенерированный V:**
```v
//##LLM@@ Unsupported destructuring target: <class 'ast.Starred'>. Please manually implement this unpacking logic in V.
a := data[0]
b := data[1:-1]
c := data[-1]
```

## Автоматическая генерация комментариев

Транслятор автоматически вставляет LLM-комментарии в следующих случаях:

1. **Обнаружена проблемная конструкция Python** — например, `*args` + `**kwargs` одновременно
2. **Не удалось применить маппинг** — например, неизвестный метод стандартной библиотеки
3. **Потеряна информация о типах** — например, аннотация не распознана
4. **Семантика Python не совпадает с V** — например, обработка исключений
5. **Динамические операции** — например, `getattr`, `eval`
6. **Временные решения (stubs)** — например, `pickle` → JSON

## Поиск LLM-комментариев в коде

Для быстрого поиска всех мест, требующих доработки, используйте:

```bash
# Поиск в Linux/macOS
grep -r "//##LLM@@" output/

# Поиск в Windows (PowerShell)
Select-String -Path "output/*.v" -Pattern "//##LLM@@"

# Подсчёт количества комментариев
grep -rc "//##LLM@@" output/ | awk -F: '{sum+=$2} END {print sum}'
```

## Рекомендации по доработке кода

1. **Начните с функций** — они часто содержат критические проблемы с параметрами
2. **Проверьте обработку ошибок** — замените `try/except` на Result/Option типы V
3. **Устраните динамические операции** — замените на статическую рефлексию или явные поля
4. **Оптимизируйте имена** — упростите длинные имена функций
5. **Проверьте стандартную библиотеку** — замените заглушки на полноценные реализации

## Интеграция с ИИ-ассистентами

LLM-комментарии разработаны для использования с ИИ-ассистентами:

1. **Автоматический поиск** — ИИ может быстро найти все `//##LLM@@` комментарии
2. **Контекстная информация** — каждый комментарий содержит достаточно контекста для понимания проблемы
3. **Рекомендации по исправлению** — комментарии включают конкретные шаги по доработке

**Пример промпта для ИИ:**
```
Найди все //##LLM@@ комментарии в этом файле и исправь проблемы по порядку приоритета:
1. Функции с некорректными параметрами
2. Обработку ошибок
3. Динамические операции
```

## Расширение функциональности

Чтобы добавить новый тип LLM-комментария в транслятор:

1. Откройте соответствующий файл в `py2v_transpiler/core/translator/`
2. Найдите место, где обрабатывается проблемная конструкция
3. Добавьте генерацию комментария перед генерацией кода:

```python
self.output.append(f"{self._indent()}//##LLM@@ Описание проблемы. Рекомендации по исправлению.")
```

4. Добавьте тест в `py2v_transpiler/tests/translator/` для проверки генерации комментария

## Статистика использования

На март 2026 года в трансляторе реализовано **40+ уникальных типов LLM-комментариев**, охватывающих:
- 15+ категорий проблем с функциями
- 10+ категорий проблем с типами
- 8+ категорий проблем со стандартной библиотекой
- 7+ категорий проблем с обработкой ошибок
