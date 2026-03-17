from mypy.plugin import Plugin
from typing import Any, Dict, Optional, List, Union, cast
import json
from mypy.nodes import Var, AssignmentStmt, OperatorAssignmentStmt, CallExpr, MypyFile, ClassDef, FuncDef, Block, IfStmt, WhileStmt, ForStmt, TryStmt, NameExpr, MemberExpr, IndexExpr, TupleExpr, ListExpr, DictExpr, SetExpr, SymbolNode
from collections import defaultdict

# Global dictionary to store types without relying on the filesystem
# This is accessed from py2v_transpiler.core.analyzer
_global_collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
_global_collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)
_global_collected_mutability: Dict[str, Dict[str, Any]] = defaultdict(dict)

class MutabilityVisitor:
    def __init__(self, collected, mutating_methods):
        self.collected = collected
        self.mutating_methods = mutating_methods
        self.visited = set()

    def visit(self, node):
        if node is None or id(node) in self.visited:
            return
        self.visited.add(id(node))

        if isinstance(node, Var):
            self.visit_var(node)
        elif isinstance(node, AssignmentStmt):
            self.visit_assignment_stmt(node)
        elif isinstance(node, OperatorAssignmentStmt):
            self.visit_operator_assignment_stmt(node)
        elif isinstance(node, CallExpr):
            self.visit_call_expr(node)

        # Generic traversal
        if isinstance(node, MypyFile):
            for sym in node.names.values(): self.visit(sym.node)
        elif isinstance(node, ClassDef):
            if node.info:
                for sym in node.info.names.values(): self.visit(sym.node)
            for stmt in node.defs.body: self.visit(stmt)
        elif isinstance(node, FuncDef):
            for arg in node.arguments: self.visit(arg.variable)
            self.visit(node.body)
        elif isinstance(node, Block):
            for stmt in node.body: self.visit(stmt)
        elif isinstance(node, IfStmt):
            for e in node.expr: self.visit(e)
            for b in node.body: self.visit(b)
            self.visit(node.else_body)
        elif isinstance(node, WhileStmt):
            self.visit(node.expr); self.visit(node.body); self.visit(node.else_body)
        elif isinstance(node, ForStmt):
            self.visit(node.expr); self.visit(node.index); self.visit(node.body); self.visit(node.else_body)
        elif isinstance(node, TryStmt):
            self.visit(node.body)
            for h in node.handlers:
                if hasattr(h, 'type'): self.visit(h.type)
                if hasattr(h, 'name'): self.visit(h.name)
                self.visit(h.body)
            self.visit(node.else_body); self.visit(node.finally_body)
        elif isinstance(node, (TupleExpr, ListExpr)):
            for item in node.items: self.visit(item)
        elif isinstance(node, NameExpr):
            self.visit(node.node)
        elif isinstance(node, MemberExpr):
            self.visit(node.expr); self.visit(node.node)
        elif isinstance(node, IndexExpr):
            self.visit(node.base); self.visit(node.index)

    def visit_var(self, v):
        key = f"{v.line}:{v.column}"
        if v.fullname not in self.collected: self.collected[v.fullname] = {}
        if key not in self.collected[v.fullname]:
            self.collected[v.fullname][key] = {
                "is_reassigned": getattr(v, "is_reassigned", False),
                "is_final": v.is_final,
                "is_mutated": False
            }
        else:
            self.collected[v.fullname][key]["is_reassigned"] = getattr(v, "is_reassigned", False)
            self.collected[v.fullname][key]["is_final"] = v.is_final

    def _mark_mutated(self, expr):
        if isinstance(expr, NameExpr) and isinstance(expr.node, Var):
            v = expr.node
            v_key = f"{v.line}:{v.column}"
            if v.fullname not in self.collected: self.collected[v.fullname] = {}
            if v_key not in self.collected[v.fullname]:
                 self.collected[v.fullname][v_key] = {"is_reassigned": getattr(v, "is_reassigned", False), "is_final": v.is_final, "is_mutated": True}
            else:
                 self.collected[v.fullname][v_key]["is_mutated"] = True
        elif isinstance(expr, MemberExpr):
            self._mark_mutated(expr.expr)
        elif isinstance(expr, IndexExpr):
            self._mark_mutated(expr.base)

    def visit_assignment_stmt(self, s):
        for lvalue in s.lvalues:
            if isinstance(lvalue, (IndexExpr, MemberExpr)):
                self._mark_mutated(lvalue.expr if isinstance(lvalue, MemberExpr) else lvalue.base)
            elif isinstance(lvalue, (TupleExpr, ListExpr)):
                # Handle unpacking: x, y = ...
                def visit_unpacking(node):
                    if isinstance(node, (TupleExpr, ListExpr)):
                        for elt in node.items: visit_unpacking(elt)
                    elif isinstance(node, (IndexExpr, MemberExpr)):
                        self._mark_mutated(node.expr if isinstance(node, MemberExpr) else node.base)
                visit_unpacking(lvalue)
        self.visit(s.rvalue)

    def visit_operator_assignment_stmt(self, s):
        if isinstance(s.lvalue, (IndexExpr, MemberExpr)):
            self._mark_mutated(s.lvalue.expr if isinstance(s.lvalue, MemberExpr) else s.lvalue.base)
        elif isinstance(s.lvalue, NameExpr):
            self._mark_mutated(s.lvalue)
        self.visit(s.lvalue)
        self.visit(s.rvalue)

    def visit_call_expr(self, e):
        if isinstance(e.callee, MemberExpr) and e.callee.name in self.mutating_methods:
            self._mark_mutated(e.callee.expr)
        self.visit(e.callee)
        for arg in e.args: self.visit(arg)


