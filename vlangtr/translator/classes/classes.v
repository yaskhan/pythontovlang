module classes

import ast
import analyzer
import base

pub struct ClassesModule {
pub mut:
	class_definition_handler ClassDefinitionHandler
	class_decorator_handler  ClassDecoratorHandler
	class_fields_handler     ClassFieldsHandler
	class_bases_handler      ClassBasesHandler
	class_methods_handler    ClassMethodsHandler
	special_classes_handler   SpecialClassesHandler
	pydantic_handler         ClassPydanticHandler
}

pub fn new_classes_module() ClassesModule {
	return ClassesModule{
		class_definition_handler: ClassDefinitionHandler{}
		class_decorator_handler:  ClassDecoratorHandler{}
		class_fields_handler:     ClassFieldsHandler{}
		class_bases_handler:      ClassBasesHandler{}
		class_methods_handler:    ClassMethodsHandler{}
		special_classes_handler:   SpecialClassesHandler{}
		pydantic_handler:         ClassPydanticHandler{}
	}
}

pub struct ClassVisitEnv {
pub mut:
	state            &base.TranslatorState
	analyzer         analyzer.Analyzer
	visit_stmt_fn    fn (ast.Statement) = unsafe { nil }
	visit_expr_fn    fn (ast.Expression) string = unsafe { nil }
	emit_struct_fn   fn (string) = unsafe { nil }
	emit_function_fn fn (string) = unsafe { nil }
	emit_constant_fn fn (string) = unsafe { nil }
	source_mapping   bool
}

pub fn new_class_visit_env(
	state &base.TranslatorState,
	analyzer_ref analyzer.Analyzer,
	visit_stmt_fn fn (ast.Statement),
	visit_expr_fn fn (ast.Expression) string,
	emit_struct_fn fn (string),
	emit_function_fn fn (string),
	emit_constant_fn fn (string),
	source_mapping bool,
) ClassVisitEnv {
	return ClassVisitEnv{
		state:            state
		analyzer:         analyzer_ref
		visit_stmt_fn:    visit_stmt_fn
		visit_expr_fn:    visit_expr_fn
		emit_struct_fn:   emit_struct_fn
		emit_function_fn: emit_function_fn
		emit_constant_fn: emit_constant_fn
		source_mapping:   source_mapping
	}
}

pub fn (mut m ClassesModule) visit_class_def(node &ast.ClassDef, mut env ClassVisitEnv) {
	m.class_definition_handler.visit_class_def(node, mut env, mut m)
}
