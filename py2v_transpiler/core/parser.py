import ast
import logging
import re
from typing import Optional, Any
from .compatibility import CompatibilityLayer

logger = logging.getLogger(__name__)

class PyASTParser:
    def __init__(self, compatibility: Optional[CompatibilityLayer] = None, return_stub_lines: bool = False):
        self.compatibility = compatibility or CompatibilityLayer()
        self.return_stub_lines = return_stub_lines

    def parse(self, source: str, return_stub_lines: Optional[bool] = None) -> Any:
        """
        Parses Python source code into an AST.
        Returns a tuple of (ast_tree, stub_lines) if return_stub_lines is True,
        otherwise returns just the ast_tree.
        """
        if return_stub_lines is None:
            return_stub_lines = self.return_stub_lines
        try:
            processed_source, stub_lines = self.compatibility.preprocess_source(source)
            tree = ast.parse(processed_source)
            if return_stub_lines:
                return tree, stub_lines
            return tree
        except SyntaxError as e:
            logger.error(f"Syntax error: {e}")
            raise

    def parse_file(self, file_path: str, return_stub_lines: Optional[bool] = None) -> Any:
        """
        Reads a file and parses its content into an AST.
        Returns a tuple of (ast_tree, stub_lines) if return_stub_lines is True,
        otherwise returns just the ast_tree.
        """
        if return_stub_lines is None:
            return_stub_lines = self.return_stub_lines
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                source = f.read()
            return self.parse(source, return_stub_lines=return_stub_lines)
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