class VlangPlugin(Plugin):
    """Mypy plugin for py2v_transpiler to extract type information."""

    def __init__(self, options):
        super().__init__(options)
        self.collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_mutability: Dict[str, Dict[str, Any]] = defaultdict(dict)
        self._files_to_process = []
        self.checker: Any = None
        self._processed_exprs = set()
        self._processed_files = set()

    def get_additional_deps(self, file: Any) -> Any:
        self._files_to_process.append(file)
        return []

    def get_function_hook(self, fullname: str):
        return self.get_method_hook(fullname)

    def get_method_hook(self, fullname: str):
        def hook(ctx):
             return self._hook(ctx, fullname)
        return hook

    def _hook(self, ctx, fullname: str):
        if not self.checker:
             self.checker = ctx.api
        if hasattr(ctx.context, 'line'):
            key = f"{ctx.context.line}:{ctx.context.column}"
            # Store under both fullname and short name for flexibility
            short_name = fullname.split('.')[-1]
            self.collected_types[fullname][key] = str(ctx.default_return_type)

            # Also store call signature
            args = []
            for arg_list in ctx.arg_types:
                for arg in arg_list:
                    args.append(str(arg))

            is_class = False
            has_init = False
            try:
                from mypy.types import Instance
                if isinstance(ctx.default_return_type, Instance):
                    type_info = ctx.default_return_type.type
                    is_class = type_info.fullname == fullname
                    has_init = '__init__' in type_info.names
            except Exception:
                pass

            sig_data = {
                "args": args,
                "return": str(ctx.default_return_type),
                "is_class": is_class,
                "has_init": has_init
            }

            self.collected_sigs[fullname][key] = json.dumps(sig_data)
            self.collected_sigs[short_name][key] = json.dumps(sig_data)
            # Direct location-based lookup
            self.collected_sigs[key][key] = json.dumps(sig_data)

        return ctx.default_return_type

    def get_attribute_hook(self, fullname: str):
        def hook(ctx):
             if hasattr(ctx.context, 'line'):
                 key = f"{ctx.context.line}:{ctx.context.column}"
                 self.collected_types[fullname][key] = str(ctx.default_attr_type)
             return ctx.default_attr_type
        return hook

    def report_config_data(self, ctx: Any) -> Any:
        global _global_collected_types, _global_collected_sigs, _global_collected_mutability

        # Mutating methods
        MUTATING_METHODS = {
            # list
            "append", "extend", "pop", "clear", "insert", "remove", "reverse", "sort",
            # dict
            "update", "popitem", "setdefault",
            # set
            "add", "discard", "intersection_update"
        }

        # Collect types from checker's type_map for narrowing and calls
        if self.checker and hasattr(self.checker, 'type_map'):
            for expr, typ in self.checker.type_map.items():
                state_id = (id(expr), id(typ))
                if state_id in self._processed_exprs:
                    continue
                self._processed_exprs.add(state_id)
                if hasattr(expr, 'line'):
                    key = f"{expr.line}:{expr.column}"

                    if isinstance(expr, (CallExpr, ListExpr, DictExpr, SetExpr, TupleExpr)):
                        # Store by location for direct lookup
                        self.collected_types[key][key] = str(typ)

                    if isinstance(expr, CallExpr):
                        from mypy.types import Instance, CallableType

                        if isinstance(expr.callee, (NameExpr, MemberExpr)) and expr.callee.node and isinstance(expr.callee.node, (FuncDef, Var)):
                            node = expr.callee.node
                            f_node: Optional[FuncDef] = None
                            if isinstance(node, FuncDef):
                                f_node = node
                            elif isinstance(node, Var) and hasattr(node, 'type') and isinstance(node.type, CallableType):
                                c_type = cast(CallableType, node.type)
                                if c_type.definition and isinstance(c_type.definition, FuncDef):
                                    f_node = c_type.definition

                            ret_type_str = str(typ)
                            if f_node and hasattr(f_node, 'type') and isinstance(f_node.type, CallableType):
                                ret_type_str = str(f_node.type.ret_type)

                            if "TypeIs[" not in ret_type_str and "TypeGuard[" not in ret_type_str:
                                # Try to extract it from the actual function type if it was lost in type_map
                                if isinstance(expr.callee, (NameExpr, MemberExpr)) and expr.callee.node and hasattr(expr.callee.node, 'type'):
                                    callee_node_type = getattr(expr.callee.node, 'type', None)
                                    if isinstance(callee_node_type, CallableType):
                                        ret_type_str = str(callee_node_type.ret_type)

                            args_data = []
                            if f_node:
                                for arg in f_node.arguments:
                                    if hasattr(arg, 'variable') and hasattr(arg.variable, 'type'):
                                        args_data.append(str(arg.variable.type))
                                    else:
                                        args_data.append("Any")

                            sig_data = {
                                "args": args_data,
                                "return": ret_type_str,
                                "is_class": False,
                                "has_init": False
                            }
                            fullname = f_node.fullname if f_node else (expr.callee.fullname if isinstance(expr.callee, NameExpr) else None)
                            short_name = f_node.name if f_node else (expr.callee.name if isinstance(expr.callee, MemberExpr) else None)
                            if fullname: self.collected_sigs[fullname][key] = json.dumps(sig_data)
                            if short_name: self.collected_sigs[short_name][key] = json.dumps(sig_data)
                            self.collected_sigs[key][key] = json.dumps(sig_data)

                        if isinstance(typ, Instance):
                            type_info = typ.type
                            fullname_cls = type_info.fullname
                            short_name_cls = type_info.name

                            sig_data = {
                                "args": [], # difficult to recover from type_map easily
                                "return": str(typ),
                                "is_class": True, # heuristic: if return type is Instance and we are at CallExpr, it's likely a class call
                                "has_init": '__init__' in type_info.names
                            }
                            self.collected_sigs[fullname_cls][key] = json.dumps(sig_data)
                            self.collected_sigs[short_name_cls][key] = json.dumps(sig_data)
                            self.collected_sigs[key][key] = json.dumps(sig_data)

                    name: Optional[str] = None
                    fullname_node: Optional[str] = None
                    if isinstance(expr, NameExpr):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif isinstance(expr, MemberExpr):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif isinstance(expr, Var):
                        name = expr.name
                        fullname_node = expr.fullname
                    elif hasattr(expr, 'name'):
                        name = getattr(expr, 'name')
                        fullname_node = getattr(expr, 'fullname', None)

                    if name:
                        # Store by multiple keys to increase hit rate
                        self.collected_types[name][key] = str(typ)
                        # Also store by line only for block-start heuristic
                        self.collected_types[name][f"{expr.line}:*"] = str(typ)
                        if fullname_node:
                            self.collected_types[fullname_node][key] = str(typ)
                            self.collected_types[fullname_node][f"{expr.line}:*"] = str(typ)

        # Collect mutability info from processed files
        visitor = MutabilityVisitor(self.collected_mutability, MUTATING_METHODS)
        for file_node in self._files_to_process:
            if id(file_node) in self._processed_files:
                continue
            self._processed_files.add(id(file_node))
            visitor.visit(file_node)

        # Update the module-level global dictionary
        for k, v in self.collected_types.items():
            _global_collected_types[k].update(v)

        for k, v in self.collected_sigs.items():
            _global_collected_sigs[k].update(v)

        for k, v in self.collected_mutability.items():
            _global_collected_mutability[k].update(v)

        return self.collected_types

def plugin(version: str):
    return VlangPlugin
