module translator

import ast

pub struct Translator {
pub mut:
	// Add fields as needed, e.g. emitter, type_checker
}

pub fn new_translator() &Translator {
	return &Translator{}
}

pub fn (mut t Translator) translate(source string) string {
	mut l := ast.new_lexer(source, 'test.py')
	mut p := ast.new_parser(l)
	m := p.parse_module()
	
	// For now, return empty or a stub. 
	// Later this will use a visitor to generate code.
	_ = m
	return ''
}
