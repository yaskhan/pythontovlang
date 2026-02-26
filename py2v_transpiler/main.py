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

def transpile_file(source_file: str, config: TranspilerConfig) -> bool:
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

    # 4. Translate
    translator = VNodeVisitor(analyzer)
    try:
        v_code_intermediate = translator.visit_Module(tree)
    except Exception as e:
        print(f"Translation error in {source_file}: {e}")
        # import traceback; traceback.print_exc()
        return False

    # 5. Output
    output_file = os.path.splitext(source_file)[0] + ".v"
    try:
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(v_code_intermediate)
        print(f"Success: {output_file}")
        return True
    except Exception as e:
        print(f"Error writing {output_file}: {e}")
        return False

def process_directory(path: str, config: TranspilerConfig, recursive: bool) -> None:
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith(".py"):
                full_path = os.path.join(root, file)
                transpile_file(full_path, config)

        if not recursive:
            break

def main():
    parser = argparse.ArgumentParser(description="Python to V Transpiler")
    parser.add_argument("path", help="Path to Python file or directory")
    parser.add_argument("--analyze-deps", action="store_true", help="Analyze dependencies (for directories)")
    parser.add_argument("--recursive", "-r", action="store_true", help="Recursively process directories")
    parser.add_argument("--no-mypy", action="store_true", help="Disable Mypy type analysis")

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

    config = TranspilerConfig(mypy_enabled=not args.no_mypy)

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
