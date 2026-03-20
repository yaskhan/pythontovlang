import ast
from typing import Dict, Any
from .base import TypeInferenceBase
from .utils import TypeInferenceUtilsMixin
from .visitor import TypeInferenceVisitorMixin
from .mypy import TypeInferenceMypyMixin, mypy_api_module
from .inferers import AliasInferer, MixinInferer, FunctionMutabilityScanner


class TypeInference(
    TypeInferenceVisitorMixin,
    TypeInferenceUtilsMixin,
    TypeInferenceMypyMixin,
    TypeInferenceBase
):
    def analyze(self, tree: ast.AST) -> Dict[str, str]:
        """Analyzes the AST to infer variable types."""
        # Type Alias Inference SHOULD RUN FIRST
        alias_inferer = AliasInferer()
        alias_inferer.analyze(tree)
        for k, v in alias_inferer.alias_to_type.items():
            if k not in self.type_map or self.type_map[k] == "Any":
                self.type_map[k] = v

        # Preliminary pass for function parameter mutability
        mut_scanner = FunctionMutabilityScanner()
        self.func_param_mutability = mut_scanner.analyze(tree, self.mutability_map)

        # Pre-seed stdlib mutability
        self.func_param_mutability.update({
             "json.decode": [1],
             "os.open": [],
             "py_csv_reader": [],
             "py_csv_writer": [],
        })

        self.visit(tree)

        # Mixin Inference
        mixin_inferer = MixinInferer()
        mixin_inferer.analyze(tree)
        self.mixin_to_main = mixin_inferer.mixin_to_main
        self.main_to_mixins = mixin_inferer.main_to_mixins
        self.mixin_nodes = mixin_inferer.mixin_nodes
        self.is_abc = mixin_inferer.is_abc
        self.static_methods = mixin_inferer.static_methods
        self.class_methods = mixin_inferer.class_methods

        return self.type_map
