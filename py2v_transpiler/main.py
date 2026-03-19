
import sys
import os
import argparse
import ast
from typing import List, Optional, Set
from py2v_transpiler.config import TranspilerConfig
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.dependencies import DependencyAnalyzer
from py2v_transpiler.core.mypy_tips import get_mypy_tips

class Transpiler:
    def transpile(self, source_code: str) -> str:
        parser = PyASTParser()
        tree = parser.parse(source_code)

        if not isinstance(tree, ast.Module):
            raise ValueError("Expected a valid Python module")

        analyzer = TypeInference()
        # Enable basic type inference for test strings
        analyzer.analyze(tree)

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

def generate_all_helpers(output_path: str) -> None:
    analyzer = TypeInference()
    translator = VNodeVisitor(analyzer)

    # Force all flags to True to generate every possible helper
    translator.used_complex = True
    translator.used_string_format = True
    translator.used_list_concat = True
    translator.used_dict_merge = True

    translator.used_builtins = {"sorted", "reversed", "round", "py_subscript", "py_slice", "py_repr", "py_ascii", "py_format"}

    modules = [
        "tempfile", "logging", "argparse", "pathlib", "collections",
        "itertools", "functools", "operator", "threading", "socket", "http.client",
        "csv", "sqlite3", "subprocess", "platform", "hashlib", "urllib.parse",
        "struct", "array", "fractions", "statistics", "decimal", "pickle", "zlib", "gzip", "copy"
    ]

    for i, mod in enumerate(modules):
        translator.imported_modules[f"fake{i}"] = mod

    # Trigger AST visit to inject all helpers
    translator.visit_Module(ast.parse("pass"))

    helpers_code = translator.emitter.emit_helpers()

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(helpers_code)
        print(f"Success: generated global helper library at {output_path}")
    except Exception as e:
        print(f"Error writing global helpers to {output_path}: {e}")


def transpile_file(source_file: str, config: TranspilerConfig, global_helpers: Optional[GlobalHelpers] = None, current_module: str = "main", scc_files: Optional[Set[str]] = None, output_path: Optional[str] = None) -> bool:
    print(f"Transpiling {source_file} (module: {current_module})...")

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
        stdout, stderr, exit_code = analyzer.run_mypy(source_file, experimental=config.experimental)
        if exit_code != 0:
            print(f"Mypy found errors in {source_file}:")
            print(stdout)
            if stderr:
                print(stderr, file=sys.stderr)
            tips = get_mypy_tips(stdout)
            if tips:
                print(tips)

    # Run basic AST visitor for type inference regardless of mypy
    analyzer.analyze(tree)
    
    if hasattr(analyzer, 'raw_type_map'):
        import json
        with open("raw_type_map_debug.json", "w", encoding="utf-8") as f:
            json.dump(analyzer.raw_type_map, f, indent=4)

    if config.warn_dynamic:
        for key, v_type in analyzer.type_map.items():
            if v_type == "Any":
                if "@" in key:
                    fullname, loc = key.split("@", 1)
                    print(f"Warning: Dynamic 'Any' type fallback at {source_file}:{loc} for '{fullname}'")
                else:
                    print(f"Warning: Dynamic 'Any' type fallback for variable '{key}' in {source_file}")

    # 4. Translate
    translator = VNodeVisitor(analyzer, config=config)
    translator.current_module_name = current_module
    # Use the same relative path key as SCC for consistent prefixing
    # Actually, we need the path relative to project root
    # source_file is absolute or relative to cwd.
    # In process_directory, f is relative to path.
    # Let's pass the relative path explicitly if available
    translator.current_file_name = getattr(config, 'rel_path', os.path.basename(source_file))

    if scc_files:
        translator.scc_files = scc_files

    try:
        v_code_intermediate = translator.visit_Module(tree)

        # Print warnings
        for warning in getattr(translator, 'warnings', []):
            print(f"Warning: {warning}")

        if not config.no_helpers:
            if global_helpers is not None:
                global_helpers.merge(translator)
            else:
                v_code_helpers = translator.emitter.emit_helpers()
    except Exception as e:
        print(f"Translation error in {source_file}: {e}")
        import traceback; traceback.print_exc()
        return False

    # 5. Output
    if output_path:
        output_file = output_path
    else:
        output_file = os.path.splitext(source_file)[0] + ".v"
    output_dir = os.path.dirname(output_file)

    try:
        if not config.helpers_only:
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(v_code_intermediate)

        if global_helpers is None:
            # Standalone mode: write a helpers file specific to this script
            if not config.no_helpers:
                base_name = os.path.basename(source_file).split('.')[0]
                helpers_file = os.path.join(output_dir, f"{base_name}_helpers.v")
                with open(helpers_file, "w", encoding="utf-8") as f:
                    f.write(v_code_helpers)

                if not config.helpers_only:
                    print(f"Success: {output_file} (and {helpers_file})")
                else:
                    print(f"Success: generated {helpers_file}")
            else:
                print(f"Success: {output_file}")
        else:
            # In directory processing mode, we defer helpers writing to the caller.
            # But we should respect `--no-helpers` by not merging.
            if config.no_helpers:
                pass # Already skipped merging effectively, or actually we merged it above. Wait, if config.no_helpers we shouldn't merge. Let's fix above too!

            if not config.helpers_only:
                print(f"Success: {output_file}")

        return True
    except Exception as e:
        print(f"Error writing {output_file}: {e}")
        return False

