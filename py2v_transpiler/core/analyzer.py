import ast
from typing import Dict, Any, Tuple, Optional
from py2v_transpiler.models.v_types import map_python_type_to_v

try:
    from mypy import api as mypy_api_module
except ImportError:
    mypy_api_module = None # type: ignore


class AliasInferer(ast.NodeVisitor):
    def __init__(self):
        self.alias_to_type = {}

    def analyze(self, tree: ast.AST):
        # Pass 1: find alias assignments to collections
        aliases = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                lhs = node.targets[0].id
                if isinstance(node.value, ast.Name) and node.value.id in ('list', 'set', 'dict'):
                    aliases[lhs] = node.value.id

        # Pass 2: find usage of aliases and what gets appended
        alias_usages: Dict[str, set] = {alias: set() for alias in aliases}
        var_to_alias = {}

        for node in ast.walk(tree):
            # Find instantiations: a = OrderedCollection()
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name):
                    if node.value.func.id in aliases:
                        var_to_alias[node.targets[0].id] = node.value.func.id

            # Find appends: a.append(Constraint())
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'append':
                if isinstance(node.func.value, ast.Name):
                    var_name = node.func.value.id
                    if var_name in var_to_alias and len(node.args) == 1:
                        if isinstance(node.args[0], ast.Call) and isinstance(node.args[0].func, ast.Name):
                            alias_usages[var_to_alias[var_name]].add(node.args[0].func.id)

        # Resolve types
        for alias, base_type in aliases.items():
            used_types = alias_usages[alias]
            if not used_types:
                self.alias_to_type[alias] = f"[]Any" if base_type == 'list' else 'Any'
            elif len(used_types) == 1:
                inner_type = list(used_types)[0]
                self.alias_to_type[alias] = f"[]{inner_type}" if base_type == 'list' else f"map[int]{inner_type}"
            else:
                self.alias_to_type[alias] = f"[]Any" if base_type == 'list' else f"map[int]Any"

class MixinInferer(ast.NodeVisitor):
    def __init__(self):
        self.mixin_to_main: Dict[str, list[str]] = {}
        self.main_to_mixins: Dict[str, list[str]] = {}
        self.mixin_nodes: Dict[str, ast.ClassDef] = {}

    def analyze(self, tree: ast.AST):
        # Pass 1: find mixins and their inheritances
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                if node.name.endswith("Mixin"):
                    self.mixin_nodes[node.name] = node
                else:
                    for base in node.bases:
                        if isinstance(base, ast.Name) and base.id.endswith("Mixin"):
                            if base.id not in self.mixin_to_main:
                                self.mixin_to_main[base.id] = []
                            self.mixin_to_main[base.id].append(node.name)
                            if node.name not in self.main_to_mixins:
                                self.main_to_mixins[node.name] = []
                            self.main_to_mixins[node.name].append(base.id)

