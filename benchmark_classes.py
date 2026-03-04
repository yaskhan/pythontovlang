import ast
import timeit
from py2v_transpiler.core.translator.classes import ClassesMixin

class DummyTypeInference:
    pass

class DummyEmitter:
    def add_struct(self, s):
        pass

class DummyTranslator(ClassesMixin):
    def __init__(self):
        self.emitter = DummyEmitter()
        self.type_inference = DummyTypeInference()
        self.imported_symbols = {}
        self.known_interfaces = set()
        self.class_hierarchy = {}
        self.current_class = None
        self.current_class_generics = []
        self.current_class_generic_map = {}
        self.current_class_bases = []
        self.current_class_is_unittest = False

    def _sanitize_name(self, name, is_type=False):
        return name

    def visit(self, node):
        return ""

    def _get_generic_map(self, py_generics):
        return {g: g for g in py_generics}

    def _guess_type(self, node):
        return "int"

translator = DummyTranslator()

# Create a massive enum to test enum generation
enum_fields = []
for i in range(10000):
    enum_fields.append(
        ast.Assign(
            targets=[ast.Name(id=f"FIELD_{i}", ctx=ast.Store())],
            value=ast.Constant(value=i)
        )
    )

enum_class = ast.ClassDef(
    name="BigEnum",
    bases=[ast.Name(id="Enum", ctx=ast.Load())],
    keywords=[],
    body=enum_fields,
    decorator_list=[]
)

methods = []
for i in range(10000):
    methods.append(
        ast.FunctionDef(
            name=f"method_{i}",
            args=ast.arguments(
                posonlyargs=[],
                args=[ast.arg(arg="self")],
                kwonlyargs=[],
                kw_defaults=[],
                defaults=[]
            ),
            body=[ast.Pass()],
            decorator_list=[],
            returns=None
        )
    )

protocol_class = ast.ClassDef(
    name="BigProtocol",
    bases=[ast.Name(id="Protocol", ctx=ast.Load())],
    keywords=[],
    body=methods,
    decorator_list=[]
)

def run_enum_bench():
    translator.visit_ClassDef(enum_class)

def run_protocol_bench():
    translator.visit_ClassDef(protocol_class)

if __name__ == "__main__":
    t_enum = timeit.timeit(run_enum_bench, number=10)
    print(f"Enum Benchmark: {t_enum:.4f} seconds")
    t_proto = timeit.timeit(run_protocol_bench, number=10)
    print(f"Protocol Benchmark: {t_proto:.4f} seconds")
