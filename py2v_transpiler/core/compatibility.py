import re
from typing import Set, List

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

    def preprocess_source(self, source: str) -> str:
        """
        Applies a series of pre-processing transformations to the Python source
        to support newer or future syntax on older Python versions.
        """
        source = self._preprocess_bracketless_except(source)
        # Add more future pre-processors here
        return source

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
