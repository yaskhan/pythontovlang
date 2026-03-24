import re
import sys
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

    # Pre-compiled regex patterns for performance optimization
    _T_STRING_PREFIX_RE = re.compile(r'(^|[\s=([{},:!|&])(rt|tr|t)(["\']{1,3})', re.IGNORECASE)
    _GENERIC_PATTERN_RE = re.compile(r'(\b[\w\.]+)\[([^\[\]]+)\]')
    _CASE_STMT_RE = re.compile(r'^(\s*)case\s+(.*)')
    _EXCEPT_STMT_RE = re.compile(r"^(\s*)(except\*?\s+)(.*)$")

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
        # We ensure it's at the start of an expression or preceded by whitespace/delimiters.
        # This avoids matching things like path-t" or filename.tr" inside labels or strings.
        def replace_t_prefix(match):
            prefix = match.group(2).lower()
            quotes = match.group(3)
            leading = match.group(1)
            if 'r' in prefix:
                return f'{leading}rf{quotes}__py2v_t__'
            else:
                return f'{leading}f{quotes}__py2v_t__'

        return self._T_STRING_PREFIX_RE.sub(replace_t_prefix, source)

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
                temp = self._GENERIC_PATTERN_RE.sub(mangle_callback, new_text)
                if temp == new_text:
                    break
                new_text = temp
            return new_text

        result = []
        lines = source.split('\n')
        i = 0
        while i < len(lines):
            line = lines[i]
            case_match = self._CASE_STMT_RE.match(line)
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

        Also handles `except*` syntax on Python versions < 3.11 by converting it to `except`.
        """
        lines = source.split('\n')
        result: List[str] = []
        i = 0

        while i < len(lines):
            line = lines[i]
            header_match = self._EXCEPT_STMT_RE.match(line)
            if not header_match:
                result.append(line)
                i += 1
                continue

            indent, except_kwd, rest = header_match.groups()
            header_parts = [rest]
            j = i

            while self._find_header_colon('\n'.join(header_parts)) == -1 and j + 1 < len(lines):
                j += 1
                header_parts.append(lines[j])

            full_header = '\n'.join(header_parts)
            colon_index = self._find_header_colon(full_header)
            if colon_index == -1:
                result.append(line)
                i += 1
                continue

            clause = full_header[:colon_index]
            suffix = full_header[colon_index + 1:]

            # Map except* to except on Python < 3.11
            if except_kwd.strip().endswith('*') and sys.version_info < (3, 11):
                except_kwd = f"{indent}except "

            rewritten_clause = self._wrap_bracketless_except_clause(clause)
            rewritten_lines = f"{indent}{except_kwd.strip()} {rewritten_clause}:{suffix}".split('\n')
            result.extend(rewritten_lines)
            i = j + 1

        return '\n'.join(result)

    def _find_header_colon(self, text: str) -> int:
        """Finds the colon that terminates an except header, ignoring nested brackets."""
        depth = 0
        for index, char in enumerate(text):
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth = max(0, depth - 1)
            elif char == ':' and depth == 0:
                return index
        return -1

    def _wrap_bracketless_except_clause(self, clause: str) -> str:
        """Wraps a multi-exception except clause in parentheses when needed."""
        stripped = clause.strip()
        if not stripped or stripped.startswith('('):
            return clause

        head, as_clause = self._split_except_alias(clause)
        if not self._has_top_level_comma(head):
            return clause

        return f"({head.strip()}){as_clause}"

    def _split_except_alias(self, clause: str) -> tuple[str, str]:
        """Splits `ValueError, TypeError as e` into exception list and alias suffix."""
        depth = 0
        idx = 0
        while idx < len(clause):
            char = clause[idx]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth = max(0, depth - 1)
            elif depth == 0 and clause[idx:idx + 4] == " as ":
                return clause[:idx], clause[idx:]
            idx += 1
        return clause, ""

    def _has_top_level_comma(self, text: str) -> bool:
        """Returns True when the clause contains a comma outside nested brackets."""
        depth = 0
        for char in text:
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth = max(0, depth - 1)
            elif char == ',' and depth == 0:
                return True
        return False
