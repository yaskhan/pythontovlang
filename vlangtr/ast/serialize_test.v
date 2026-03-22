module ast

fn test_serialize_simple() {
	source := 'x = 1\ndef f(y):\n    return y + 1\n'
	filename := 'test.py'
	
	mut l := new_lexer(source, filename)
	mut p := new_parser(l)
	mod := p.parse_module()
	
	mut s := Serializer.new()
	bytes := s.serialize_module(mod)
	
	assert bytes.len > 0
}
