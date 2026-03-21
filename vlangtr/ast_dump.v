module main

import os
import ast

fn main() {
	// ── Demo: parse Python source from CLI argument or built-in example ──
	mut source := ''
	mut filename := '<string>'

	if os.args.len >= 2 {
		filename = os.args[1]
		source = os.read_file(filename) or {
			eprintln('Error reading file: ${filename}')
			exit(1)
		}
	} else {
		// Built-in example covering most AST node types
		source = demo_source()
		filename = '<demo>'
	}

	// ── Lex ──
	mut lexer := ast.new_lexer(source, filename)

	// ── Parse ──
	mut parser := ast.new_parser(lexer)
	module_ast := parser.parse_module()

	if parser.errors.len > 0 {
		for e in parser.errors {
			eprintln(e.str())
		}
		// Continue anyway to show partial tree
	}

	// ── Print AST ──
	mut printer := ast.Printer{}
	printer.visit_module(&module_ast)
	println(printer.output)

	println('--- Parse complete: ${module_ast.body.len} top-level statements, ${parser.errors.len} errors ---')
}

fn demo_source() string {
	return "# Demo Python source
import os
from sys import argv, exit as sys_exit

CONST = 42

class Animal:
    def __init__(self, name: str, age: int = 0):
        self.name = name
        self.age = age

    def speak(self) -> str:
        return '...'

    @staticmethod
    def from_string(s: str) -> 'Animal':
        parts = s.split(',')
        return Animal(parts[0], int(parts[1]))

class Dog(Animal):
    def speak(self) -> str:
        return f'Woof! I am {self.name}'

def greet(name: str, loud: bool = False) -> str:
    msg = 'Hello, ' + name
    if loud:
        msg = msg.upper()
    return msg

def fibonacci(n: int) -> int:
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

def process_list(items):
    result = [x * 2 for x in items if x > 0]
    mapping = {k: v for k, v in enumerate(items)}
    total = sum(x for x in items)
    return result, mapping, total

def match_example(point):
    match point:
        case (0, 0):
            return 'origin'
        case (x, 0):
            return f'x-axis at {x}'
        case (0, y):
            return f'y-axis at {y}'
        case (x, y):
            return f'point at {x},{y}'
        case _:
            return 'not a point'

async def fetch_data(url: str):
    try:
        data = await get(url)
        return data
    except Exception as e:
        raise RuntimeError('fetch failed') from e
    finally:
        pass

x: int = 10
y = z = 0
x += 5

animals = [Dog('Rex'), Dog('Buddy')]
for a in animals:
    print(a.speak())

i = 0
while i < 10:
    i += 1
    if i == 5:
        continue
    if i == 8:
        break

with open('file.txt') as f:
    content = f.read()

result = greet('World', loud=True)
nums = [1, 2, 3, 4, 5]
doubled = list(map(lambda x: x * 2, nums))
"
}
