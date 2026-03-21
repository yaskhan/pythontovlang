// Я Qwen Code работаю над этим файлом. Начало: 2026-03-22 18:00
// Type state for mypy (typestate.py)
// Shared state for all TypeInfos that holds global cache and dependency information.

module mypy

const (
	max_negative_cache_types   = 1000
	max_negative_cache_entries = 10000
)

// SubtypeKind represents the conditions under which we performed the subtype check.
// (e.g. did we want a proper subtype? A regular subtype while ignoring variance?)
pub type SubtypeKind = []bool

// SubtypeCache keeps track of whether the given TypeInfo is a part of a particular subtype relationship.
pub type SubtypeCache = map[TypeInfo]map[SubtypeKind][]SubtypePair

// SubtypePair represents a (subtype, supertype) pair.
pub struct SubtypePair {
	left  Instance
	right Instance
}

// TypeState provides subtype caching to improve performance of subtype checks.
// It also holds protocol fine grained dependencies.
// Note: to avoid leaking global state, 'reset_all_subtype_caches()' should be called
// after a build has finished and after a daemon shutdown.
pub struct TypeState {
pub mut:
	// '_subtype_caches' keeps track of (subtype, supertype) pairs where supertypes are
	// instances of the given TypeInfo.
	_subtype_caches        SubtypeCache
	_negative_subtype_caches SubtypeCache
	
	// This contains protocol dependencies generated after running a full build.
	proto_deps map[string]map[string]bool
	
	// Protocols (full names) a given class attempted to implement.
	_attempted_protocols   map[string]map[string]bool
	_checked_against_members map[string]map[string]bool
	
	// TypeInfos that appeared as a left type (subtype) in a subtype check.
	_rechecked_types       map[TypeInfo]bool
	
	// Assumption stacks for subtyping relationships between recursive type aliases.
	_assuming              []TypePair
	_assuming_proper       []TypePair
	
	// For inference of generic constraints against recursive type aliases.
	inferring              []TypePair
	
	// Whether to use unions when solving constraints.
	infer_unions           bool
	
	// Whether to use new type inference algorithm that can infer polymorphic types.
	infer_polymorphic      bool
}

// TypePair represents a pair of types for assumptions.
pub struct TypePair {
	left  Type
	right Type
}

// new_type_state creates a new TypeState instance.
pub fn new_type_state() TypeState {
	return TypeState{
		_subtype_caches:        map[TypeInfo]map[SubtypeKind][]SubtypePair{}
		_negative_subtype_caches: map[TypeInfo]map[SubtypeKind][]SubtypePair{}
		proto_deps:             map[string]map[string]bool{}
		_attempted_protocols:   map[string]map[string]bool{}
		_checked_against_members: map[string]map[string]bool{}
		_rechecked_types:       map[TypeInfo]bool{}
		_assuming:              []TypePair{}
		_assuming_proper:       []TypePair{}
		inferring:              []TypePair{}
		infer_unions:           false
		infer_polymorphic:      false
	}
}

// Global type state instance
pub fn get_type_state() &TypeState {
	return &type_state
}

pub fn mut_type_state() &TypeState {
	return &mut type_state
}

// Static type state instance (initialized at compile time with defaults)
type_state := TypeState{}

// is_assumed_subtype checks if left is assumed to be a subtype of right.
pub fn (mut ts TypeState) is_assumed_subtype(left Type, right Type) bool {
	for i := ts._assuming.len - 1; i >= 0; i-- {
		pair := ts._assuming[i]
		if get_proper_type(pair.left) == get_proper_type(left) && get_proper_type(pair.right) == get_proper_type(right) {
			return true
		}
	}
	return false
}

// is_assumed_proper_subtype checks if left is assumed to be a proper subtype of right.
pub fn (mut ts TypeState) is_assumed_proper_subtype(left Type, right Type) bool {
	for i := ts._assuming_proper.len - 1; i >= 0; i-- {
		pair := ts._assuming_proper[i]
		if get_proper_type(pair.left) == get_proper_type(left) && get_proper_type(pair.right) == get_proper_type(right) {
			return true
		}
	}
	return false
}

// get_assumptions returns the assumption stack for proper or regular subtypes.
pub fn (mut ts TypeState) get_assumptions(is_proper bool) []TypePair {
	if is_proper {
		return ts._assuming_proper
	}
	return ts._assuming
}

// reset_all_subtype_caches completely resets all known subtype caches.
pub fn (mut ts TypeState) reset_all_subtype_caches() {
	ts._subtype_caches.clear()
	ts._negative_subtype_caches.clear()
}

// reset_subtype_caches_for resets subtype caches for a given supertype TypeInfo.
pub fn (mut ts TypeState) reset_subtype_caches_for(info TypeInfo) {
	if info in ts._subtype_caches {
		ts._subtype_caches[info].clear()
	}
	if info in ts._negative_subtype_caches {
		ts._negative_subtype_caches[info].clear()
	}
}

// reset_all_subtype_caches_for resets subtype caches for a given TypeInfo and its MRO.
pub fn (mut ts TypeState) reset_all_subtype_caches_for(info TypeInfo) {
	for item in info.mro {
		ts.reset_subtype_caches_for(item)
	}
}

// is_cached_subtype_check checks if a subtype check is cached.
pub fn (mut ts TypeState) is_cached_subtype_check(kind SubtypeKind, left Instance, right Instance) bool {
	if left.last_known_value != none || right.last_known_value != none {
		// If there is a literal last known value, give up.
		return false
	}
	info := right.type_info
	cache := ts._subtype_caches[info] or { return false }
	subcache := cache[kind] or { return false }
	for pair in subcache {
		if pair.left == left && pair.right == right {
			return true
		}
	}
	return false
}

