from mypy.plugin import Plugin, ReportConfigContext
from typing import Any, Dict, Optional, List, Union, cast, Set
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
            if hasattr(node, 'defs'):
                for stmt in node.defs: self.visit(stmt)
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
    def __init__(self, options: Any):
        super().__init__(options)
        self.collected_types: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_sigs: Dict[str, Dict[str, str]] = defaultdict(dict)
        self.collected_mutability: Dict[str, Dict[str, Any]] = defaultdict(dict)
        self._processed_files: Set[int] = set()
        self._files_to_process: List[MypyFile] = []

    def get_additional_deps(self, file: MypyFile) -> List[tuple[int, str, int]]:
        self._files_to_process.append(file)
        return []

    def report_config_data(self, context: ReportConfigContext) -> Optional[Dict[str, Any]]:
        if not self._files_to_process:
            return None

        class TypeCollector:
            def __init__(self, plugin, type_map):
                self.plugin = plugin
                self.type_map = type_map

            def collect(self):
                from mypy.nodes import NameExpr, MemberExpr, CallExpr, IndexExpr, Var
                from mypy.types import Instance
                for node, typ in self.type_map.items():
                    if not hasattr(node, 'line'): continue
                    key = f"{node.line}:{node.column}"
                    name = getattr(node, 'name', None)
                    fullname = None
                    if isinstance(node, (NameExpr, MemberExpr)) and node.node:
                        fullname = getattr(node.node, 'fullname', None)
                    elif isinstance(node, Var):
                        fullname = node.fullname

                    if name:
                        self.plugin.collected_types[name][key] = str(typ)
                    if isinstance(node, (NameExpr, MemberExpr, CallExpr, IndexExpr)):
                        self.plugin.collected_types['@'][key] = str(typ)
                    if fullname:
                        self.plugin.collected_types[fullname][key] = str(typ)
                        self.plugin.collected_types[fullname][f"{node.line}:*"] = str(typ)
                    if name and fullname:
                        self.plugin.collected_types[f"{name}@{key}"][key] = str(typ)
                    if isinstance(node, CallExpr): self._collect_call_sig(node, typ, key)
                    if isinstance(typ, Instance): self._collect_instance_sig(typ, key)

            def _collect_call_sig(self, expr, typ, key):
                from mypy.nodes import NameExpr, MemberExpr, FuncDef, Var
                from mypy.types import CallableType
                f_node = None
                if isinstance(expr.callee, (NameExpr, MemberExpr)) and expr.callee.node and isinstance(expr.callee.node, (FuncDef, Var)):
                    node_callee = expr.callee.node
                    if isinstance(node_callee, FuncDef):
                        f_node = node_callee
                    elif isinstance(node_callee, Var) and hasattr(node_callee, 'type') and isinstance(node_callee.type, CallableType):
                        c_type = node_callee.type
                        if c_type.definition and isinstance(c_type.definition, FuncDef):
                            f_node = c_type.definition
                    ret_type_str = str(typ)
                    if f_node and hasattr(f_node, 'type') and isinstance(f_node.type, CallableType):
                        ret_type_str = str(f_node.type.ret_type)
                    args_data = []
                    if f_node:
                        for arg in f_node.arguments:
                            if hasattr(arg, 'variable') and hasattr(arg.variable, 'type'):
                                args_data.append(str(arg.variable.type))
                            else: args_data.append("Any")
                    sig_data = {"args": args_data, "return": ret_type_str, "is_class": False, "has_init": False}
                    fn_name = f_node.fullname if f_node else getattr(expr.callee, 'fullname', None)
                    sh_name = f_node.name if f_node else getattr(expr.callee, 'name', None)
                    if fn_name: self.plugin.collected_sigs[fn_name][key] = json.dumps(sig_data)
                    if sh_name: self.plugin.collected_sigs[sh_name][key] = json.dumps(sig_data)
                    self.plugin.collected_sigs[key][key] = json.dumps(sig_data)

            def _collect_instance_sig(self, typ, key):
                type_info = typ.type
                sig_data_cls = {
                    "args": [], "return": str(typ), "is_class": True,
                    "has_init": '__init__' in type_info.names
                }
                if 'namedtuple' in type_info.metadata:
                    nt_meta = type_info.metadata['namedtuple']
                    sig_data_cls["namedtuple_metadata"] = {
                        "fields": nt_meta.get("fields", []),
                        "types": [str(t) for t in nt_meta.get("types", [])]
                    }
                fn_cls = type_info.fullname
                sh_cls = type_info.name
                self.plugin.collected_sigs[fn_cls][key] = json.dumps(sig_data_cls)
                self.plugin.collected_sigs[sh_cls][key] = json.dumps(sig_data_cls)
                self.plugin.collected_sigs[key][key] = json.dumps(sig_data_cls)

        type_map: Dict[Any, Any] = {}
        if hasattr(self, 'checker') and self.checker:
            type_map = getattr(self.checker, 'type_map', {})
            if not type_map and hasattr(self.checker, 'expr_checker'):
                type_map = getattr(self.checker.expr_checker, 'type_map', {})

        if type_map:
            collector = TypeCollector(self, type_map)
            collector.collect()

        mutating_methods = {
            "append", "extend", "insert", "remove", "pop", "clear", "sort",
            "update", "popitem", "setdefault",
            "add", "discard", "intersection_update"
        }
        mut_visitor = MutabilityVisitor(self.collected_mutability, mutating_methods)
        for file_node in self._files_to_process:
            if id(file_node) in self._processed_files: continue
            self._processed_files.add(id(file_node))
            mut_visitor.visit(file_node)

        for k, v in self.collected_types.items(): _global_collected_types[k].update(v)
        for k, v in self.collected_sigs.items(): _global_collected_sigs[k].update(v)
        for k, v in self.collected_mutability.items(): _global_collected_mutability[k].update(v)

        return self.collected_types

def plugin(version: str):
    return VlangPlugin
