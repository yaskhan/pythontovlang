import sys
import os
from py2v_transpiler.config import TranspilerConfig
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.analyzer import TypeInference
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.generator import VCodeEmitter
from py2v_transpiler.core.dependencies import DependencyAnalyzer

def main():
    if len(sys.argv) < 2:
        print("Usage: python -m py2v_transpiler.main <file.py> OR --analyze-deps <project_root>")
        return

    if sys.argv[1] == "--analyze-deps":
        if len(sys.argv) < 3:
            print("Usage: python -m py2v_transpiler.main --analyze-deps <project_root>")
            return

        project_root = sys.argv[2]
        if not os.path.exists(project_root):
            print(f"Error: Directory '{project_root}' not found.")
            return

        analyzer = DependencyAnalyzer()
        print(f"Analyzing dependencies for: {project_root}")
        graph = analyzer.analyze_project(project_root)

        for file, deps in graph.items():
            print(f"{file}: {', '.join(deps) if deps else 'No imports'}")
        return

    source_file = sys.argv[1]
    if not os.path.exists(source_file):
        print(f"Error: File '{source_file}' not found.")
        return

    config = TranspilerConfig()

    # 1. Read source
    with open(source_file, "r") as f:
        source_code = f.read()

    # 2. Parse AST
    parser = PyASTParser()
    try:
        tree = parser.parse(source_code)
    except SyntaxError:
        return

    # 3. Analyze types
    analyzer = TypeInference()
    if config.mypy_enabled:
        analyzer.run_mypy(source_file)

    # 4. Translate
    translator = VNodeVisitor(analyzer)
    v_code_intermediate = translator.visit_Module(tree)

    # 5. Generate Code
    generator = VCodeEmitter()
    final_code = generator.emit_module(v_code_intermediate)

    # 6. Output
    output_file = os.path.splitext(source_file)[0] + ".v"
    with open(output_file, "w") as f:
        f.write(final_code)

    print(f"Transpilation successful. Output written to {output_file}")

if __name__ == "__main__":
    main()
