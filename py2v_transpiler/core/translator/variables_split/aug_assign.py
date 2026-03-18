import ast
from ..base import TranslatorBase


class AugAssignMixin(TranslatorBase):
    """Обработка операторов присваивания с операцией: +=, -=, *=, /=, %=, **=, //="""
    
    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        if isinstance(node.op, (ast.Pow, ast.FloorDiv)):
            # Handle special cases **= and //= which need expansion to target = func(target, value)
            # We must ensure target components (e.g. index) are evaluated once.
            new_target, setup_stmts = self._capture_target(node.target)
            value = self.visit(node.value)

            for stmt in setup_stmts:
                self.output.append(stmt)

            emit_fn = self.output.append
            if self.in_main:
                base_target = new_target.split('.')[0].split('[')[0]
                if base_target in getattr(self, "global_vars", set()) or base_target.isupper():
                    emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())

            if isinstance(node.op, ast.Pow):
                self.emitter.add_import("math")
                target_type = self._guess_type(node.target) if hasattr(self, '_guess_type') else "unknown"
                value_type = self._guess_type(node.value) if hasattr(self, '_guess_type') else "unknown"

                # Check for negative exponent literal
                is_negative_literal = False
                if isinstance(node.value, ast.UnaryOp) and isinstance(node.value.op, ast.USub):
                    if isinstance(node.value.operand, ast.Constant) and isinstance(node.value.operand.value, (int, float)):
                         is_negative_literal = True
                elif isinstance(node.value, ast.Constant) and isinstance(node.value.value, (int, float)) and node.value.value < 0:
                     is_negative_literal = True

                if target_type == "int" and value_type == "int" and not is_negative_literal:
                     # Integer power
                     emit_fn(f"{self._indent()}{new_target} = int(math.powi(f64({new_target}), {value}))")
                else:
                     l_val = new_target if target_type == "f64" else f"f64({new_target})"
                     r_val = value if value_type == "f64" else f"f64({value})"
                     if target_type == "int":
                          emit_fn(f"{self._indent()}{new_target} = int(math.pow({l_val}, {r_val}))")
                     else:
                          emit_fn(f"{self._indent()}{new_target} = math.pow({l_val}, {r_val})")
            elif isinstance(node.op, ast.FloorDiv):
                target_type = self._guess_type(node.target) if hasattr(self, '_guess_type') else "unknown"
                self.emitter.add_import("math")
                if target_type == "f64" or target_type == "float":
                     emit_fn(f"{self._indent()}{new_target} = math.floor({new_target} / {value})")
                else:
                     emit_fn(f"{self._indent()}{new_target} = int(math.floor(f64({new_target}) / f64({value})))")
            return

        target = self.visit(node.target)
        value = self.visit(node.value)
        op_map = {
            ast.Add: "+=", ast.Sub: "-=", ast.Mult: "*=", ast.Div: "/=",
            ast.Mod: "%=", ast.BitOr: "|=", ast.BitAnd: "&=", ast.BitXor: "^=",
            ast.LShift: "<<=", ast.RShift: ">>="
        }

        emit_fn = self.output.append
        if self.in_main:
            base_target = target.split('.')[0].split('[')[0]
            if base_target in getattr(self, "global_vars", set()) or base_target.isupper():
                emit_fn = lambda stmt: self.emitter.add_init_statement(stmt.strip())

        # V supports +=, -=, *=, /=, %=, |=, &=, ^=, <<=, >>=
        op_str = op_map.get(type(node.op))
        if op_str:
             emit_fn(f"{self._indent()}{target} {op_str} {value}")
        elif isinstance(node.op, ast.MatMult):
             emit_fn(f"{self._indent()}{target} = {target}.matmul({value})")
        else:
             emit_fn(f"{self._indent()}// Unsupported AugAssign operator: {type(node.op)}")
