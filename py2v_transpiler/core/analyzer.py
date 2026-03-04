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
        self.class_hierarchy: Dict[str, list[str]] = {}
        self.is_abc: Dict[str, bool] = {}

    def _get_all_ancestors(self, cls_name: str) -> set[str]:
        ancestors = set()
        stack = list(self.class_hierarchy.get(cls_name, []))
        while stack:
            curr = stack.pop()
            if curr not in ancestors:
                ancestors.add(curr)
                stack.extend(self.class_hierarchy.get(curr, []))
        return ancestors

    def analyze(self, tree: ast.AST):
        # Pass 1: Build hierarchy and identify ABCs/Mixins
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                self.is_abc[node.name] = False
                self.mixin_nodes[node.name] = node
                bases = []
                for base in node.bases:
                    if isinstance(base, ast.Name):
                        bases.append(base.id)
                    elif isinstance(base, ast.Attribute):
                        bases.append(base.attr)
                self.class_hierarchy[node.name] = bases

        # A class is an ABC if:
        # 1. It contains @abstractmethod
        # 2. It inherits from ABC AND is inherited by others (it's an intermediate abstract class)
        # 3. It's a Mixin (template)

        explicit_abcs = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                has_abstract = False
                for stmt in node.body:
                    if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        for dec in stmt.decorator_list:
                            if (isinstance(dec, ast.Name) and dec.id == "abstractmethod") or \
                               (isinstance(dec, ast.Attribute) and dec.attr == "abstractmethod"):
                                has_abstract = True
                                break
                    if has_abstract: break

                if has_abstract:
                    explicit_abcs.add(node.name)
                elif node.name.endswith("Mixin"):
                    explicit_abcs.add(node.name)
                elif "ABC" in self.class_hierarchy[node.name]:
                    # Inherits from ABC. Is it a leaf or intermediate?
                    is_inherited = False
                    for other_cls, other_bases in self.class_hierarchy.items():
                        if node.name in other_bases:
                            is_inherited = True
                            break
                    if is_inherited:
                        explicit_abcs.add(node.name)
                    else:
                        # Leaf class inheriting from ABC with no abstract methods -> CONCRETE
                        pass
                else:
                    # Also check if it inherits from another ABC
                    # We need a proper ancestor check here.
                    pass

        # Final pass for transitive ABC-ness
        changed = True
        while changed:
            changed = False
            for cls_name, bases in self.class_hierarchy.items():
                if cls_name in explicit_abcs:
                    continue

                # If it inherits from an ABC...
                is_inherited_from_abc = any(b in explicit_abcs for b in bases)
                if is_inherited_from_abc:
                     # Check if it has concrete methods. If NOT, it's an ABC too.
                     node = self.mixin_nodes[cls_name]
                     has_concrete = False
                     for stmt in node.body:
                        if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                            # Check if it's empty
                            is_empty = True
                            for body_stmt in stmt.body:
                                if isinstance(body_stmt, ast.Pass): continue
                                if isinstance(body_stmt, ast.Expr) and isinstance(body_stmt.value, ast.Constant) and body_stmt.value.value is Ellipsis: continue
                                if isinstance(body_stmt, ast.Raise) and isinstance(body_stmt.exc, ast.Name) and body_stmt.exc.id == "NotImplementedError": continue
                                if isinstance(body_stmt, ast.Raise) and isinstance(body_stmt.exc, ast.Call) and isinstance(body_stmt.exc.func, ast.Name) and body_stmt.exc.func.id == "NotImplementedError": continue
                                is_empty = False
                                break
                            if not is_empty:
                                has_concrete = True
                                break

                     if not has_concrete:
                         explicit_abcs.add(cls_name)
                         changed = True
                     else:
                         # It has concrete methods. If it's inherited by others, it might still be an ABC (interface in V)
                         # BUT ONLY if those descendants are themselves ABCs.
                         # If it's inherited by a concrete class, then THIS class must be a struct (if we want to use V embedding)
                         # or at least we should NOT mark it as ABC if it's intended to be a base struct.

                         # Actually, in V, you can't embed an interface in a struct to get its methods.
                         # So if a class has concrete methods and is inherited by a struct, it MUST be a struct.

                         # Let's check if all descendants are ABCs.
                         all_descendants_are_abcs = True
                         stack = []
                         for other_cls, other_bases in self.class_hierarchy.items():
                            if cls_name in other_bases:
                                stack.append(other_cls)

                         if not stack:
                             all_descendants_are_abcs = False # Leaf with concrete methods is NOT an ABC

                         visited_desc = set()
                         while stack:
                             curr = stack.pop()
                             if curr in visited_desc: continue
                             visited_desc.add(curr)

                             if curr not in explicit_abcs:
                                 # We don't know yet if curr is an ABC.
                                 # But if it's a leaf and has no @abstractmethod, it's concrete.

                                 is_leaf = True
                                 for c, b in self.class_hierarchy.items():
                                     if curr in b:
                                         is_leaf = False
                                         stack.append(c)

                                 if is_leaf:
                                     # Check if it's an explicit ABC (we already know it's not in explicit_abcs yet)
                                     all_descendants_are_abcs = False
                                     break

                         if all_descendants_are_abcs and visited_desc:
                             explicit_abcs.add(cls_name)
                             changed = True

        for cls_name in self.class_hierarchy:
            self.is_abc[cls_name] = cls_name in explicit_abcs

        # Pass 2: Transitive closure to distribute methods from ABCs/Mixins to all concrete descendants
        for cls_name in self.class_hierarchy:
            ancestors = self._get_all_ancestors(cls_name)

            # Re-evaluate is_abc: if it has abstract methods, it's an ABC.
            # If it's inherited from ABC and not all ancestors are interfaces... wait.
            # Simplified: if any ancestor is an ABC, it can be an interface.
            # But the user specifically wants to transpile ABCs to V interfaces.

            # Correct logic for V:
            # 1. Any class explicitly marked as ABC or containing @abstractmethod is a V interface.
            # 2. Any class inheriting from an ABC can be either another interface or a concrete struct.
            # 3. If it's a concrete struct, it needs all concrete methods from its ABC ancestors.

            if self.is_abc.get(cls_name):
                # If it's an interface, it doesn't get concrete methods DISTRIBUTED to it as a struct,
                # because it's not a struct.
                continue

            for ancestor in ancestors:
                if self.is_abc.get(ancestor):
                    # ABCs and Mixins act as templates: their concrete methods are pushed to descendants
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
        self.type_map.update(alias_inferer.alias_to_type)

        # Mixin Inference
        mixin_inferer = MixinInferer()
        mixin_inferer.analyze(tree)
        self.mixin_to_main = mixin_inferer.mixin_to_main
        self.main_to_mixins = mixin_inferer.main_to_mixins
        self.mixin_nodes = mixin_inferer.mixin_nodes
        self.is_abc = mixin_inferer.is_abc

        return self.type_map


    def visit_Assign(self, node: ast.Assign) -> Any:
        for target in node.targets:
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
            if node.annotation:
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
