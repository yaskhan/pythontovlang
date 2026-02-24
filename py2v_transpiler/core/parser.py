import ast
import logging

logger = logging.getLogger(__name__)

class PyASTParser:
    def parse(self, source: str) -> ast.AST:
        """Parses Python source code into an AST."""
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
