// Я Cline работаю над этим файлом. Начало: 2026-03-22 15:38
// fastparse.v — Fast Python parser for mypy
// Переведён из mypy/fastparse.py

module mypy

// Маппинг операторов
pub const op_map = {
	'ast3.Add':      '+'
	'ast3.Sub':      '-'
	'ast3.Mult':     '*'
	'ast3.MatMult':  '@'
	'ast3.Div':      '/'
	'ast3.Mod':      '%'
	'ast3.Pow':      '**'
	'ast3.LShift':   '<<'
	'ast3.RShift':   '>>'
	'ast3.BitOr':    '|'
	'ast3.BitXor':   '^'
	'ast3.BitAnd':   '&'
	'ast3.FloorDiv': '//'
}

// Маппинг операторов сравнения
pub const comp_op_map = {
	'ast3.Gt':    '>'
	'ast3.Lt':    '<'
	'ast3.Eq':    '=='
	'ast3.GtE':   '>='
	'ast3.LtE':   '<='
	'ast3.NotEq': '!='
	'ast3.Is':    'is'
	'ast3.IsNot': 'is not'
	'ast3.In':    'in'
	'ast3.NotIn': 'not in'
}

// parse парсит исходный файл без семантического анализа
// Возвращает дерево разбора
pub fn parse(source string, fnam string, module ?string, mut errors Errors, options Options) MypyFile {
	is_stub_file := fnam.ends_with('.pyi')

	// TODO: полная реализация парсинга через ast3
	// Временная заглушка
	mut tree := MypyFile{
		defs:    []
		imports: []
		is_stub: is_stub_file
		path:    fnam
	}

	return tree
}

// parse_type_ignore_tag парсит опциональный тег "[code, ...]" после "# type: ignore"
pub fn parse_type_ignore_tag(tag ?string) ?[]string {
	if tag == none || tag.trim_space().len == 0 || tag.trim_space().starts_with('#') {
		return []string{}
	}
	// TODO: regex парсинг
	return []string{}
}

// parse_type_comment парсит тип из type comment
pub fn parse_type_comment(type_comment string, line int, column int, mut errors Errors) (?[]string, ?MypyTypeNode) {
	// TODO: реализация парсинга type comment
	return none, none
}

// parse_type_string парсит тип из строки
pub fn parse_type_string(expr_string string, expr_fallback_name string, line int, column int) MypyTypeNode {
	// TODO: реализация парсинга строки типа
	return RawExpressionTypeNode{
		literal_value:  expr_string
		base_type_name: expr_fallback_name
		line:           line
		column:         column
	}
}

// is_no_type_check_decorator проверяет, является ли декоратор no_type_check
pub fn is_no_type_check_decorator(expr AST) bool {
	if expr is NameNode {
		return expr.id == 'no_type_check'
	} else if expr is AttributeNode {
		if expr.value is NameNode {
			return expr.value.id == 'typing' && expr.attr == 'no_type_check'
		}
	}
	return false
}

// ASTConverter — конвертер AST Python в узлы mypy
pub struct ASTConverter {
pub mut:
	class_and_function_stack []string
	imports                  []ImportBase
	options                  Options
	is_stub                  bool
	errors                   Errors
	strip_function_bodies    bool
	path                     string
	type_ignores             map[int][]string
	uses_template_strings    bool
}

// new_ast_converter создаёт новый ASTConverter
pub fn new_ast_converter(options Options, is_stub bool, mut errors Errors, strip_function_bodies bool, path string) ASTConverter {
	return ASTConverter{
		class_and_function_stack: []
		imports:                  []
		options:                  options
		is_stub:                  is_stub
		errors:                   errors
		strip_function_bodies:    strip_function_bodies
		path:                     path
		type_ignores:             map[int][]string{}
		uses_template_strings:    false
	}
}

// note записывает примечание
pub fn (mut conv ASTConverter) note(msg string, line int, column int) {
	conv.errors.report(line, column, msg, 'note', codes.syntax)
}