def process_directory(path: str, config: TranspilerConfig, recursive: bool) -> None:
    analyzer = DependencyAnalyzer()
    sccs = analyzer.find_sccs(path, recursive=recursive)

    # Map file path to its SCC
    file_to_scc = {}
    for scc in sccs:
        for f in scc:
            file_to_scc[f] = scc

    # Identify SCCs that span multiple directories and decide on their consolidation
    scc_to_dir = {}
    scc_to_module = {}
    for scc_set in sccs:
        scc_list: list[str] = list(scc_set)
        if len(scc_list) > 1:
            # Consolidation directory for the SCC
            first_file = scc_list[0]
            scc_dir = os.path.dirname(os.path.join(path, first_file))
            scc_to_dir[id(scc_set)] = scc_dir
            # If multi-file SCC, use directory name as module
            scc_to_module[id(scc_set)] = os.path.basename(scc_dir) if os.path.basename(scc_dir) else "models"
        else:
            scc_dir = os.path.dirname(os.path.join(path, scc_list[0]))
            scc_to_dir[id(scc_set)] = scc_dir
            scc_to_module[id(scc_set)] = "main"

    # Group files by their final destination directory
    final_dir_to_files: dict[str, list[str]] = {}
    for f, scc_set in file_to_scc.items():
        d = scc_to_dir[id(scc_set)]
        if d not in final_dir_to_files:
            final_dir_to_files[d] = []
        final_dir_to_files[d].append(f)

    # Within each directory, ensure ALL files share the same module name
    for d, files in final_dir_to_files.items():
        global_helpers = GlobalHelpers()
        processed_files = 0

        # Determine a consistent module name for this directory.
        # If any file in the directory belongs to a multi-file SCC,
        # use the module name associated with that SCC for the whole directory.
        # Otherwise, use "main".
        current_module = "main"
        for f in files:
            scc = file_to_scc[f]
            if len(scc) > 1:
                current_module = scc_to_module[id(scc)]
                break

        for f in files:
            full_path = os.path.join(path, f)
            scc = file_to_scc[f]

            # Ensure the output file is in the consolidated directory
            base = os.path.basename(f)
            if base.endswith('.pyi'):
                out_name = base[:-4] + '.v'
            else:
                out_name = base[:-3] + '.v'
            output_path = os.path.join(d, out_name)

            # Temporarily attach relative path to config for translator
            config.rel_path = f # type: ignore

            if transpile_file(full_path, config, global_helpers, current_module=current_module, scc_files=scc, output_path=output_path):
                processed_files += 1

        if processed_files > 0 and not config.no_helpers:
            helpers_file = os.path.join(d, "py2v_helpers.v")
            # Ensure helpers use the same module name
            v_code_helpers = VCodeEmitter.emit_global_helpers(global_helpers.imports, global_helpers.structs, global_helpers.functions, module_name=current_module)
            try:
                with open(helpers_file, "w", encoding="utf-8") as f_out:
                    f_out.write(v_code_helpers)
                print(f"Generated global helpers: {helpers_file}")
            except Exception as e:
                print(f"Error writing global helpers to {helpers_file}: {e}")

