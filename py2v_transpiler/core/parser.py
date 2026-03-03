import ast
import logging
import tokenize
import io
import token
import re

logger = logging.getLogger(__name__)

class PyASTParser:
    def _preprocess_t_strings(self, source: str) -> str:
        """
        Preprocesses Python source to support PEP 750 t-strings.
        Replaces 't' and 'T' string prefixes with 'f' and 'F' so that they
        are parsed as JoinedStr (f-strings) which can be transpiled natively
        using V's string interpolation.
        """
        try:
            tokens = list(tokenize.tokenize(io.BytesIO(source.encode('utf-8')).readline))
        except tokenize.TokenError:
            return source

        new_tokens = []
        i = 0
        while i < len(tokens):
            tok = tokens[i]
            if tok.type == token.NAME and tok.string.lower() in ('t', 'tr', 'rt'):
                next_tok = tokens[i+1] if i+1 < len(tokens) else None
                if next_tok and next_tok.type == token.STRING and next_tok.start == tok.end:
                    prefix_str = tok.string.lower().replace('t', 'f')

                    tok_start = tokenize.TokenInfo(token.NAME, 'py2v_t_string', tok.start, tok.start, tok.line)
                    tok_lpar = tokenize.TokenInfo(token.OP, '(', tok.start, tok.start, tok.line)

                    new_str_val = prefix_str + next_tok.string
                    tok_f = tokenize.TokenInfo(token.STRING, new_str_val, tok.start, next_tok.end, tok.line)
                    tok_rpar = tokenize.TokenInfo(token.OP, ')', next_tok.end, next_tok.end, next_tok.line)

                    new_tokens.extend([tok_start, tok_lpar, tok_f, tok_rpar])
                    i += 2
                    continue
            new_tokens.append(tok)
            i += 1
        try:
            return tokenize.untokenize(new_tokens).decode('utf-8')
        except Exception:
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

    def parse(self, source: str) -> ast.AST:
        """Parses Python source code into an AST."""
        source = self._preprocess_t_strings(source)
        try:
            processed_source = self._preprocess_bracketless_except(source)
            return ast.parse(processed_source)
        except SyntaxError as e:
            logger.error(f"Syntax error: {e}")
            raise

    def parse_file(self, file_path: str) -> ast.AST:
        """Reads a file and parses its content into an AST."""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()
            return self.parse(source)
        except FileNotFoundError as e:
            logger.error(f"File not found: {e}")
            raise
        except SyntaxError:
            # Already logged in parse()
            raise
        except Exception as e:
            logger.error(f"Error reading or parsing file {file_path}: {e}")
            raise

    def dump_tree(self, tree: ast.AST) -> str:
        """Dumps the AST tree for debugging."""
        return ast.dump(tree, indent=4)
