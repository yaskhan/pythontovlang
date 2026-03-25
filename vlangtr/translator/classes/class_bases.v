module classes

import ast

pub struct ClassBasesHandler {}

pub fn (h ClassBasesHandler) is_enum_type(name string, env &ClassVisitEnv) (bool, bool, bool) {
	_ = h
	_ = name
	_ = env
	return false, false, false
}

pub fn (h ClassBasesHandler) process_bases(node ast.ClassDef, struct_name string, mut env ClassVisitEnv) ([]string, []string, bool, bool, bool, bool, bool, bool, bool) {
	_ = h
	_ = node
	_ = struct_name
	_ = env
	return []string{}, []string{}, false, false, false, false, false, false, false
}

pub fn (h ClassBasesHandler) is_descendant_of(cls_name string, target string, env &ClassVisitEnv) bool {
	_ = h
	_ = cls_name
	_ = target
	_ = env
	return false
}

pub fn (h ClassBasesHandler) is_abstract_base_class(node ast.ClassDef, struct_name string, env &ClassVisitEnv) bool {
	_ = h
	_ = node
	_ = struct_name
	_ = env
	return false
}
