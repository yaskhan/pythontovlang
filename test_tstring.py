import ast
import tokenize, io, token
def _preprocess_t_strings(source: str) -> str:
    tokens = list(tokenize.tokenize(io.BytesIO(source.encode('utf-8')).readline))
    new_tokens = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.type == token.NAME and tok.string.lower() in ('t', 'tr', 'rt'):
            next_tok = tokens[i+1] if i+1 < len(tokens) else None
            if next_tok and next_tok.type == token.STRING and next_tok.start == tok.end:
                prefix_str = tok.string.lower().replace('t', 'f')

                tok_start = tokenize.TokenInfo(token.NAME, 'py2v_t_string', tok.start, tok.start, tok.line)
                tok_lpar = tokenize.TokenInfo(token.OP, '(', tok.start, tok.start, tok.line)

                new_str_val = prefix_str + next_tok.string
                tok_f = tokenize.TokenInfo(token.STRING, new_str_val, tok.start, next_tok.end, tok.line)
                tok_rpar = tokenize.TokenInfo(token.OP, ')', next_tok.end, next_tok.end, next_tok.line)

                new_tokens.extend([tok_start, tok_lpar, tok_f, tok_rpar])
                i += 2
                continue
        new_tokens.append(tok)
        i += 1
    return tokenize.untokenize(new_tokens).decode('utf-8')

import py2v_transpiler.core.parser as pyparser
pyparser.PyASTParser._preprocess_t_strings = lambda self, src: _preprocess_t_strings(src)
original_parse = pyparser.PyASTParser.parse
def new_parse(self, source: str) -> ast.AST:
    source = self._preprocess_t_strings(source)
    return original_parse(self, source)
pyparser.PyASTParser.parse = new_parse

parser = pyparser.PyASTParser()
tree = parser.parse('template = t"Hello {name=}"')

class DummyEmitter:
    def add_import(self, name): print(f"Added import: {name}")
    def add_helper_function(self, code): print(f"Added helper:\n{code}")

class DummyMapper:
    def get_mapping(self, *args): return None
    def get_constant_mapping(self, *args): return None

class DummyTypeInference:
    def resolve_type(self, node): return 'Any'
    def __getattr__(self, name): return {}

class DummyCoroutine:
    def is_generator(self, name): return False

from py2v_transpiler.core.translator.expressions import ExpressionsMixin
from py2v_transpiler.core.translator.literals import LiteralsMixin
class DummyTranslator(ExpressionsMixin, LiteralsMixin):
    def __init__(self):
        self.output = []
        self.imported_modules = {}
        self.imported_symbols = {}
        self.function_names = set()
        self.scc_files = []
        self.current_class = None
        self.current_class_bases = []
        self.mapper = DummyMapper()
        self.emitter = DummyEmitter()
        self.type_inference = DummyTypeInference()
        self.renamed_functions = {}
        self.name_remap = {}
        self.coroutine_handler = DummyCoroutine()
        self.overloaded_signatures = {}

    def visit_Name(self, node): return node.id
    def _guess_type(self, node): return 'Any'

translator = DummyTranslator()
print(translator.visit(tree.body[0].value))
