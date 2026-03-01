import ast
from typing import List, Optional, Any
from ..base import TranslatorBase
from py2v_transpiler.models.v_types import map_python_type_to_v

class BasicExpressionsMixin(TranslatorBase):
    def visit_Expr(self, node: ast.Expr) -> None:
        val = self.visit(node.value)
        if val:
            self.output.append(f"{self._indent()}{val}")

    def visit_Starred(self, node: ast.Starred) -> str:
        val = self.visit(node.value)
        return f"...{val}"

    def visit_Assert(self, node: ast.Assert) -> None:
        test = self.visit(node.test)
        self.output.append(f"{self._indent()}assert {test}")

    def visit_IfExp(self, node: ast.IfExp) -> str:
        test = self.visit(node.test)
        body = self.visit(node.body)
        orelse = self.visit(node.orelse)
        return f"if {test} {{ {body} }} else {{ {orelse} }}"
    def _guess_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Constant):
             if isinstance(node.value, int): return "int"
             if isinstance(node.value, float): return "f64"
             if isinstance(node.value, str): return "string"
             if isinstance(node.value, bool): return "bool"
             if isinstance(node.value, complex): return "PyComplex"
             return "int"
        elif isinstance(node, ast.Name):
            # Try to resolve via type inference
            inferred = self.type_inference.resolve_type(node)
            if inferred != "void":
                return inferred
            return "int" # Fallback
        elif isinstance(node, ast.BinOp):
            if isinstance(node.op, ast.Div):
                left = self._guess_type(node.left)
                right = self._guess_type(node.right)
                if left == "PyComplex" or right == "PyComplex": return "PyComplex"
                return "f64"
            # For Add/Sub/Mult/Mod/Pow, check operands
            left = self._guess_type(node.left)
            right = self._guess_type(node.right)
            if left == "PyComplex" or right == "PyComplex": return "PyComplex"
            if left == "f64" or right == "f64": return "f64"
            if left == "string" or right == "string": return "string"
            return "int"
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                fid = node.func.id
                if fid == "str": return "string"
                if fid == "int": return "int"
                if fid == "float": return "f64"
                if fid == "bool": return "bool"
                if fid == "len": return "int"

        return "int"

    def _infer_generator_types(self, gen: ast.comprehension) -> None:
        """Infers types of loop variables from the generator and updates type_map."""
        iter_node = gen.iter
        target_node = gen.target

        # Handle simple range
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "range":
            if isinstance(target_node, ast.Name):
                self.type_inference.type_map[target_node.id] = "int"

        # Handle list literal
        elif isinstance(iter_node, ast.List):
            if iter_node.elts:
                elt_type = self._guess_type(iter_node.elts[0])
                if isinstance(target_node, ast.Name):
                    self.type_inference.type_map[target_node.id] = elt_type

        # Handle zip
        elif isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "zip":
            if isinstance(target_node, ast.Tuple):
                for i, arg in enumerate(iter_node.args):
                    if i < len(target_node.elts):
                        t_elt = target_node.elts[i]
                        if isinstance(t_elt, ast.Name):
                            # Guess type of the argument (list literal, etc)
                            if isinstance(arg, ast.List) and arg.elts:
                                arg_type = self._guess_type(arg.elts[0])
                                self.type_inference.type_map[t_elt.id] = arg_type
                            elif isinstance(arg, ast.Call) and isinstance(arg.func, ast.Name) and arg.func.id == "range":
                                self.type_inference.type_map[t_elt.id] = "int"
