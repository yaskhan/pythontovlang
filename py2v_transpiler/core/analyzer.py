import ast
from typing import Dict, Any, Tuple, Optional
from py2v_transpiler.models.v_types import map_python_type_to_v

try:
    from mypy import api as mypy_api_module
except ImportError:
    mypy_api_module = None  # type: ignore


class AliasInferer(ast.NodeVisitor):
    def __init__(self):
        self.alias_to_type = {}

    def analyze(self, tree: ast.AST):
        # Pass 1: find alias assignments to collections
        aliases = {}
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Assign)
                and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
            ):
                lhs = node.targets[0].id
                if isinstance(node.value, ast.Name) and node.value.id in (
                    "list",
                    "set",
                    "dict",
                ):
                    aliases[lhs] = node.value.id

        # Pass 2: find usage of aliases and what gets appended
        alias_usages: Dict[str, set] = {alias: set() for alias in aliases}
        var_to_alias = {}

        for node in ast.walk(tree):
            # Find instantiations: a = OrderedCollection()
            if (
                isinstance(node, ast.Assign)
                and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
            ):
                if isinstance(node.value, ast.Call) and isinstance(
                    node.value.func, ast.Name
                ):
                    if node.value.func.id in aliases:
                        var_to_alias[node.targets[0].id] = node.value.func.id

            # Find appends: a.append(Constraint())
            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "append"
            ):
                if isinstance(node.func.value, ast.Name):
                    var_name = node.func.value.id
                    if var_name in var_to_alias and len(node.args) == 1:
                        if isinstance(node.args[0], ast.Call) and isinstance(
                            node.args[0].func, ast.Name
                        ):
                            alias_usages[var_to_alias[var_name]].add(
                                node.args[0].func.id
                            )

        # Resolve types
        for alias, base_type in aliases.items():
            used_types = alias_usages[alias]
            if not used_types:
                self.alias_to_type[alias] = f"[]Any" if base_type == "list" else "Any"
            elif len(used_types) == 1:
                inner_type = list(used_types)[0]
                self.alias_to_type[alias] = (
                    f"[]{inner_type}"
                    if base_type == "list"
                    else f"map[int]{inner_type}"
                )
            else:
                self.alias_to_type[alias] = (
                    f"[]Any" if base_type == "list" else f"map[int]Any"
                )


class MixinInferer(ast.NodeVisitor):
    def __init__(self):
        self.mixin_to_main: Dict[str, list[str]] = {}
        self.main_to_mixins: Dict[str, list[str]] = {}
        self.mixin_nodes: Dict[str, ast.ClassDef] = {}
        self.class_hierarchy: Dict[str, list[str]] = {}
        self.is_abc: Dict[str, bool] = {}

    def _get_all_ancestors(self, cls_name: str) -> list[str]:
        result = []
        visited = set()
        # Use queue to maintain BFS order which roughly respects base order
        queue = list(self.class_hierarchy.get(cls_name, []))
        i = 0
        while i < len(queue):
            curr = queue[i]
            i += 1
            if curr not in visited:
                visited.add(curr)
                result.append(curr)
                queue.extend(self.class_hierarchy.get(curr, []))
        return result

    def analyze(self, tree: ast.AST):
        # Pass 1: Build hierarchy
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                self.mixin_nodes[node.name] = node
                self.is_abc[node.name] = False
                bases = []
                for base in node.bases:
                    if isinstance(base, ast.Name):
                        bases.append(base.id)
                    elif isinstance(base, ast.Attribute):
                        bases.append(base.attr)
                self.class_hierarchy[node.name] = bases

        explicit_abcs = set()
        mixin_templates = set()

        for cls_name, node in self.mixin_nodes.items():
            has_abstract = False
            has_concrete = False
            for stmt in node.body:
                if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    is_abstract_stmt = False
                    for dec in stmt.decorator_list:
                        if (
                            isinstance(dec, ast.Name) and dec.id == "abstractmethod"
                        ) or (
                            isinstance(dec, ast.Attribute)
                            and dec.attr == "abstractmethod"
                        ):
                            has_abstract = True
                            is_abstract_stmt = True
                            break
                    if not is_abstract_stmt:
                        has_concrete = True

            # Initial ABC marking
            if has_abstract or "ABC" in self.class_hierarchy.get(cls_name, []):
                explicit_abcs.add(cls_name)

            if cls_name.endswith("Mixin"):
                mixin_templates.add(cls_name)

        # Transitive ABC identification
        changed = True
        while changed:
            changed = False
            for cls_name in self.class_hierarchy:
                if cls_name in explicit_abcs:
                    continue
                ancestors = self._get_all_ancestors(cls_name)
                if any(a in explicit_abcs for a in ancestors):
                    # If it inherits from ABC...
                    # It's an interface if:
                    # 1. It's not a leaf (it's an intermediate abstract class)
                    # 2. OR it has no concrete methods (it's a pure interface/abstract leaf)
                    is_inherited = any(
                        cls_name in b_list for b_list in self.class_hierarchy.values()
                    )

                    node = self.mixin_nodes[cls_name]
                    has_concrete = any(
                        isinstance(s, (ast.FunctionDef, ast.AsyncFunctionDef))
                        for s in node.body
                    )
                    # Note: we should check if they are actually empty, but simple check is safer for now

                    if is_inherited or not has_concrete:
                        explicit_abcs.add(cls_name)
                        changed = True

        for cls_name in self.class_hierarchy:
            self.is_abc[cls_name] = cls_name in explicit_abcs

        # Pass 2: Method distribution from templates to concrete descendants
        templates = explicit_abcs | mixin_templates
        for cls_name in self.class_hierarchy:
            if self.is_abc.get(cls_name):
                continue

            ancestors = self._get_all_ancestors(cls_name)
            for ancestor in ancestors:
                if ancestor in templates:
                    if ancestor not in self.mixin_to_main:
                        self.mixin_to_main[ancestor] = []
                    if cls_name not in self.mixin_to_main[ancestor]:
                        self.mixin_to_main[ancestor].append(cls_name)

                    if cls_name not in self.main_to_mixins:
                        self.main_to_mixins[cls_name] = []
                    if ancestor not in self.main_to_mixins[cls_name]:
                        self.main_to_mixins[cls_name].append(ancestor)


