# GitHub Issue Creator

Автоматическое создание GitHub issues из текстового файла с использованием GitHub CLI.

## Установка

1. Установите [GitHub CLI](https://cli.github.com/):
   ```bash
   winget install GitHub.cli
   ```

2. Авторизуйтесь в GitHub:
   ```bash
   gh auth login
   ```

## Использование

### Базовое использование

```bash
cd scripts
python create_issue.py issues_todo.txt
```

### С указанием репозитория

```bash
python create_issue.py issues_todo.txt --repo yaskhan/pythontovlang
```

### С лейблами

```bash
python create_issue.py issues_todo.txt --label enhancement,bug
```

### Dry-run (предварительный просмотр)

```bash
python create_issue.py issues_todo.txt --dry-run
```

## Формат файла issues

```
##title: Заголовок issue
##descr: Описание issue.
         Может занимать несколько строк.
---cut---
##title: Другой заголовок
##descr: Другое описание.
---cut---
```

### Пример

```
##title: Implement PEP 747: TypeForm[T] Support
##descr: Add support for Python's PEP 747 TypeForm syntax in the transpiler.

### Task
Implement parsing and translation of `TypeForm[T]` annotations.

### Requirements
- Parse `TypeForm[T]` in argument and return annotations
- Map `TypeForm` to appropriate V type representation

### Acceptance Criteria
- [ ] AST parsing supports TypeForm syntax
- [ ] Test cases for TypeForm in function signatures
---cut---
```

## Формат Issues

Каждый consolidated issue обязательно следует шаблону:

```markdown
## Problem
Чёткое описание проблемы

## Affected Tests
Таблица с файлами и ошибками

## Example
Python Input → Current Invalid V Output → Expected V Output

## Root Cause
Анализ корневой причины

## Tasks
Конкретные шаги для исправления

## Files to Modify
Список файлов для изменения

## Acceptance Criteria
Чеклист для проверки

## Priority
Приоритет с обоснованием
```


## Структура файлов

```
scripts/
├── create_issue.py      # Скрипт для создания issues
├── issues_todo.txt      # Шаблоны issues из todo2.md
└── README.md            # Этот файл
```

## Генерация issues из todo2.md

Файл `issues_todo.txt` был автоматически сгенерирован на основе `todo2.md`.
Он содержит нереализованные задачи (отмеченные `[ ]`) в формате для GitHub issues.

Для обновления файла issues:

1. Отредактируйте `todo2.md` (добавьте новые задачи или отметьте выполненные `[x]`)
2. Запустите скрипт генерации (требует дополнительного парсера)
3. Отредактируйте `issues_todo.txt` при необходимости

## Требования

- Python 3.10+
- GitHub CLI 2.0+
- Авторизация в GitHub через `gh auth login`

## Примеры команд

### Создать все issues из файла

```bash
python create_issue.py issues_todo.txt --repo yaskhan/pythontovlang
```

### Создать issues с определёнными лейблами

```bash
python create_issue.py issues_todo.txt --repo yaskhan/pythontovlang --label "enhancement,typing"
```

### Предварительный просмотр

```bash
python create_issue.py issues_todo.txt --dry-run
```

## Troubleshooting

### Ошибка: "gh: command not found"

Добавьте GitHub CLI в PATH:
```powershell
$env:Path += ";C:\Program Files\GitHub CLI"
```

### Ошибка авторизации

Выполните:
```bash
gh auth logout
gh auth login
```

### Ошибка: "HTTP 422: Validation Failed"

Проверьте, что лейблы существуют в репозитории:
```bash
gh label list
```

## Лицензия

MIT
