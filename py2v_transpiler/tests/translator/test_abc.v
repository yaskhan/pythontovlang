module main

import py2v_transpiler.models.v_types

// @line: test_abc.py:16:0
pub struct TestTranslator {
    ClassesMixin
    FunctionsMixin
    VariablesMixin
    ExpressionsMixin
    LiteralsMixin
    TranslatorBase
    emitter int
    mapper int
    decorator_processor int
    coroutine_handler int
    in_main bool
}

// @line: test_abc.py:24:4
pub fn new_test_translator(type_inference Any) TestTranslator {
    mut self := TestTranslator{}
    self.ClassesMixin = new_classes_mixin()
    self.emitter = py2v_transpiler.core.generator.VCodeEmitter()
    self.mapper = py2v_transpiler.stdlib_map.mapper.StdLibMapper()
    self.decorator_processor = py2v_transpiler.core.decorators.DecoratorProcessor(self)
    self.coroutine_handler = py2v_transpiler.core.coroutines.CoroutineHandler()
    self.in_main = false
    v_types.global_type_map = map[string]Any{}
    return self
}
// @line: test_abc.py:34:0
pub fn test_abc_basic() {
    mut code := '
import abc

class Animal(abc.ABC):
    @abc.abstractmethod
    def speak(self) -> str:
        pass

class Dog(Animal):
    def speak(self) -> str:
        return "Woof!"

# Animal() # Should fail in Python
d = Dog()
print(d.speak())
'
    mut tree := ast.parse(code)
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    analyzer.analyze(tree)
    mut translator := new_test_translator()
    for node in tree.body {
        translator.visit(node)
    }
    mut v_code := translator.emitter.emit()
    println('${v_code}')
    assert 'interface Animal {' in v_code
    assert 'speak() string' in v_code
    assert 'struct Dog {' in v_code
    assert 'Animal' in v_code
    assert 'fn new_animal() !Animal' in v_code
}
// @line: test_abc.py:76:0
pub fn test_abc_classmethod() {
    mut code := '
import abc

class C(abc.ABC):
    @classmethod
    @abc.abstractmethod
    def foo(cls) -> str:
        pass
'
    mut tree := ast.parse(code)
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    analyzer.analyze(tree)
    mut translator := new_test_translator()
    for node in tree.body {
        translator.visit(node)
    }
    mut v_code := translator.emitter.emit()
    println('${v_code}')
    assert 'foo() string' in v_code
    assert 'cls' !in v_code
}

fn main() {
    // @line: test_abc.py:101:0
    // if __name__ == '__main__':
    test_abc_basic()
    test_abc_classmethod()
}