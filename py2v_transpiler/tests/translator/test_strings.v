module main

pub fn test_translator_f_string_simple() {
    mut parser := py2v_transpiler.core.parser.PyASTParser()
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut translator := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := 'f\'value: {x}\''
    mut tree := parser.parse(code)
    analyzer.analyze(tree)
    mut result := translator.visit_Module(tree)
    assert '\'value: ${x}\'' in result
}
pub fn test_translator_f_string_expression() {
    mut parser := py2v_transpiler.core.parser.PyASTParser()
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut translator := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := 'f\'{x + 1}\''
    mut tree := parser.parse(code)
    analyzer.analyze(tree)
    mut result := translator.visit_Module(tree)
    assert '\'${x + 1}\'' in result
}
pub fn test_translator_f_string_mixed() {
    mut parser := py2v_transpiler.core.parser.PyASTParser()
    mut analyzer := py2v_transpiler.core.analyzer.TypeInference()
    mut translator := py2v_transpiler.core.translator.VNodeVisitor(analyzer)
    mut code := 'f\'a={a}, b={b}\''
    mut tree := parser.parse(code)
    analyzer.analyze(tree)
    mut result := translator.visit_Module(tree)
    assert '\'a=${a}, b=${b}\'' in result
}
