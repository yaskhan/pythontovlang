module parser

import os

import ast as pyast
import utils

pub struct PyASTParser {
pub mut:
	compatibility utils.CompatibilityLayer
}

pub fn new_py_ast_parser(compatibility ?utils.CompatibilityLayer) PyASTParser {
	mut layer := compatibility or { utils.new_compatibility_layer() }
	return PyASTParser{
		compatibility: layer
	}
}

pub fn (p PyASTParser) parse(source string) !pyast.Module {
	processed_source := p.compatibility.preprocess_source(source)
	mut lexer := pyast.new_lexer(processed_source, '<string>')
	mut ast_parser := pyast.new_parser(lexer)
	return ast_parser.parse_module()
}

pub fn (p PyASTParser) parse_file(file_path string) !pyast.Module {
	source := os.read_file(file_path) or { return error('File not found: ${file_path}') }
	return p.parse(source)
}

pub fn (p PyASTParser) dump_tree(tree pyast.Module) string {
	return 'Module(body=[${tree.body.len} statements])'
}