class MutabilityTracker(ast.NodeVisitor):
    def __init__(self):
        # We track mutability per scope. 0 is global, >0 are functions/classes
        self.scopes: list[Dict[str, bool]] = [{}] # var_name -> True if mutated/reassigned
        self.finals: list[set[str]] = [set()] # variables annotated with Final

        self.scope_mutations: Dict[ast.AST, Dict[str, bool]] = {}
        self.scope_finals: Dict[ast.AST, set[str]] = {}

    def analyze(self, tree: ast.AST):
        self.scope_mutations[tree] = self.scopes[0]
        self.scope_finals[tree] = self.finals[0]
        self.visit(tree)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        self.scopes.append({})
        self.finals.append(set())

        for arg in node.args.args + getattr(node.args, 'kwonlyargs', []) + getattr(node.args, 'posonlyargs', []):
            self.scopes[-1][arg.arg] = False
        if node.args.vararg:
            self.scopes[-1][node.args.vararg.arg] = False
        if node.args.kwarg:
            self.scopes[-1][node.args.kwarg.arg] = False

        self.generic_visit(node)
        self.scope_mutations[node] = self.scopes.pop()
        self.scope_finals[node] = self.finals.pop()

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> Any:
        self.scopes.append({})
        self.finals.append(set())

        for arg in node.args.args + getattr(node.args, 'kwonlyargs', []) + getattr(node.args, 'posonlyargs', []):
            self.scopes[-1][arg.arg] = False
        if node.args.vararg:
            self.scopes[-1][node.args.vararg.arg] = False
        if node.args.kwarg:
            self.scopes[-1][node.args.kwarg.arg] = False

        self.generic_visit(node)
        self.scope_mutations[node] = self.scopes.pop()
        self.scope_finals[node] = self.finals.pop()

    def visit_ClassDef(self, node: ast.ClassDef) -> Any:
        self.scopes.append({})
        self.finals.append(set())
        self.generic_visit(node)
        self.scope_mutations[node] = self.scopes.pop()
        self.scope_finals[node] = self.finals.pop()

    def _handle_assign_target(self, target: ast.AST) -> None:
        if isinstance(target, ast.Name):
            name = target.id
            if name in self.scopes[-1]:
                self.scopes[-1][name] = True
            else:
                self.scopes[-1][name] = False
        elif isinstance(target, (ast.Tuple, ast.List)):
            for elt in target.elts:
                self._handle_assign_target(elt)

    def _mark_mutation(self, target: ast.AST) -> None:
        if isinstance(target, ast.Name):
            name = target.id
            for i in range(len(self.scopes) - 1, -1, -1):
                if name in self.scopes[i]:
                    self.scopes[i][name] = True
                    return
            self.scopes[-1][name] = True
        elif isinstance(target, (ast.Attribute, ast.Subscript)):
            base = target.value
            while isinstance(base, (ast.Attribute, ast.Subscript)):
                base = base.value
            if isinstance(base, ast.Name):
                self._mark_mutation(base)

    def visit_Assign(self, node: ast.Assign) -> Any:
        for target in node.targets:
            self._handle_assign_target(target)
        self.generic_visit(node)

    def visit_AugAssign(self, node: ast.AugAssign) -> Any:
        self._mark_mutation(node.target)
        self.generic_visit(node)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        if isinstance(node.target, ast.Name):
            name = node.target.id
            if name in self.scopes[-1]:
                self.scopes[-1][name] = True
            else:
                self.scopes[-1][name] = False

            if node.annotation:
                is_final = False
                if isinstance(node.annotation, ast.Name) and node.annotation.id == 'Final':
                    is_final = True
                elif isinstance(node.annotation, ast.Subscript) and getattr(node.annotation.value, 'id', '') == 'Final':
                    is_final = True
                elif isinstance(node.annotation, ast.Attribute) and getattr(node.annotation.value, 'id', '') == 'typing' and node.annotation.attr == 'Final':
                    is_final = True

                if is_final:
                    self.finals[-1].add(name)
        self.generic_visit(node)

    def visit_For(self, node: ast.For) -> Any:
        self._handle_assign_target(node.target)
        self._mark_mutation(node.target)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> Any:
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            if node.func.attr in ('append', 'extend', 'pop', 'remove', 'insert', 'clear', 'update', 'setdefault', 'sort', 'reverse'):
                self._mark_mutation(node.func.value)
        self.generic_visit(node)