def print_banner():
    """Print a nice banner and usage information when py2v is run without arguments."""
    banner = """
=================================================================
                    Py2V Transpiler
              Python to V Language Compiler
=================================================================

Usage: py2v <path> [options]

Arguments:
  path                  Path to Python file (.py/.pyi) or directory

Options:
  -r, --recursive       Recursively process directories
  --analyze-deps        Analyze dependencies (for directories)
  --no-mypy             Disable Mypy type analysis
  --warn-dynamic        Warn when falling back to dynamic Any type
  --no-helpers          Do not generate a helper V file
  --helpers-only        Only generate the helper V file
  --include-all-symbols Include all symbols (not just __all__)
  --strict-exports      Warn about symbols missing from __all__
  -h, --help            Show this help message

Examples:
  py2v script.py                    # Transpile a single file
  py2v src/ -r                      # Transpile all files in directory
  py2v mylib/ --no-mypy             # Transpile without Mypy checks
  py2v project/ --helpers-only      # Generate only helpers file

Quick Start:
  py2v your_script.py
=================================================================
"""
    print(banner)


def main():
    # If no arguments provided, show banner and exit
    if len(sys.argv) == 1:
        print_banner()
        sys.exit(0)

    parser = argparse.ArgumentParser(
        description="Python to V Transpiler",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  py2v script.py                    # Transpile a single file
  py2v src/ -r                      # Transpile all files in directory
  py2v mylib/ --no-mypy             # Transpile without Mypy checks
  py2v project/ --helpers-only      # Generate only helpers file
        """
    )
    parser.add_argument("path", help="Path to Python file or directory")
    parser.add_argument("--analyze-deps", action="store_true", help="Analyze dependencies (for directories)")
    parser.add_argument("--recursive", "-r", action="store_true", help="Recursively process directories")
    parser.add_argument("--no-mypy", action="store_true", help="Disable Mypy type analysis")
    parser.add_argument("--warn-dynamic", action="store_true", help="Warn when falling back to dynamic Any type")
    parser.add_argument("--no-helpers", action="store_true", help="Do not generate a helper V file")
    parser.add_argument("--helpers-only", action="store_true", help="Only generate the helper V file (do not transpile individual scripts)")
    parser.add_argument("--include-all-symbols", action="store_true", help="Include all symbols even if not in __all__")
    parser.add_argument("--strict-exports", action="store_true", help="Warn about public symbols missing from __all__")
    parser.add_argument("--experimental", action="store_true", help="Enable experimental PEP features")

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

    config = TranspilerConfig(
        mypy_enabled=not args.no_mypy,
        warn_dynamic=args.warn_dynamic,
        no_helpers=args.no_helpers,
        helpers_only=args.helpers_only,
        include_all_symbols=args.include_all_symbols,
        strict_export_mode=args.strict_exports,
        experimental=args.experimental
    )

    if config.helpers_only:
        output_dir = path if os.path.isdir(path) else os.path.dirname(path)
        if not output_dir:
            output_dir = "."
        output_path = os.path.join(output_dir, "py2v_helpers.v")
        generate_all_helpers(output_path)
        return

    if os.path.isfile(path):
        if not (path.endswith(".py") or path.endswith(".pyi")):
            print("Error: Input file must be a Python script (.py or .pyi)")
            sys.exit(1)
        transpile_file(path, config)
    elif os.path.isdir(path):
        process_directory(path, config, args.recursive)
    else:
        print("Error: Invalid path type.")
        sys.exit(1)

if __name__ == "__main__":
    main()
