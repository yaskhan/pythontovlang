import ast

class PyASTParser:
    def parse(self, source: str) -> ast.AST:
        """Parses Python source code into an AST."""
        try:
            return ast.parse(source)
        except SyntaxError as e:
            print(f"Syntax error: {e}")
            raise

    def dump_tree(self, tree: ast.AST) -> str:
        """Dumps the AST tree for debugging."""
        return ast.dump(tree, indent=4)