// is_cached_negative_subtype_check checks if a negative subtype check is cached.
pub fn (mut ts TypeState) is_cached_negative_subtype_check(kind SubtypeKind, left Instance, right Instance) bool {
	if left.last_known_value != none || right.last_known_value != none {
		return false
	}
	info := right.type_info
	cache := ts._negative_subtype_caches[info] or { return false }
	subcache := cache[kind] or { return false }
	for pair in subcache {
		if pair.left == left && pair.right == right {
			return true
		}
	}
	return false
}

// record_subtype_cache_entry records a subtype cache entry.
pub fn (mut ts TypeState) record_subtype_cache_entry(kind SubtypeKind, left Instance, right Instance) {
	if left.last_known_value != none || right.last_known_value != none {
		return
	}
	for tv in right.type_info.defn.type_vars {
		if tv is TypeVarType {
			tv_type := tv as TypeVarType
			if tv_type.variance == variance_not_ready {
				return
			}
		}
	}
	if right.type_info !in ts._subtype_caches {
		ts._subtype_caches[right.type_info] = map[SubtypeKind][]SubtypePair{}
	}
	cache := ts._subtype_caches[right.type_info]
	if kind !in cache {
		cache[kind] = []SubtypePair{}
	}
	cache[kind] << SubtypePair{left: left, right: right}
}

// record_negative_subtype_cache_entry records a negative subtype cache entry.
pub fn (mut ts TypeState) record_negative_subtype_cache_entry(kind SubtypeKind, left Instance, right Instance) {
	if left.last_known_value != none || right.last_known_value != none {
		return
	}
	if ts._negative_subtype_caches.len > max_negative_cache_types {
		ts._negative_subtype_caches.clear()
	}
	if right.type_info !in ts._negative_subtype_caches {
		ts._negative_subtype_caches[right.type_info] = map[SubtypeKind][]SubtypePair{}
	}
	cache := ts._negative_subtype_caches[right.type_info]
	if kind !in cache {
		cache[kind] = []SubtypePair{}
	}
	subcache := cache[kind]
	if subcache.len > max_negative_cache_entries {
		cache[kind] = []SubtypePair{}
	}
	cache[kind] << SubtypePair{left: left, right: right}
}

// reset_protocol_deps resets dependencies after a full run or before a daemon shutdown.
pub fn (mut ts TypeState) reset_protocol_deps() {
	ts.proto_deps.clear()
	ts._attempted_protocols.clear()
	ts._checked_against_members.clear()
	ts._rechecked_types.clear()
}

// record_protocol_subtype_check records a protocol subtype check.
pub fn (mut ts TypeState) record_protocol_subtype_check(left_type TypeInfo, right_type TypeInfo) {
	assert right_type.is_protocol
	ts._rechecked_types[left_type] = true
	if left_type.fullname !in ts._attempted_protocols {
		ts._attempted_protocols[left_type.fullname] = map[string]bool{}
	}
	ts._attempted_protocols[left_type.fullname][right_type.fullname] = true
	
	if left_type.fullname !in ts._checked_against_members {
		ts._checked_against_members[left_type.fullname] = map[string]bool{}
	}
	for member in right_type.protocol_members {
		ts._checked_against_members[left_type.fullname][member] = true
	}
}

// update_protocol_deps updates global protocol dependency map.
pub fn (mut ts TypeState) update_protocol_deps(second_map ?map[string]map[string]bool) {
	new_deps := ts.snapshot_protocol_deps()
	for trigger, targets in new_deps {
		if trigger !in ts.proto_deps {
			ts.proto_deps[trigger] = map[string]bool{}
		}
		for target in targets {
			ts.proto_deps[trigger][target] = true
		}
	}
	if second_map != none {
		sm := second_map!
		for trigger in new_deps.keys() {
			targets := new_deps[trigger]
			if trigger !in sm {
				sm[trigger] = map[string]bool{}
			}
			for target in targets.keys() {
				sm[trigger][target] = true
			}
		}
	}
	ts._rechecked_types.clear()
	ts._attempted_protocols.clear()
	ts._checked_against_members.clear()
}

// snapshot_protocol_deps collects protocol attribute dependencies.
pub fn (mut ts TypeState) snapshot_protocol_deps() map[string]map[string]bool {
	deps := map[string]map[string]bool{}
	for info in ts._rechecked_types.keys() {
		checked := ts._checked_against_members[info.fullname] or { continue }
		for attr in checked.keys() {
			for base_info in info.mro[..info.mro.len-1] {
				trigger := make_trigger('${base_info.fullname}.${attr}')
				if 'typing' in trigger || 'builtins' in trigger {
					continue
				}
				if trigger !in deps {
					deps[trigger] = map[string]bool{}
				}
				deps[trigger][make_trigger(info.fullname)] = true
			}
		}
		attempted := ts._attempted_protocols[info.fullname] or { continue }
		for proto in attempted.keys() {
			trigger := make_trigger(info.fullname)
			if 'typing' in trigger || 'builtins' in trigger {
				continue
			}
			if trigger !in deps {
				deps[trigger] = map[string]bool{}
			}
			deps[trigger][proto] = true
		}
	}
	return deps
}

// add_all_protocol_deps adds all known protocol dependencies to deps.
pub fn (mut ts TypeState) add_all_protocol_deps(deps map[string]map[string]bool) {
	ts.update_protocol_deps(none)
	for trigger, targets in ts.proto_deps {
		if trigger !in deps {
			deps[trigger] = map[string]bool{}
		}
		for target in targets {
			deps[trigger][target] = true
		}
	}
}

// reset_global_state resets most existing global state.
pub fn reset_global_state() {
	type_state.reset_all_subtype_caches()
	type_state.reset_protocol_deps()
	TypeVarId.next_raw_id = 1
}
