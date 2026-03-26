module translator

// generator.v mirrors core/generator.py and forwards to VCodeEmitter.

pub fn new_generator_emitter(module_name string) VCodeEmitter {
	return new_vcode_emitter(module_name)
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
