import ast
import logging
import tokenize
import io
import token

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

    def parse(self, source: str) -> ast.AST:
        """Parses Python source code into an AST."""
        source = self._preprocess_t_strings(source)
        try:
            return ast.parse(source)
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
