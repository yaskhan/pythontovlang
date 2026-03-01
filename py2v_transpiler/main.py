
import sys
import os
import argparse
import ast
from typing import List
from py2v_transpiler.config import TranspilerConfig
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.dependencies import DependencyAnalyzer

class Transpiler:
    def transpile(self, source_code: str) -> str:
        parser = PyASTParser()
        tree = parser.parse(source_code)

        if not isinstance(tree, ast.Module):
            raise ValueError("Expected a valid Python module")

        analyzer = TypeInference()
        # Enable basic type inference for test strings
        analyzer.visit(tree)

        translator = VNodeVisitor(analyzer)
        return translator.visit_Module(tree)

from py2v_transpiler.core.generator import VCodeEmitter

class GlobalHelpers:
    def __init__(self):
        self.imports: List[str] = []
        self.structs: List[str] = []
        self.functions: List[str] = []

    def merge(self, translator):
        self.imports.extend(translator.emitter.get_helper_imports())
        self.structs.extend(translator.emitter.get_helper_structs())
        self.functions.extend(translator.emitter.get_helper_functions())

    def write(self, path: str):
        v_code_helpers = VCodeEmitter.emit_global_helpers(self.imports, self.structs, self.functions)
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(v_code_helpers)
            print(f"Generated global helpers: {path}")
        except Exception as e:
            print(f"Error writing global helpers to {path}: {e}")

def transpile_file(source_file: str, config: TranspilerConfig, global_helpers: GlobalHelpers = None) -> bool:
    print(f"Transpiling {source_file}...")

    # 1. Read source
    try:
        with open(source_file, "r", encoding="utf-8") as f:
            source_code = f.read()
    except Exception as e:
        print(f"Error reading {source_file}: {e}")
        return False

    # 2. Parse AST
    parser = PyASTParser()
    try:
        tree = parser.parse(source_code)
        if not isinstance(tree, ast.Module):
            print(f"Error: {source_file} must be a valid Python module.")
            return False
    except SyntaxError as e:
        print(f"Syntax error in {source_file}: {e}")
        return False

    # 3. Analyze types
    analyzer = TypeInference()
    if config.mypy_enabled:
        analyzer.run_mypy(source_file)

    # Run basic AST visitor for type inference regardless of mypy
    analyzer.visit(tree)

    if config.warn_dynamic:
        for key, v_type in analyzer.type_map.items():
            if v_type == "Any":
                if "@" in key:
                    fullname, loc = key.split("@", 1)
                    print(f"Warning: Dynamic 'Any' type fallback at {source_file}:{loc} for '{fullname}'")
                else:
                    print(f"Warning: Dynamic 'Any' type fallback for variable '{key}' in {source_file}")

    # 4. Translate
    translator = VNodeVisitor(analyzer)
    try:
        v_code_intermediate = translator.visit_Module(tree)
        if global_helpers is not None:
            global_helpers.merge(translator)
        else:
            v_code_helpers = translator.emitter.emit_helpers()
    except Exception as e:
        print(f"Translation error in {source_file}: {e}")
        # import traceback; traceback.print_exc()
        return False

    # 5. Output
    output_file = os.path.splitext(source_file)[0] + ".v"
    output_dir = os.path.dirname(output_file)

    try:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(v_code_intermediate)

        if global_helpers is None:
            # Standalone mode: write a helpers file specific to this script
            base_name = os.path.basename(source_file).split('.')[0]
            helpers_file = os.path.join(output_dir, f"{base_name}_helpers.v")
            with open(helpers_file, "w", encoding="utf-8") as f:
                f.write(v_code_helpers)
            print(f"Success: {output_file} (and {helpers_file})")
        else:
            print(f"Success: {output_file}")

        return True
    except Exception as e:
        print(f"Error writing {output_file}: {e}")
        return False

def process_directory(path: str, config: TranspilerConfig, recursive: bool) -> None:
    global_helpers = GlobalHelpers()

    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith(".py"):
                full_path = os.path.join(root, file)
                transpile_file(full_path, config, global_helpers)

        if not recursive:
            break

    helpers_file = os.path.join(path, "py2v_helpers.v")
    global_helpers.write(helpers_file)

def main():
    parser = argparse.ArgumentParser(description="Python to V Transpiler")
    parser.add_argument("path", help="Path to Python file or directory")
    parser.add_argument("--analyze-deps", action="store_true", help="Analyze dependencies (for directories)")
    parser.add_argument("--recursive", "-r", action="store_true", help="Recursively process directories")
    parser.add_argument("--no-mypy", action="store_true", help="Disable Mypy type analysis")
    parser.add_argument("--warn-dynamic", action="store_true", help="Warn when falling back to dynamic Any type")

    args = parser.parse_args()

    path = args.path
    if not os.path.exists(path):
        print(f"Error: Path '{path}' not found.")
        sys.exit(1)

    if args.analyze_deps:
        if not os.path.isdir(path):
             print("Error: --analyze-deps requires a directory.")
             sys.exit(1)

        analyzer = DependencyAnalyzer()
        print(f"Analyzing dependencies for: {path}")
        graph = analyzer.analyze_project(path)

        for file, deps in graph.items():
            print(f"{file}: {', '.join(deps) if deps else 'No imports'}")
        return

    config = TranspilerConfig(mypy_enabled=not args.no_mypy, warn_dynamic=args.warn_dynamic)

    if os.path.isfile(path):
        if not path.endswith(".py"):
            print("Error: Input file must be a Python script (.py)")
            sys.exit(1)
        transpile_file(path, config)
    elif os.path.isdir(path):
        process_directory(path, config, args.recursive)
    else:
        print("Error: Invalid path type.")
        sys.exit(1)

if __name__ == "__main__":
    main()