class TypeInference(ast.NodeVisitor):
    def __init__(self):
        self.type_map: Dict[str, str] = {}
        self.mutability_tracker = MutabilityTracker()
        self.location_map: Dict[str, str] = {}
        self.call_signatures: Dict[str, Dict[str, Any]] = {}
        self.mixin_to_main: Dict[str, list[str]] = {}
        self.main_to_mixins: Dict[str, list[str]] = {}
        self.mixin_nodes: Dict[str, ast.ClassDef] = {}

        self.assignments: Dict[str, bool] = {}
        self.reassigned_vars: set[str] = set()
        self.final_vars: set[str] = set()

    def analyze(self, tree: ast.AST) -> Dict[str, str]:
        """Analyzes the AST to infer variable types."""
        self.mutability_tracker.analyze(tree)
        self.visit(tree)
        # Type Alias Inference
        alias_inferer = AliasInferer()
        alias_inferer.analyze(tree)
        self.type_map.update(alias_inferer.alias_to_type)

        # Mixin Inference
        mixin_inferer = MixinInferer()
        mixin_inferer.analyze(tree)
        self.mixin_to_main = mixin_inferer.mixin_to_main
        self.main_to_mixins = mixin_inferer.main_to_mixins
        self.mixin_nodes = mixin_inferer.mixin_nodes

        return self.type_map


    def visit_AugAssign(self, node: ast.AugAssign) -> Any:
        if isinstance(node.target, ast.Name):
            self.reassigned_vars.add(node.target.id)
        elif isinstance(node.target, (ast.Attribute, ast.Subscript)):
            # If mutating an attribute or item of a variable, the base variable might need 'mut' in V
            # For simplicity, if base is Name, we mark it.
            base = node.target.value
            while isinstance(base, (ast.Attribute, ast.Subscript)):
                 base = base.value
            if isinstance(base, ast.Name):
                 self.reassigned_vars.add(base.id)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> Any:
        # Track mutating method calls
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            if node.func.attr in ('append', 'extend', 'pop', 'remove', 'insert', 'clear', 'update', 'setdefault'):
                self.reassigned_vars.add(node.func.value.id)
        self.generic_visit(node)

    def visit_For(self, node: ast.For) -> Any:
        if isinstance(node.target, ast.Name):
            if node.target.id in self.assignments:
                self.reassigned_vars.add(node.target.id)
            self.assignments[node.target.id] = True
        elif isinstance(node.target, (ast.Tuple, ast.List)):
             for elt in node.target.elts:
                 if isinstance(elt, ast.Name):
                     if elt.id in self.assignments:
                         self.reassigned_vars.add(elt.id)
                     self.assignments[elt.id] = True
        self.generic_visit(node)

    def visit_Assign(self, node: ast.Assign) -> Any:
        for target in node.targets:
            if isinstance(target, ast.Name):
                if target.id in self.assignments:
                    self.reassigned_vars.add(target.id)
                self.assignments[target.id] = True
            elif isinstance(target, (ast.Tuple, ast.List)):
                 for elt in target.elts:
                     if isinstance(elt, ast.Name):
                         if elt.id in self.assignments:
                             self.reassigned_vars.add(elt.id)
                         self.assignments[elt.id] = True

            if isinstance(target, ast.Subscript):
                dict_name = None
                if isinstance(target.value, ast.Name):
                    dict_name = target.value.id
                elif isinstance(target.value, ast.Attribute) and isinstance(target.value.value, ast.Name):
                    dict_name = f"{target.value.value.id}.{target.value.attr}"

                if dict_name:
                    key_type = "string" # default key
                    if hasattr(target.slice, "value") and isinstance(target.slice.value, ast.Constant): # python < 3.9
                        if isinstance(target.slice.value.value, int): key_type = "int"
                        elif isinstance(target.slice.value.value, str): key_type = "string"
                    elif isinstance(target.slice, ast.Constant): # python 3.9+
                        if isinstance(target.slice.value, int): key_type = "int"
                        elif isinstance(target.slice.value, str): key_type = "string"

                    val_type = "Any"
                    if isinstance(node.value, ast.Constant):
                        if isinstance(node.value.value, int): val_type = "int"
                        elif isinstance(node.value.value, str): val_type = "string"
                    elif isinstance(node.value, ast.Tuple):
                        if node.value.elts:
                            if isinstance(node.value.elts[0], ast.Constant):
                                if isinstance(node.value.elts[0].value, int): val_type = "[]int"
                                elif isinstance(node.value.elts[0].value, str): val_type = "[]string"
                                else: val_type = "[]Any"
                            else:
                                val_type = "[]Any"
                        else:
                            val_type = "[]Any"
                    elif isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name):
                        val_type = node.value.func.id

                    new_type = f"map[{key_type}]{val_type}"
                    self.type_map[dict_name] = new_type

        self.generic_visit(node)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        # Check if the target is a simple variable name (ast.Name)
        if isinstance(node.target, ast.Name):
            if node.target.id in self.assignments:
                self.reassigned_vars.add(node.target.id)
            self.assignments[node.target.id] = True

            if node.annotation:
                # Check for Final
                if isinstance(node.annotation, ast.Name) and node.annotation.id == 'Final':
                    self.final_vars.add(node.target.id)
                elif isinstance(node.annotation, ast.Subscript):
                    if isinstance(node.annotation.value, ast.Name) and node.annotation.value.id == 'Final':
                        self.final_vars.add(node.target.id)

                try:
                    # Use ast.unparse to get the full type string (e.g. List[int])
                    # This works for Python 3.9+
                    type_str = ast.unparse(node.annotation)
                    v_type = map_python_type_to_v(type_str)
                    self.type_map[node.target.id] = v_type
                except AttributeError:
                    # Fallback for older python without ast.unparse (though we are on 3.12)
                    # or if unparse fails
                    if isinstance(node.annotation, ast.Name):
                        v_type = map_python_type_to_v(node.annotation.id)
                        self.type_map[node.target.id] = v_type
                    elif isinstance(node.annotation, ast.Constant) and isinstance(node.annotation.value, str):
                        v_type = map_python_type_to_v(node.annotation.value)
                        self.type_map[node.target.id] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        for arg in node.args.args:
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    v_type = map_python_type_to_v(type_str)
                    self.type_map[arg.arg] = v_type
                except AttributeError:
                    if isinstance(arg.annotation, ast.Name):
                        v_type = map_python_type_to_v(arg.annotation.id)
                        self.type_map[arg.arg] = v_type
                    elif isinstance(arg.annotation, ast.Constant) and isinstance(arg.annotation.value, str):
                        v_type = map_python_type_to_v(arg.annotation.value)
                        self.type_map[arg.arg] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def run_mypy(self, path: str) -> Tuple[str, str, int]:
        """Runs mypy on the given file path and returns the output."""
        if not mypy_api_module:
            return ("Mypy not installed.", "", 1)

        import tempfile
        import os
        import json

        # Create a temporary config file to load the plugin
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ini', delete=False) as f:
            f.write("[mypy]\nplugins = py2v_transpiler.core.mypy_plugin\n")
            config_path = f.name

        # Store original PYTHONPATH to restore it later
        original_pythonpath = os.environ.get("PYTHONPATH")

        try:
            # Set PYTHONPATH so mypy can find the plugin
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = f".:{original_pythonpath}"
            else:
                os.environ["PYTHONPATH"] = "."

            # Ensure the global dict is clean before running mypy
            try:
                import py2v_transpiler.core.mypy_plugin as m_p
                m_p._global_collected_types.clear()
                m_p._global_collected_sigs.clear()
            except ImportError:
                pass

            result, error, exit_code = mypy_api_module.run([path, '--config-file', config_path])

            collected_types = None
            collected_sigs = None
            # First try to read from the memory (global state injected by the plugin)
            try:
                import py2v_transpiler.core.mypy_plugin as m_p
                if m_p._global_collected_types:
                    collected_types = dict(m_p._global_collected_types)
                if m_p._global_collected_sigs:
                    collected_sigs = dict(m_p._global_collected_sigs)
            except ImportError:
                pass

            # Fallback to reading the generated types mapping from JSON
            if not collected_types and os.path.exists("types_for_vlang.json"):
                try:
                    with open("types_for_vlang.json", "r") as json_file:
                        collected_types = json.load(json_file)
                except Exception:
                    pass

            if collected_types:
                for fullname, types in collected_types.items():
                    for location, typ in types.items():
                        v_type = map_python_type_to_v(typ)
                        # Extract the variable or function name from fullname if possible
                        # For now, we will just store it by location as well, or we can use it during transpilation
                        # but keeping it in self.type_map via a generic key might be tricky.
                        # We map it by line:column string for potential later use.
                        self.type_map[f"{fullname}@{location}"] = v_type

                        # Populate location_map for O(1) lookups by location (handling potential float vs int overloads)
                        if 'builtins.float' in fullname or location not in self.location_map:
                             self.location_map[location] = v_type

            if collected_sigs:
                for fullname, sigs in collected_sigs.items():
                    for location, sig_json in sigs.items():
                        try:
                            sig_data = json.loads(sig_json)
                            # the function name itself is usually enough, but we store full location too
                            self.call_signatures[f"{fullname}@{location}"] = sig_data
                            self.call_signatures[location] = sig_data
                        except Exception:
                            pass

            if os.path.exists("types_for_vlang.json"):
                try:
                    os.remove("types_for_vlang.json")
                except Exception:
                    pass
        finally:
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = original_pythonpath
            elif "PYTHONPATH" in os.environ:
                del os.environ["PYTHONPATH"]

            os.remove(config_path)

        return result, error, exit_code

    def resolve_type(self, node: ast.AST) -> str:
        """Resolves the V type for a given AST node."""
        if isinstance(node, ast.Name):
            return self.type_map.get(node.id, "void")
        return "void"

    def get_variable_types(self) -> Dict[str, str]:
        """Returns the map of variable names to their V types."""
        return self.type_map
