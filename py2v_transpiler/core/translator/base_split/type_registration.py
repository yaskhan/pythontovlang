"""Type registration for literal enums and sum types."""

import ast
from typing import Any, Dict, List, Optional, Sequence, Set


class TypeRegistrationMixin:
    """Mixin for registering literal enums and sum types."""

    def _register_literal_enum(self, nodes: Sequence[ast.AST]) -> str:
        """
        Registers a V enum for a Python Literal type.
        Returns the name of the generated enum.
        """
        values: List[Any] = []
        for node in nodes:
            if isinstance(node, ast.Constant):
                values.append(node.value)
            elif (
                isinstance(node, ast.UnaryOp) and
                isinstance(node.op, ast.USub) and
                isinstance(node.operand, ast.Constant) and
                isinstance(node.operand.value, (int, float))
            ):
                val = node.operand.value
                values.append(-val)
            else:
                values.append(str(node))

        # Check if all values are of the same basic type
        val_types = {type(v) for v in values}
        base_v_type = "string"
        if len(val_types) == 1:
            t = list(val_types)[0]
            if t == int:
                base_v_type = "int"
            elif t == float:
                base_v_type = "f64"
            elif t == bool:
                base_v_type = "bool"
            elif t == str:
                base_v_type = "string"

        # Create a stable key for this literal combination
        sorted_values = sorted([str(v) for v in values])
        key = f"Literal_{base_v_type}_{'_'.join(sorted_values)}"

        if key in self._generated_literal_enums:
            return self._generated_literal_enums[key]

        # Generate unique name
        enum_name = f"LiteralEnum_{len(self._generated_literal_enums)}"

        # Build enum body and value mapping
        enum_lines = [f"pub enum {enum_name} {{"]
        val_map: Dict[Any, str] = {}
        used_member_names: Set[str] = set()

        for i, val in enumerate(values):
            member_name = str(val).lower().replace(' ', '_').replace('-', '_').replace('.', '_')
            if not member_name or not member_name[0].isalpha():
                member_name = f"val_{i}"

            base_member = member_name
            counter = 1
            while member_name in used_member_names:
                member_name = f"{base_member}_{counter}"
                counter += 1

            used_member_names.add(member_name)
            enum_lines.append(f"    {member_name}")
            val_map[val] = member_name

        enum_lines.append("}")
        self.emitter.add_struct("\n".join(enum_lines))

        # Add .str() method to the enum
        str_lines = [f"pub fn (e {enum_name}) str() string {{", "    match e {"]
        for val, member in val_map.items():
            if isinstance(val, bytes):
                hex_val = val.hex()
                str_lines.append(f"        .{member} {{ return '{hex_val}' }}")
            elif isinstance(val, (int, float, bool, str)):
                str_val = str(val)
                str_lines.append(f"        .{member} {{ return '{str_val}' }}")
            else:
                str_val = str(val)
                str_lines.append(f"        .{member} {{ return '{str_val}' }}")
        str_lines.append("    }")
        str_lines.append("}")
        self.emitter.add_struct("\n".join(str_lines))

        self._generated_literal_enums[key] = enum_name
        self._literal_enum_values[enum_name] = val_map
        return enum_name

    def _register_sum_type(self, v_union_type: str) -> str:
        """
        Normalizes a V union type, generates a named sum type if not already exists,
        and returns its name (including generic args if applicable).
        """
        parts = [p.strip() for p in v_union_type.split('|')]
        if len(parts) <= 1:
            return v_union_type

        parts.sort()
        normalized = " | ".join(parts)

        if normalized in self._generated_sum_types:
            return self._generated_sum_types[normalized]

        def clean(s: str) -> str:
            m = {
                'int': 'Int', 'string': 'String', 'bool': 'Bool', 'f64': 'F64',
                'i64': 'I64', 'u32': 'U32', 'u64': 'U64', 'i8': 'I8', 'i16': 'I16',
                'u8': 'U8', 'u16': 'U16', 'Any': 'Any', 'void': 'Void', 'none': 'None'
            }
            res = m.get(s, s).replace('[]', 'Array').replace('map', 'Map')
            return "".join(c for c in res if c.isalnum() or c == '_')

        type_name = "SumType_" + "".join(clean(p) for p in parts)

        # Avoid collisions
        base_name = type_name
        counter = 1
        while any(v == type_name for v in self._generated_sum_types.values()):
            type_name = f"{base_name}_{counter}"
            counter += 1

        # Identify active generics used in the union
        active_v_generics = self._get_all_active_v_generics()
        used_generics = [
            g for g in active_v_generics
            if g in parts or any(f"[{g}]" in p for p in parts) or any(f"{g} " in p for p in parts)
        ]

        gen_decl = f"[{', '.join(used_generics)}]" if used_generics else ""
        gen_args = f"[{', '.join(used_generics)}]" if used_generics else ""

        pub = "pub " if self.config and getattr(self.config, 'include_all_symbols', False) else ""

        self.emitter.add_struct(f"{pub}type {type_name}{gen_decl} = {normalized}")

        result = f"{type_name}{gen_args}"
        self._generated_sum_types[normalized] = result
        return result