// fail записывает ошибку
pub fn (mut conv ASTConverter) fail(msg string, line int, column int, blocker bool) {
	if blocker || !conv.options.ignore_errors {
		conv.errors.report(line, column, msg, 'error', codes.syntax)
	}
}

// set_line устанавливает позицию узла
pub fn (mut conv ASTConverter) set_line(mut node Node, n AST) Node {
	node.line = n.lineno
	node.column = n.col_offset
	node.end_line = n.end_lineno
	node.end_column = n.end_col_offset
	return node
}

// translate_expr_list конвертирует список выражений
pub fn (mut conv ASTConverter) translate_expr_list(l []AST) []Expression {
	mut res := []Expression{}
	for e in l {
		exp := conv.visit(e)
		if exp is Expression {
			res << exp
		}
	}
	return res
}

// translate_stmt_list конвертирует список операторов
pub fn (mut conv ASTConverter) translate_stmt_list(stmts []AST) []Statement {
	mut res := []Statement{}
	for stmt in stmts {
		node := conv.visit(stmt)
		if node is Statement {
			res << node
		}
	}
	return res
}

// visit посещает узел AST
pub fn (mut conv ASTConverter) visit(node AST) ?Node {
	if node is NameNode {
		return conv.visit_name(node)
	} else if node is IntNode {
		return conv.visit_int(node)
	} else if node is StrNode {
		return conv.visit_str(node)
	}
	return none
}

// visit_name обрабатывает Name узел
pub fn (mut conv ASTConverter) visit_name(n NameNode) NameExpr {
	mut e := NameExpr{
		node: n.id
	}
	e.line = n.lineno
	e.column = n.col_offset
	return e
}

// visit_int обрабатывает Int узел
pub fn (mut conv ASTConverter) visit_int(n IntNode) IntExpr {
	mut e := IntExpr{
		value: n.value
	}
	e.line = n.lineno
	e.column = n.col_offset
	return e
}

// visit_str обрабатывает Str узел
pub fn (mut conv ASTConverter) visit_str(n StrNode) StrExpr {
	mut e := StrExpr{
		value: n.value
	}
	e.line = n.lineno
	e.column = n.col_offset
	return e
}

// as_block создаёт Block из списка операторов
pub fn (mut conv ASTConverter) as_block(stmts []AST) ?Block {
	if stmts.len == 0 {
		return none
	}
	return Block{
		body: conv.translate_stmt_list(stmts)
		line: stmts[0].lineno
	}
}

// as_required_block создаёт обязательный Block
pub fn (mut conv ASTConverter) as_required_block(stmts []AST) Block {
	return Block{
		body: conv.translate_stmt_list(stmts)
		line: if stmts.len > 0 { stmts[0].lineno } else { 0 }
	}
}

// TypeConverter — конвертер типов
pub struct TypeConverter {
pub mut:
	errors          ?Errors
	line            int
	override_column int
	node_stack      []AST
	is_evaluated    bool
}

// new_type_converter создаёт новый TypeConverter
pub fn new_type_converter(errors ?Errors, line int, override_column int, is_evaluated bool) TypeConverter {
	return TypeConverter{
		errors:          errors
		line:            line
		override_column: override_column
		node_stack:      []
		is_evaluated:    is_evaluated
	}
}

// visit посещает узел AST для конвертации типа
pub fn (mut tc TypeConverter) visit(node ?AST) ?MypyTypeNode {
	if node == none {
		return none
	}
	// TODO: полная реализация конвертации типов
	return none
}

// translate_expr_list конвертирует список выражений в типы
pub fn (mut tc TypeConverter) translate_expr_list(l []AST) []MypyTypeNode {
	mut res := []MypyTypeNode{}
	for e in l {
		typ := tc.visit(e)
		if typ != none {
			res << typ
		}
	}
	return res
}

// Вспомогательные типы AST
pub struct AST {
pub:
	lineno         int
	col_offset     int
	end_lineno     int
	end_col_offset int
}

pub struct NameNode {
	AST
pub:
	id string
}

pub struct IntNode {
	AST
pub:
	value int
}

pub struct StrNode {
	AST
pub:
	value string
}

pub struct AttributeNode {
	AST
pub:
	value AST
	attr  string
}
