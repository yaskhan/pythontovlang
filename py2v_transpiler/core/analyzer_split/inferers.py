import ast
from typing import Dict, List, Set, Optional, Any


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
                elif isinstance(node.value, ast.Name) and node.value.id in (
                    "List", "Set", "Dict"
                ):
                     # Handle typing aliases
                     aliases[lhs] = node.value.id.lower()

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
        self.static_methods: Dict[str, set[str]] = {}
        self.class_methods: Dict[str, set[str]] = {}

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
        # Pass 1: Build hierarchy and collect static/class methods
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                self.mixin_nodes[node.name] = node
                self.is_abc[node.name] = False
                self.static_methods[node.name] = set()
                self.class_methods[node.name] = set()

                for child in node.body:
                    if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        for decorator in child.decorator_list:
                            dec_name = ""
                            if isinstance(decorator, ast.Name):
                                dec_name = decorator.id
                            elif isinstance(decorator, ast.Call):
                                if isinstance(decorator.func, ast.Name):
                                    dec_name = decorator.func.id
                            elif isinstance(decorator, ast.Attribute):
                                dec_name = decorator.attr

                            if dec_name == "staticmethod":
                                self.static_methods[node.name].add(child.name)
                            elif dec_name == "classmethod":
                                self.class_methods[node.name].add(child.name)

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
                    # If an ancestor is a template (ABC or Mixin), it and all of its ancestors
                    # should be distributed to the concrete class, because the
                    # template itself will not be embedded as a struct field.
                    mixin_chain = [ancestor] + self._get_all_ancestors(ancestor)
                    for m in mixin_chain:
                        if m not in self.mixin_to_main:
                            self.mixin_to_main[m] = []
                        if cls_name not in self.mixin_to_main[m]:
                            self.mixin_to_main[m].append(cls_name)

                        if cls_name not in self.main_to_mixins:
                            self.main_to_mixins[cls_name] = []
                        if m not in self.main_to_mixins[cls_name]:
                            self.main_to_mixins[cls_name].append(m)


class FunctionMutabilityScanner(ast.NodeVisitor):
    def __init__(self):
        # function_name -> [index of mutated parameters]
        self.func_param_mutability: Dict[str, List[int]] = {}
        self.current_func: Optional[str] = None
        self.current_params: List[str] = []
        self.mutated_params: Set[str] = set()
        self.reassigned_params: Set[str] = set()
        self._scope_stack: List[str] = []
        self.mutability_map: Dict[str, Dict[str, Any]] = {}

    def _get_base_node(self, node: ast.AST) -> ast.AST:
        curr = node
        while isinstance(curr, ast.Subscript):
            curr = curr.value
        return curr

    def analyze(self, tree: ast.AST, mutability_map: Optional[Dict[str, Dict[str, Any]]] = None):
        if mutability_map is not None:
            self.mutability_map = mutability_map
        self.visit(tree)
        return self.func_param_mutability

    def visit_ClassDef(self, node: ast.ClassDef):
        self._scope_stack.append(node.name)
        self.generic_visit(node)
        self._scope_stack.pop()

    def visit_FunctionDef(self, node: ast.FunctionDef):
        old_func = self.current_func
        old_params = self.current_params
        old_mutated = self.mutated_params
        old_reassigned = self.reassigned_params

        self.current_func = node.name
        self.current_params = [arg.arg for arg in node.args.args]
        if hasattr(node.args, "posonlyargs"):
            self.current_params = [arg.arg for arg in node.args.posonlyargs] + self.current_params
        if hasattr(node.args, "kwonlyargs"):
            self.current_params = self.current_params + [arg.arg for arg in node.args.kwonlyargs]

        self.mutated_params = set()
        self.reassigned_params = set()

        self.generic_visit(node)

        # Update mutability_map with qualified names
        prefix = ".".join(self._scope_stack)
        func_qual_name = f"{prefix}.{node.name}" if prefix else node.name

        for p in self.current_params:
            is_m = p in self.mutated_params
            is_r = p in self.reassigned_params
            if is_m or is_r:
                key = f"{func_qual_name}.{p}"
                if key not in self.mutability_map:
                    self.mutability_map[key] = {"is_reassigned": False, "is_final": False, "is_mutated": False}

                if is_m: self.mutability_map[key]["is_mutated"] = True
                if is_r: self.mutability_map[key]["is_reassigned"] = True

                # Also update the simple name for current function context
                if p not in self.mutability_map:
                     self.mutability_map[p] = {"is_reassigned": False, "is_final": False, "is_mutated": False}
                if is_m: self.mutability_map[p]["is_mutated"] = True
                if is_r: self.mutability_map[p]["is_reassigned"] = True

        mutated_indices = [
            i for i, p in enumerate(self.current_params) if p in self.mutated_params or p in self.reassigned_params
        ]
        self.func_param_mutability[node.name] = mutated_indices
        if prefix:
             self.func_param_mutability[func_qual_name] = mutated_indices

        self.current_func = old_func
        self.current_params = old_params
        self.mutated_params = old_mutated
        self.reassigned_params = old_reassigned

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef):
        self.visit_FunctionDef(node) # type: ignore

    def _mark_mutated(self, node: ast.AST):
        if isinstance(node, ast.Name) and node.id in self.current_params:
            self.mutated_params.add(node.id)
        elif isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
            if node.value.id in self.current_params:
                self.mutated_params.add(node.value.id)
        elif isinstance(node, ast.Subscript):
            self._mark_mutated(node.value)

    def _mark_reassigned(self, node: ast.AST):
        if isinstance(node, ast.Name) and node.id in self.current_params:
            self.reassigned_params.add(node.id)
        elif isinstance(node, (ast.Tuple, ast.List)):
            for elt in node.elts:
                self._mark_reassigned(elt)

    def visit_Assign(self, node: ast.Assign):
        for target in node.targets:
            if isinstance(target, (ast.Subscript, ast.Attribute)):
                self._mark_mutated(self._get_base_node(target.value))
            elif isinstance(target, ast.Name):
                self._mark_reassigned(target)
        self.generic_visit(node)

    def visit_AugAssign(self, node: ast.AugAssign):
        if isinstance(node.target, (ast.Subscript, ast.Attribute)):
            self._mark_mutated(self._get_base_node(node.target.value))
        elif isinstance(node.target, ast.Name):
            self._mark_reassigned(node.target)
        self.generic_visit(node)

    def visit_Delete(self, node: ast.Delete):
        for target in node.targets:
            if isinstance(target, ast.Subscript):
                self._mark_mutated(self._get_base_node(target.value))
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call):
        if isinstance(node.func, ast.Attribute):
            mutating_methods = {
                "append", "extend", "insert", "pop", "remove", "clear",
                "update", "setdefault", "delete", "add", "discard"
            }
            if node.func.attr in mutating_methods:
                self._mark_mutated(node.func.value)
        self.generic_visit(node)
