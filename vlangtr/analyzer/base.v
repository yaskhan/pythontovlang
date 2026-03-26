module analyzer

pub struct MutabilityInfo {
pub mut:
	is_reassigned bool
	is_final      bool
	is_mutated    bool
}

pub struct CallSignature {
pub mut:
	args        []string
	arg_names   []string
	defaults    map[string]string
	return_type string
	is_class    bool
	has_init    bool
	has_vararg  bool
	has_kwarg   bool
	dataclass_metadata  map[string]string
	namedtuple_metadata map[string]string
}

pub struct TypeInferenceBase {
pub mut:
	type_map              map[string]string
	raw_type_map          map[string]string
	mutability_map        map[string]MutabilityInfo
	location_map          map[string]string
	call_signatures       map[string]CallSignature
	mixin_to_main         map[string][]string
	main_to_mixins        map[string][]string
	mixin_nodes           map[string]string
	static_methods        map[string][]string
	class_methods         map[string][]string
	is_abc                map[string]bool
	class_hierarchy       map[string][]string
	scope_names           []string
	explicit_any_types    map[string]bool
	func_param_mutability map[string][]int
}

pub fn new_type_inference_base() TypeInferenceBase {
	return TypeInferenceBase{
		type_map:              map[string]string{}
		raw_type_map:          map[string]string{}
		mutability_map:        map[string]MutabilityInfo{}
		location_map:          map[string]string{}
		call_signatures:       map[string]CallSignature{}
		mixin_to_main:         map[string][]string{}
		main_to_mixins:        map[string][]string{}
		mixin_nodes:           map[string]string{}
		static_methods:        map[string][]string{}
		class_methods:         map[string][]string{}
		is_abc:                map[string]bool{}
		class_hierarchy:       map[string][]string{}
		scope_names:           []string{}
		explicit_any_types:    map[string]bool{}
		func_param_mutability: map[string][]int{}
	}
}

pub fn (mut t TypeInferenceBase) push_scope(name string) {
	t.scope_names << name
}

pub fn (mut t TypeInferenceBase) pop_scope() {
	if t.scope_names.len > 0 {
		t.scope_names = t.scope_names[..t.scope_names.len - 1]
	}
}

pub fn (t &TypeInferenceBase) get_qualified_name(name string) string {
	if t.scope_names.len == 0 {
		return name
	}
	return t.scope_names.join('.') + '.' + name
}

pub fn (mut t TypeInferenceBase) set_type(name string, typ string) {
	t.type_map[name] = typ
}

pub fn (t &TypeInferenceBase) get_type(name string) string {
	return t.type_map[name] or { 'Any' }
}

pub fn (t &TypeInferenceBase) has_type(name string) bool {
	return name in t.type_map
}

pub fn (mut t TypeInferenceBase) set_mutability(name string, info MutabilityInfo) {
	t.mutability_map[name] = info
}

pub fn (t &TypeInferenceBase) get_mutability(name string) MutabilityInfo {
	return t.mutability_map[name] or { MutabilityInfo{} }
}

pub fn (mut t TypeInferenceBase) add_class_to_hierarchy(class_name string, bases []string) {
	t.class_hierarchy[class_name] = bases
}

pub fn (t &TypeInferenceBase) get_class_bases(class_name string) []string {
	return t.class_hierarchy[class_name] or { []string{} }
}
