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
        "__global", "as", "in", "is", "none", "map", "array", "string", "bool", "Any", "union"
    }

    # Python soft keywords that may require special handling
    PYTHON_SOFT_KEYWORDS: Set[str] = {
        "match", "case", "type", "soft"
    }

    def is_v_reserved(self, name: str) -> bool:
        """Checks if a name is a reserved keyword in V."""
        return name in self.V_RESERVED_KEYWORDS or name.lower() in self.V_RESERVED_KEYWORDS

    def is_python_soft_keyword(self, name: str) -> bool:
        """Checks if a name is a Python soft keyword."""
        return name in self.PYTHON_SOFT_KEYWORDS

    def preprocess_source(self, source: str) -> str:
        """
        Applies a series of pre-processing transformations to the Python source
        to support newer or future syntax on older Python versions.
        """
        source = self._preprocess_tstrings(source)
        source = self._preprocess_bracketless_except(source)
        source = self._preprocess_generic_match(source)
        # Add more future pre-processors here
        return source

    def _preprocess_tstrings(self, source: str) -> str:
        """
        Pre-processes Python source code to support PEP 750 t-strings on older Python versions.
        Converts t"..." to f"__py2v_t__..." to be parsed as f-strings but identifiable.
        Supports t, T, rt, tr prefixes and triple quotes.
        """
        def replace_prefix(match):
            prefix = match.group(1).lower()
            quotes = match.group(2)
            if 'r' in prefix:
                return f'rf{quotes}__py2v_t__'
            else:
                return f'f{quotes}__py2v_t__'

        # Matches t, T, rt, tr, etc. followed by ' or " or ''' or """
        # Only matches if prefix is immediately followed by quotes (no space)
        # We avoid matching 't' or 'T' inside strings by ensuring it's not preceded by a quote.
        # But since we use regex on the whole source, it's hard to be perfect without tokenizing.
        # However, PEP 750 t-strings must be at the start of a token.
        # Using a negative lookbehind for quotes might help.
        return re.sub(r'(?<![\'"])\b(rt|tr|t)(["\']{1,3})', replace_prefix, source, flags=re.IGNORECASE)

    def _preprocess_generic_match(self, source: str) -> str:
        """
        Pre-processes Python source code to mangle generic class patterns in match statements
        to be parsable by the standard ast module.
        Supports multi-line patterns, nested generics, and qualified names.
        Example: `case Box[int](value=v):` becomes `case Box__py2v_gen_L__int__py2v_gen_R__(value=v):`.
        """
        def mangle_recursive(text: str) -> str:
            def mangle_callback(match: re.Match) -> str:
                name, args = match.groups()
                # Replace remaining separators in this level
                mangled_args = args.replace(', ', '__py2v_gen_C__').replace(',', '__py2v_gen_C__').replace(' ', '')
                return f"{name}__py2v_gen_L__{mangled_args}__py2v_gen_R__"

            new_text = text
            while True:
                # Matches Word or pkg.Word followed by [Inner] where Inner doesn't contain [ or ]
                temp = re.sub(r'(\b[\w\.]+)\[([^\[\]]+)\]', mangle_callback, new_text)
                if temp == new_text:
                    break
                new_text = temp
            return new_text

        result = []
        lines = source.split('\n')
        i = 0
        while i < len(lines):
            line = lines[i]
            case_match = re.match(r'^(\s*)case\s+(.*)', line)
            if case_match:
                indent = case_match.group(1)
                content = case_match.group(2)

                # Find the colon ending the case pattern
                full_case_content = content
                j = i
                while ':' not in full_case_content and j + 1 < len(lines):
                    j += 1
                    full_case_content += '\n' + lines[j]

                if ':' in full_case_content:
                    # Split into pattern and rest
                    pattern_part, rest_part = full_case_content.split(':', 1)
                    mangled_pattern = mangle_recursive(pattern_part)

                    new_full_case = f"{indent}case {mangled_pattern}:{rest_part}"
                    new_lines = new_full_case.split('\n')
                    result.extend(new_lines)
                    i = j + 1
                    continue

            result.append(line)
            i += 1

        return '\n'.join(result)

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
