module analyzer

pub struct AliasInferer {
pub mut:
	alias_to_type map[string]string
}

pub fn new_alias_inferer() AliasInferer {
	return AliasInferer{
		alias_to_type: map[string]string{}
	}
}

pub fn (mut a AliasInferer) analyze(assignments map[string]string, instantiations map[string]string, appends map[string][]string) {
	mut aliases := map[string]string{}
	for lhs, rhs in assignments {
		if rhs in ["list", "set", "dict", "List", "Set", "Dict"] {
			aliases[lhs] = rhs.to_lower()
		}
	}
	mut var_to_alias := map[string]string{}
	for var_name, func_name in instantiations {
		if func_name in aliases {
			var_to_alias[var_name] = func_name
		}
	}
	mut alias_usages := map[string][]string{}
	for alias in aliases.keys() {
		alias_usages[alias] = []string{}
	}
	for var_name, appended_types in appends {
		if var_name in var_to_alias {
			alias := var_to_alias[var_name]
			for t in appended_types {
				if t !in alias_usages[alias] {
					alias_usages[alias] << t
				}
			}
		}
	}
	for alias, base_type in aliases {
		used_types := alias_usages[alias] or { []string{} }
		if used_types.len == 0 {
			if base_type == "list" {
				a.alias_to_type[alias] = "[]Any"
			} else {
				a.alias_to_type[alias] = "Any"
			}
		} else if used_types.len == 1 {
			inner_type := used_types[0]
			if base_type == "list" {
				a.alias_to_type[alias] = "[]" + inner_type
			} else {
				a.alias_to_type[alias] = "map[int]" + inner_type
			}
		} else {
			if base_type == "list" {
				a.alias_to_type[alias] = "[]Any"
			} else {
				a.alias_to_type[alias] = "map[int]Any"
			}
		}
	}
}

pub fn (a &AliasInferer) get_type(alias string) string {
	return a.alias_to_type[alias] or { "" }
}

pub struct MixinInferer {
pub mut:
	mixin_to_main map[string][]string
	main_to_mixins map[string][]string
	mixin_nodes map[string]string
	class_hierarchy map[string][]string
	is_abc map[string]bool
	static_methods map[string][]string
	class_methods map[string][]string
}

pub fn new_mixin_inferer() MixinInferer {
	return MixinInferer{}
}

fn (m &MixinInferer) get_all_ancestors(cls_name string) []string {
	mut result := []string{}
	mut visited := map[string]bool{}
	mut queue := m.class_hierarchy[cls_name] or { []string{} }
	mut i := 0
	for i < queue.len {
		curr := queue[i]
		i++
		if curr !in visited {
			visited[curr] = true
			result << curr
			parents := m.class_hierarchy[curr] or { []string{} }
			queue << parents
		}
	}
	return result
}

pub fn (mut m MixinInferer) analyze(class_defs map[string][]string, has_abstract map[string]bool) {
	for cls_name, bases in class_defs {
		m.mixin_nodes[cls_name] = cls_name
		m.is_abc[cls_name] = false
		m.static_methods[cls_name] = []string{}
		m.class_methods[cls_name] = []string{}
		m.class_hierarchy[cls_name] = bases
	}
	mut explicit_abcs := map[string]bool{}
	mut mixin_templates := map[string]bool{}
	for cls_name in m.mixin_nodes.keys() {
		if has_abstract[cls_name] or { false } {
			explicit_abcs[cls_name] = true
		}
		if cls_name.ends_with("Mixin") {
			mixin_templates[cls_name] = true
		}
	}
	mut changed := true
	for changed {
		changed = false
		for cls_name in m.class_hierarchy.keys() {
			if cls_name in explicit_abcs { continue }
			ancestors := m.get_all_ancestors(cls_name)
			mut has_abc_ancestor := false
			for a in ancestors {
				if a in explicit_abcs {
					has_abc_ancestor = true
					break
				}
			}
			if has_abc_ancestor {
				explicit_abcs[cls_name] = true
				changed = true
			}
		}
	}
	for cls_name in m.class_hierarchy.keys() {
		m.is_abc[cls_name] = cls_name in explicit_abcs
	}
}

pub struct FunctionMutabilityScanner {
pub mut:
	func_param_mutability map[string][]int
	current_func string
	current_params []string
	mutated_params []string
	reassigned_params []string
	scope_stack []string
	mutability_map map[string]MutabilityInfo
}

pub fn new_function_mutability_scanner() FunctionMutabilityScanner {
	return FunctionMutabilityScanner{}
}

pub fn (mut f FunctionMutabilityScanner) analyze(func_defs map[string][]string, assignments map[string][]string, calls map[string][]string) map[string][]int {
	for func_name, params in func_defs {
		f.current_func = func_name
		f.current_params = params
		f.mutated_params = []string{}
		f.reassigned_params = []string{}
		for target in assignments[func_name] or { []string{} } {
			if target in f.current_params { f.reassigned_params << target }
		}
		for call in calls[func_name] or { []string{} } {
			if call in f.current_params { f.mutated_params << call }
		}
		mut indices := []int{}
		for i, p in f.current_params {
			if p in f.mutated_params || p in f.reassigned_params { indices << i }
		}
		f.func_param_mutability[func_name] = indices
	}
	return f.func_param_mutability
}

pub fn (f &FunctionMutabilityScanner) get_mutated_params(func_name string) []int {
	return f.func_param_mutability[func_name] or { []int{} }
}