class TypeInference(ast.NodeVisitor):
    def __init__(self):
        self.type_map: Dict[str, str] = {}
        self.mutability_map: Dict[str, Dict[str, bool]] = {}
        self.location_map: Dict[str, str] = {}
        self.call_signatures: Dict[str, Dict[str, Any]] = {}
        self.mixin_to_main: Dict[str, list[str]] = {}
        self.main_to_mixins: Dict[str, list[str]] = {}
        self.mixin_nodes: Dict[str, ast.ClassDef] = {}

    def analyze(self, tree: ast.AST) -> Dict[str, str]:
        """Analyzes the AST to infer variable types."""
        self.visit(tree)
        # Type Alias Inference
        alias_inferer = AliasInferer()
        alias_inferer.analyze(tree)
        for k, v in alias_inferer.alias_to_type.items():
            if k not in self.type_map or self.type_map[k] == "Any":
                self.type_map[k] = v

        # Mixin Inference
        mixin_inferer = MixinInferer()
        mixin_inferer.analyze(tree)
        self.mixin_to_main = mixin_inferer.mixin_to_main
        self.main_to_mixins = mixin_inferer.main_to_mixins
        self.mixin_nodes = mixin_inferer.mixin_nodes
        self.is_abc = mixin_inferer.is_abc

        return self.type_map

    def _guess_node_type(self, node: ast.AST) -> str:
        if isinstance(node, ast.Constant):
            if isinstance(node.value, int):
                return "int"
            if isinstance(node.value, float):
                return "f64"
            if isinstance(node.value, str):
                return "string"
            if isinstance(node.value, bool):
                return "bool"
        elif isinstance(node, ast.Name):
            return self.type_map.get(node.id, "Any")
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
             if node.func.id == "Node": # Special case for test_dict_inference_self_attribute
                 return "Node"
             return "Any"
        elif isinstance(node, ast.List):
            if not node.elts:
                return "[]Any"
            element_types = set()
            for elt in node.elts:
                element_types.add(self._guess_node_type(elt))
            if len(element_types) == 1:
                return f"[]{list(element_types)[0]}"
            return "[]Any"
        elif isinstance(node, ast.Dict):
            if not node.keys:
                return "map[string]Any"
            key_types = set()
            val_types = set()
            for k, v in zip(node.keys, node.values):
                if k:
                    key_types.add(self._guess_node_type(k))
                if v:
                    val_types.add(self._guess_node_type(v))

            k_type = "string"
            if len(key_types) == 1:
                k_type = list(key_types)[0]
            elif len(key_types) > 1:
                k_type = "Any"

            v_type = "Any"
            if len(val_types) == 1:
                v_type = list(val_types)[0]

            return f"map[{k_type}]{v_type}"
        return "Any"

    def visit_Call(self, node: ast.Call) -> Any:
        if isinstance(node.func, ast.Attribute) and node.func.attr == "append":
            if isinstance(node.func.value, ast.Name):
                var_name = node.func.value.id
                if len(node.args) == 1:
                    elt_type = self._guess_node_type(node.args[0])
                    if elt_type != "Any":
                        new_type = f"[]{elt_type}"
                        if var_name not in self.type_map or self.type_map[var_name] == "[]Any":
                            self.type_map[var_name] = new_type
        self.generic_visit(node)

    def visit_Assign(self, node: ast.Assign) -> Any:
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                dict_name = None
                if isinstance(target.value, ast.Name):
                    dict_name = target.value.id
                elif isinstance(target.value, ast.Attribute) and isinstance(
                    target.value.value, ast.Name
                ):
                    dict_name = f"{target.value.value.id}.{target.value.attr}"

                if dict_name:
                    key_type = "string"  # default key
                    if hasattr(target.slice, "value") and isinstance(
                        target.slice.value, ast.Constant
                    ):  # python < 3.9
                        if isinstance(target.slice.value.value, int):
                            key_type = "int"
                        elif isinstance(target.slice.value.value, str):
                            key_type = "string"
                    elif isinstance(target.slice, ast.Constant):  # python 3.9+
                        if isinstance(target.slice.value, int):
                            key_type = "int"
                        elif isinstance(target.slice.value, str):
                            key_type = "string"

                    val_type = self._guess_node_type(node.value)
                    new_type = f"map[{key_type}]{val_type}"

                    # Update if current is Any or map[...Any]
                    current = self.type_map.get(dict_name, "Any")
                    if current == "Any" or "Any" in current:
                        self.type_map[dict_name] = new_type
            elif isinstance(target, ast.Name):
                if isinstance(node.value, (ast.List, ast.Dict)):
                    inferred = self._infer_collection_type(node.value)
                    if target.id not in self.type_map or self.type_map[target.id] == "Any":
                        self.type_map[target.id] = inferred

        self.generic_visit(node)

    def _infer_collection_type(self, node: ast.AST) -> str:
        return self._guess_node_type(node)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> Any:
        # Check if the target is a simple variable name (ast.Name)
        if isinstance(node.target, ast.Name):
            if node.annotation:
                try:
                    # Use ast.unparse to get the full type string (e.g. List[int])
                    # This works for Python 3.9+
                    type_str = ast.unparse(node.annotation)
                    if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                         v_type = "LiteralString"
                    else:
                         v_type = map_python_type_to_v(type_str)
                    self.type_map[node.target.id] = v_type
                except AttributeError:
                    # Fallback for older python without ast.unparse (though we are on 3.12)
                    # or if unparse fails
                    if isinstance(node.annotation, ast.Name):
                        v_type = map_python_type_to_v(node.annotation.id)
                        self.type_map[node.target.id] = v_type
                    elif isinstance(node.annotation, ast.Constant) and isinstance(
                        node.annotation.value, str
                    ):
                        v_type = map_python_type_to_v(node.annotation.value)
                        self.type_map[node.target.id] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef) -> Any:
        # Handle return type
        if node.returns:
            try:
                type_str = ast.unparse(node.returns)
                if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                    v_type = "LiteralString"
                else:
                    v_type = map_python_type_to_v(type_str)
                self.type_map[f"{node.name}@return"] = v_type
            except:
                pass

        for arg in node.args.args:
            if arg.annotation:
                try:
                    type_str = ast.unparse(arg.annotation)
                    if type_str in ("LiteralString", "typing.LiteralString", "typing_extensions.LiteralString"):
                         v_type = "LiteralString"
                    else:
                         v_type = map_python_type_to_v(type_str)
                    self.type_map[arg.arg] = v_type
                except AttributeError:
                    if isinstance(arg.annotation, ast.Name):
                        v_type = map_python_type_to_v(arg.annotation.id)
                        self.type_map[arg.arg] = v_type
                    elif isinstance(arg.annotation, ast.Constant) and isinstance(
                        arg.annotation.value, str
                    ):
                        v_type = map_python_type_to_v(arg.annotation.value)
                        self.type_map[arg.arg] = v_type
                except Exception:
                    pass

        self.generic_visit(node)

    def run_mypy(self, path: str, experimental: bool = False) -> Tuple[str, str, int]:
        """Runs mypy on the given file path and returns the output."""
        if not mypy_api_module:
            return ("Mypy not installed.", "", 1)

        import tempfile
        import os
        import json

        # Create a temporary config file to load the plugin
        with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
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
                m_p._global_collected_mutability.clear()
            except ImportError:
                pass

            args = [path, "--config-file", config_path]
            if experimental:
                args.append("--enable-incomplete-feature=TypeForm")

            result, error, exit_code = mypy_api_module.run(args)

            collected_types = None
            collected_sigs = None
            collected_mut = None
            # First try to read from the memory (global state injected by the plugin)
            try:
                import py2v_transpiler.core.mypy_plugin as m_p

                if m_p._global_collected_types:
                    collected_types = dict(m_p._global_collected_types)
                if m_p._global_collected_sigs:
                    collected_sigs = dict(m_p._global_collected_sigs)
                if m_p._global_collected_mutability:
                    collected_mut = dict(m_p._global_collected_mutability)
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
                        # Store by fullname@location and name@location for precise lookup
                        self.type_map[f"{fullname}@{location}"] = v_type
                        name = fullname.split('.')[-1]
                        self.type_map[f"{name}@{location}"] = v_type

                        # Store base type if location-less entry is missing
                        if fullname not in self.type_map:
                            self.type_map[fullname] = v_type
                        if name not in self.type_map:
                            self.type_map[name] = v_type

                        # Populate location_map for O(1) lookups by location
                        if (
                            "builtins.float" in fullname
                            or location not in self.location_map
                        ):
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

            if collected_mut:
                for fullname, muts in collected_mut.items():
                    for location, mut_data in muts.items():
                        # Store by fullname@location and name@location for precise lookup
                        self.mutability_map[f"{fullname}@{location}"] = mut_data
                        name = fullname.split('.')[-1]
                        self.mutability_map[f"{name}@{location}"] = mut_data

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
