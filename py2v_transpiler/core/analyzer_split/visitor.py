import ast
from typing import Any, Dict
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TypeInferenceBase


class TypeInferenceVisitorMixin(TypeInferenceBase):
    def visit_Call(self, node: ast.Call) -> Any:
        if isinstance(node.func, ast.Attribute):
            mutating_methods = {
                "append", "extend", "insert", "pop", "remove", "clear",
                "update", "setdefault", "delete", "add", "discard"
            }
            if node.func.attr in mutating_methods:
                self._mark_mutated(node.func.value)

            if node.func.attr == "append":
                if isinstance(node.func.value, ast.Name):
                    var_name = node.func.value.id
                    if len(node.args) == 1:
                        elt_type = self._guess_node_type(node.args[0])
                        if elt_type != "Any":
                            new_type = f"[]{elt_type}"
                            if var_name not in self.type_map or self.type_map[var_name] == "[]Any":
                                self.type_map[var_name] = new_type
        elif isinstance(node.func, ast.Name):
            func_name = node.func.id
            if func_name in self.func_param_mutability:
                mutated_indices = self.func_param_mutability[func_name]
                for i, arg in enumerate(node.args):
                    if i in mutated_indices:
                        self._mark_mutated(arg)

            var_name = node.func.id
            # Don't overwrite if already inferred as something more specific
            if var_name not in self.type_map or self.type_map[var_name] == "Any":
                if var_name not in ("list", "set", "dict"):
                    self.type_map[var_name] = "fn (...Any) Any"

        self.generic_visit(node)

    def visit_ClassDef(self, node: ast.ClassDef) -> Any:
        for stmt in node.body:
            if isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name):
                        self.type_map[target.id] = self._guess_node_type(stmt.value)
        self.generic_visit(node)

    def visit_Assign(self, node: ast.Assign) -> Any:
        for target in node.targets:
            if isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name) and target.value.id == "self":
                 self.type_map[target.attr] = self._guess_node_type(node.value)

            if isinstance(target, ast.Name):
                if target.id in self.mutability_map:
                    self.mutability_map[target.id]["is_reassigned"] = True
                else:
                    self.mutability_map[target.id] = {"is_reassigned": False, "is_final": False, "is_mutated": False}

            if isinstance(target, ast.Subscript):
                self._mark_mutated(target.value)
                dict_name = None
                if isinstance(target.value, ast.Name):
                    dict_name = target.value.id
                elif isinstance(target.value, ast.Attribute) and isinstance(
                    target.value.value, ast.Name
                ):
                    dict_name = f"{target.value.value.id}.{target.value.attr}"

                if dict_name:
                    if isinstance(target.slice, ast.Slice):
                        val_type = self._guess_node_type(node.value)
                        new_type = val_type
                        if new_type != "Any":
                            current = self.type_map.get(dict_name, "Any")
                            if current == "Any" or "Any" in current:
                                self.type_map[dict_name] = new_type
                    else:
                        key_type = "string"
                        if hasattr(target.slice, "value") and isinstance(
                            target.slice.value, ast.Constant
                        ):
                            if isinstance(target.slice.value.value, int):
                                key_type = "int"
                            elif isinstance(target.slice.value.value, str):
                                key_type = "string"
                        elif isinstance(target.slice, ast.Constant):
                            if isinstance(target.slice.value, int):
                                key_type = "int"
                            elif isinstance(target.slice.value, str):
                                key_type = "string"

                        val_type = self._guess_node_type(node.value)
                        new_type = f"map[{key_type}]{val_type}"

                        current = self.type_map.get(dict_name, "Any")
                        if current == "Any" or "Any" in current:
                            self.type_map[dict_name] = new_type
            elif isinstance(target, ast.Name):
                if isinstance(node.value, (ast.List, ast.Dict)):
                    inferred = self._infer_collection_type(node.value)
                    if target.id not in self.type_map or self.type_map[target.id] == "Any":
                        self.type_map[target.id] = inferred

        self.generic_visit(node)

    def visit_AugAssign(self, node: ast.AugAssign) -> Any:
        if isinstance(node.target, (ast.Name, ast.Attribute)):
            self._mark_reassigned(node.target)
        elif isinstance(node.target, ast.Subscript):
            self._mark_mutated(node.target.value)
        self.generic_visit(node)

    def visit_Delete(self, node: ast.Delete) -> Any:
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                self._mark_mutated(target.value)
        self.generic_visit(node)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        if node.annotation:
            try:
                type_str = ast.unparse(node.annotation)
                if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                     v_type = "LiteralString"
                else:
                     v_type = map_python_type_to_v(type_str)
                
                if isinstance(node.target, ast.Name):
                    self.type_map[node.target.id] = v_type
                elif isinstance(node.target, ast.Attribute) and isinstance(node.target.value, ast.Name) and node.target.value.id == "self":
                    self.type_map[node.target.attr] = v_type
            except Exception:
                pass

        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        self.type_map[node.name] = "fn (...Any) Any"

        for arg in node.args.args:
            fullname = f"{node.name}.{arg.arg}"
            if fullname in self.mutability_map:
                 self.mutability_map[arg.arg] = self.mutability_map[fullname]

            py_type = "Any"
            if arg.annotation:
                try:
                    py_type = ast.unparse(arg.annotation)
                except Exception:
                    pass

            v_type = map_python_type_to_v(py_type)
            if v_type == "LiteralString": v_type = "string"

            self.type_map[arg.arg] = v_type
            if hasattr(arg, 'lineno'):
                self.type_map[f"{arg.arg}@{arg.lineno}:{arg.col_offset}"] = v_type

        v_type_ret = "void"
        py_type_ret = "void"
        if node.returns:
            try:
                py_type_ret = ast.unparse(node.returns)
                v_type_ret = map_python_type_to_v(py_type_ret)
                if v_type_ret == "LiteralString": v_type_ret = "string"
                self.type_map[f"{node.name}@return"] = v_type_ret
            except:
                pass
        elif node.name not in ("__init__", "__post_init__", "setUp", "tearDown"):
            found_types = set()
            has_return_value = False

            def find_returns(n: ast.AST):
                nonlocal has_return_value
                for child in ast.iter_child_nodes(n):
                    if isinstance(child, ast.Return):
                        if child.value:
                            has_return_value = True
                            typ = self._guess_node_type(child.value)
                            if typ != "Any":
                                found_types.add(typ)
                    elif not isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Lambda)):
                        find_returns(child)

            find_returns(node)

            if len(found_types) == 1:
                v_type_ret = list(found_types)[0]
                if v_type_ret != "void":
                    self.type_map[f"{node.name}@return"] = v_type_ret
            elif len(found_types) > 1:
                self.type_map[f"{node.name}@return"] = "Any"
            elif has_return_value:
                self.type_map[f"{node.name}@return"] = "Any"

        args_len = len(node.args.args)
        defaults_len = len(node.args.defaults)
        defaults_map: Dict[str, ast.expr] = {}
        for i, d in enumerate(node.args.defaults):
            arg_idx = args_len - defaults_len + i
            if arg_idx >= 0 and arg_idx < args_len:
                 arg_name = node.args.args[arg_idx].arg
                 defaults_map[arg_name] = d

        for i, kwarg in enumerate(node.args.kwonlyargs):
            if i < len(node.args.kw_defaults) and node.args.kw_defaults[i] is not None:
                 defaults_map[kwarg.arg] = node.args.kw_defaults[i] # type: ignore

        sig_data: Dict[str, Any] = {
            "args": [ast.unparse(arg.annotation) if arg.annotation else "Any" for arg in node.args.args + node.args.kwonlyargs],
            "arg_names": [arg.arg for arg in node.args.args + node.args.kwonlyargs],
            "defaults": defaults_map,
            "return": py_type_ret,
            "is_class": False,
            "has_init": False
        }
        self.call_signatures[node.name] = sig_data

        self.generic_visit(node)

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> Any:
        return self.visit_FunctionDef(node) # type: ignore
