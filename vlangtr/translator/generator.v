module translator

// generator.v mirrors core/generator.py and forwards to VCodeEmitter.

pub fn new_generator_emitter(module_name string) VCodeEmitter {
	return new_vcode_emitter(module_name)
}

pub fn (e &VCodeEmitter) generator_get_helper_imports() []string {
	return e.helper_imports.clone()
}

pub fn (e &VCodeEmitter) generator_get_helper_structs() []string {
	return e.helper_structs.clone()
}

pub fn (e &VCodeEmitter) generator_get_helper_functions() []string {
	return e.helper_functions.clone()
}

pub fn (e &VCodeEmitter) generator_emit() string {
	return e.emit()
}

pub fn (e &VCodeEmitter) generator_emit_helpers() string {
	return e.emit_helpers()
}

pub fn generator_emit_global_helpers(imports []string, structs []string, functions []string, module_name string) string {
	return VCodeEmitter.emit_global_helpers(imports, structs, functions, module_name)
}

pub fn (mut e VCodeEmitter) generator_add_import(module_name string) {
	e.add_import(module_name)
}

pub fn (mut e VCodeEmitter) generator_add_helper_import(module_name string) {
	e.add_helper_import(module_name)
}

pub fn (mut e VCodeEmitter) generator_add_global(global_def string) {
	e.add_global(global_def)
}

pub fn (mut e VCodeEmitter) generator_add_constant(const_def string) {
	e.add_constant(const_def)
}

pub fn (mut e VCodeEmitter) generator_add_struct(struct_def string) {
	e.add_struct(struct_def)
}

pub fn (mut e VCodeEmitter) generator_add_helper_struct(struct_def string) {
	e.add_helper_struct(struct_def)
}

pub fn (mut e VCodeEmitter) generator_add_function(func_def string) {
	e.add_function(func_def)
}

pub fn (mut e VCodeEmitter) generator_add_helper_function(func_def string) {
	e.add_helper_function(func_def)
}

pub fn (mut e VCodeEmitter) generator_add_init_statement(stmt string) {
	e.add_init_statement(stmt)
}

pub fn (mut e VCodeEmitter) generator_add_main_statement(stmt string) {
	e.add_main_statement(stmt)
}
