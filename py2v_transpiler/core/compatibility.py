import re
from typing import Set, List, Any, Optional

class CompatibilityLayer:
    """
    Handles Python version-specific syntax changes and soft keywords
    to ensure forward compatibility.
    """

    # V lang reserved keywords that should be sanitized if used as identifiers in Python
    V_RESERVED_KEYWORDS: Set[str] = {
        "fn", "type", "struct", "mut", "if", "else", "for", "return", "match",
        "interface", "enum", "pub", "import", "module", "const", "unsafe",
        "defer", "go", "chan", "shared", "spawn", "assert", "sizeof", "typeof",
        "__global", "as", "in", "is", "none", "map", "array", "string", "bool", "Any"
    }

    # Python soft keywords that may require special handling
    PYTHON_SOFT_KEYWORDS: Set[str] = {
        "match", "case", "type", "soft"
    }

    def is_v_reserved(self, name: str) -> bool:
        """Checks if a name is a reserved keyword in V."""
        return name in self.V_RESERVED_KEYWORDS

    def is_python_soft_keyword(self, name: str) -> bool:
        """Checks if a name is a Python soft keyword."""
        return name in self.PYTHON_SOFT_KEYWORDS

    def preprocess_source(self, source: str) -> tuple[str, dict[tuple[int, int], str]]:
        """
        Applies a series of pre-processing transformations to the Python source
        to support newer or future syntax on older Python versions.
        Returns (modified_source, variance_map).
        """
        source = self._preprocess_bracketless_except(source)
        source, variance_map = self._preprocess_pep695_variance(source)
        return source, variance_map

    def _preprocess_pep695_variance(self, source: str) -> tuple[str, dict[tuple[int, int], str]]:
        """
        Pre-processes PEP 695 type parameter lists to remove variance modifiers
        (+T, -T) so that ast.parse can handle them on Python 3.12.
        Records the variance in a map keyed by (line_no, col_offset).
        Supports multi-line headers and async def.
        """
        # Refined regex finding to support multi-line and more robustly capture headers
        header_re = re.compile(r'(?P<indent>^\s*)(?P<kind>(async\s+)?def|class|type)\s+(?P<name>\w+)\s*\[', re.MULTILINE)

        variance_map = {}
        modifications = [] # list of (offset, sign)

        for match in header_re.finditer(source):
            start_bracket_idx = match.end() - 1

            # Bracket counting for multi-line support
            bracket_level = 0
            end_bracket_idx = -1
            for j in range(start_bracket_idx, len(source)):
                if source[j] == '[':
                    bracket_level += 1
                elif source[j] == ']':
                    bracket_level -= 1
                    if bracket_level == 0:
                        end_bracket_idx = j
                        break

            if end_bracket_idx == -1:
                continue

            segment = source[start_bracket_idx:end_bracket_idx+1]
            param_re = re.compile(r'(?P<sign>[+-])(?P<param>\w+)')

            for p_match in param_re.finditer(segment):
                sign = p_match.group('sign')
                abs_offset = start_bracket_idx + p_match.start()

                # Calculate line and column
                prefix = source[:abs_offset]
                lineno = prefix.count('\n') + 1
                last_newline = prefix.rfind('\n')
                col_offset = (abs_offset - last_newline - 1) if last_newline != -1 else abs_offset

                # Name offset is one after the sign
                variance_map[(lineno, col_offset + 1)] = sign
                modifications.append(abs_offset)

        # Apply modifications
        source_list = list(source)
        for offset in modifications:
            source_list[offset] = ' '

        return "".join(source_list), variance_map

    def _preprocess_bracketless_except(self, source: str) -> str:
        """
        Pre-processes Python source code to wrap bracketless multi-exception clauses
        in parentheses before AST parsing, to support PEP 758 syntax (Python 3.14).
        For example: `except ValueError, TypeError:` becomes `except (ValueError, TypeError):`.
        """
        lines = source.split('\n')
        for i, line in enumerate(lines):
            if 'except' not in line:
                continue

            # Match `except` or `except*`, capturing leading whitespace
            m = re.match(r"^(\s*)(except\*?\s+)(.+?):(.*)$", line)
            if m:
                indent, except_kwd, rest, after_colon = m.groups()
                rest_stripped = rest.strip()

                # Skip empty excepts `except:` or already parenthesized `except (A, B):`
                if not rest_stripped or rest_stripped.startswith('('):
                    continue

                # Check for multiple exceptions separated by commas
                if ',' in rest_stripped:
                    # Handle optional `as alias`
                    parts = rest_stripped.rsplit(' as ', 1)
                    exc_list = parts[0].strip()
                    as_clause = f" as {parts[1].strip()}" if len(parts) > 1 else ""

                    lines[i] = f"{indent}{except_kwd}({exc_list}){as_clause}:{after_colon}"

        return '\n'.join(lines)
