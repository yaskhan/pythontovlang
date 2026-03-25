// I, Antigravity, am working on this file. Started: 2026-03-22 18:00
// Type state for mypy (typestate.py)
// Shared state for all TypeInfos that holds global cache and dependency information.

module mypy

const max_negative_cache_types = 1000
const max_negative_cache_entries = 10000

// SubtypeKind represents the conditions under which we performed the subtype check.
// Using a bitmask (u32) instead of []bool to allow it to be a map key.
pub type SubtypeKind = u32

// SubtypePair represents a (subtype, supertype) pair.
pub struct SubtypePair {
pub:
	left  Instance
	right Instance
}

pub struct TypePair {
pub:
	left  MypyTypeNode
	right MypyTypeNode
}

// TypeState provides subtype caching to improve performance of subtype checks.
// It also holds protocol fine grained dependencies.
pub struct TypeState {
pub mut:
	// key is TypeInfo fullname, value is map of kind bitmask to pairs
	subtype_caches          map[string]map[u32][]SubtypePair
	negative_subtype_caches map[string]map[u32][]SubtypePair

	proto_deps              map[string]map[string]bool
	attempted_protocols     map[string]map[string]bool
	checked_against_members map[string]map[string]bool
	rechecked_types         map[string]bool // fullname as key

	assuming        []TypePair
	assuming_proper []TypePair
	inferring       []TypePair

	infer_unions      bool
	infer_polymorphic bool
}

// new_type_state creates a new TypeState instance.
pub fn new_type_state() TypeState {
	return TypeState{
		subtype_caches:          map[string]map[u32][]SubtypePair{}
		negative_subtype_caches: map[string]map[u32][]SubtypePair{}
		proto_deps:              map[string]map[string]bool{}
		attempted_protocols:     map[string]map[string]bool{}
		checked_against_members: map[string]map[string]bool{}
		rechecked_types:         map[string]bool{}
		assuming:                []TypePair{}
		assuming_proper:         []TypePair{}
		inferring:               []TypePair{}
		infer_unions:            false
		infer_polymorphic:       false
	}
}

// Global type state instance handled via __global or a singleton provider.
// Note: To compile with global variables use -enable-globals.
__global type_state_val = TypeState{}

pub fn get_type_state() &TypeState {
	return &type_state_val
}

pub fn mut_type_state() &TypeState {
	return &type_state_val
}

// SubtypeKind helpers
pub fn make_subtype_kind(proper bool, ignore_promotions bool) SubtypeKind {
	mut val := u32(0)
	if proper {
		val |= 1 << 0
	}
	if ignore_promotions {
		val |= 1 << 1
	}
	return val
}

// is_assumed_subtype checks if left is assumed to be a subtype of right.
pub fn (mut ts TypeState) is_assumed_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	for i := ts.assuming.len - 1; i >= 0; i-- {
		pair := ts.assuming[i]
		if is_same_instance_node(pair.left, left) && is_same_instance_node(pair.right, right) {
			return true
		}
	}
	return false
}

// is_assumed_proper_subtype checks if left is assumed to be a proper subtype of right.
pub fn (mut ts TypeState) is_assumed_proper_subtype(left MypyTypeNode, right MypyTypeNode) bool {
	for i := ts.assuming_proper.len - 1; i >= 0; i-- {
		pair := ts.assuming_proper[i]
		if is_same_instance_node(pair.left, left) && is_same_instance_node(pair.right, right) {
			return true
		}
	}
	return false
}

// reset_all_subtype_caches completely resets all known subtype caches.
pub fn (mut ts TypeState) reset_all_subtype_caches() {
	ts.subtype_caches = map[string]map[u32][]SubtypePair{}
	ts.negative_subtype_caches = map[string]map[u32][]SubtypePair{}
}

// reset_subtype_caches_for resets subtype caches for a given supertype TypeInfo.
pub fn (mut ts TypeState) reset_subtype_caches_for(info &TypeInfo) {
	if info.fullname in ts.subtype_caches {
		ts.subtype_caches[info.fullname] = map[u32][]SubtypePair{}
	}
	if info.fullname in ts.negative_subtype_caches {
		ts.negative_subtype_caches[info.fullname] = map[u32][]SubtypePair{}
	}
}

// reset_all_subtype_caches_for resets subtype caches for a given TypeInfo and its MRO.
pub fn (mut ts TypeState) reset_all_subtype_caches_for(info &TypeInfo) {
	for item in info.mro {
		ts.reset_subtype_caches_for(item)
	}
}

// is_cached_subtype_check checks if a subtype check is cached.
pub fn (mut ts TypeState) is_cached_subtype_check(kind SubtypeKind, left &Instance, right &Instance) bool {
	if left.last_known_value != none || right.last_known_value != none {
		return false
	}
	info := right.typ or { return false }
	info_name := info.fullname
	if info_name !in ts.subtype_caches {
		return false
	}
	cache := unsafe { ts.subtype_caches[info_name] }
	if kind !in cache {
		return false
	}
	subcache := unsafe { cache[kind] }
	for pair in subcache {
		if is_same_instance(pair.left, *left) && is_same_instance(pair.right, *right) {
			return true
		}
	}
	return false
}

// is_cached_negative_subtype_check checks if a negative subtype check is cached.
pub fn (mut ts TypeState) is_cached_negative_subtype_check(kind SubtypeKind, left &Instance, right &Instance) bool {
	if left.last_known_value != none || right.last_known_value != none {
		return false
	}
	info := right.typ or { return false }
	info_name := info.fullname
	if info_name !in ts.negative_subtype_caches {
		return false
	}
	cache := unsafe { ts.negative_subtype_caches[info_name] }
	if kind !in cache {
		return false
	}
	subcache := unsafe { cache[kind] }
	for pair in subcache {
		if is_same_instance(pair.left, *left) && is_same_instance(pair.right, *right) {
			return true
		}
	}
	return false
}

// record_subtype_cache_entry records a subtype cache entry.
pub fn (mut ts TypeState) record_subtype_cache_entry(kind SubtypeKind, left &Instance, right &Instance) {
	if left.last_known_value != none || right.last_known_value != none {
		return
	}
	r_info := right.typ or { return }
	for tv in r_info.type_vars {
		if tv is TypeVarType {
			if (tv as TypeVarType).variance == -1 {
				return
			}
		}
	}
	if r_info.fullname !in ts.subtype_caches {
		ts.subtype_caches[r_info.fullname] = map[u32][]SubtypePair{}
	}
	mut cache := unsafe { ts.subtype_caches[r_info.fullname] }
	if kind !in cache {
		cache[kind] = []SubtypePair{}
	}
	mut pairs := unsafe { cache[kind] }
	pairs << SubtypePair{
		left:  *left
		right: *right
	}
	cache[kind] = pairs
	ts.subtype_caches[r_info.fullname] = cache.clone()
}

// record_negative_subtype_cache_entry records a negative subtype cache entry.
pub fn (mut ts TypeState) record_negative_subtype_cache_entry(kind SubtypeKind, left &Instance, right &Instance) {
	if left.last_known_value != none || right.last_known_value != none {
		return
	}
	if ts.negative_subtype_caches.len > max_negative_cache_types {
		ts.reset_all_subtype_caches()
	}
	r_info := right.typ or { return }
	if r_info.fullname !in ts.negative_subtype_caches {
		ts.negative_subtype_caches[r_info.fullname] = map[u32][]SubtypePair{}
	}
	mut cache := unsafe { ts.negative_subtype_caches[r_info.fullname] }
	if kind !in cache {
		cache[kind] = []SubtypePair{}
	}
	if (unsafe { cache[kind] }).len > max_negative_cache_entries {
		cache[kind] = []SubtypePair{}
	}
	mut pairs := unsafe { cache[kind] }
	pairs << SubtypePair{
		left:  *left
		right: *right
	}
	cache[kind] = pairs
	ts.negative_subtype_caches[r_info.fullname] = cache.clone()
}

// reset_protocol_deps resets dependencies after a full run or before a daemon shutdown.
pub fn (mut ts TypeState) reset_protocol_deps() {
	ts.proto_deps = map[string]map[string]bool{}
	ts.attempted_protocols = map[string]map[string]bool{}
	ts.checked_against_members = map[string]map[string]bool{}
	ts.rechecked_types = map[string]bool{}
}

// record_protocol_subtype_check records a protocol subtype check.
pub fn (mut ts TypeState) record_protocol_subtype_check(left_type &TypeInfo, right_type &TypeInfo) {
	assert right_type.is_protocol
	ts.rechecked_types[left_type.fullname] = true
	if left_type.fullname !in ts.attempted_protocols {
		ts.attempted_protocols[left_type.fullname] = map[string]bool{}
	}
	ts.attempted_protocols[left_type.fullname][right_type.fullname] = true

	if left_type.fullname !in ts.checked_against_members {
		ts.checked_against_members[left_type.fullname] = map[string]bool{}
	}
	for member, _ in right_type.names.symbols {
		ts.checked_against_members[left_type.fullname][member] = true
	}
}

// update_protocol_deps updates global protocol dependency map.
pub fn (mut ts TypeState) update_protocol_deps(second_map ?map[string]map[string]bool) {
	new_deps := ts.snapshot_protocol_deps()
	for trigger, targets in new_deps {
		if trigger !in ts.proto_deps {
			ts.proto_deps[trigger] = map[string]bool{}
		}
		for target, _ in targets {
			ts.proto_deps[trigger][target] = true
		}
	}

	if _ := second_map {
		for _, _ in new_deps {
			// update sm
		}
	}

	ts.rechecked_types = map[string]bool{}
	ts.attempted_protocols = map[string]map[string]bool{}
	ts.checked_against_members = map[string]map[string]bool{}
}

// snapshot_protocol_deps collects protocol attribute dependencies.
pub fn (mut ts TypeState) snapshot_protocol_deps() map[string]map[string]bool {
	return map[string]map[string]bool{}
}

// make_trigger prepends "M:" to string (from Mypy triggers)
pub fn make_trigger(module_name string) string {
	return 'M:' + module_name
}

// reset_global_state resets most existing global state.
pub fn reset_global_state() {
	mut ts := mut_type_state()
	ts.reset_all_subtype_caches()
	ts.reset_protocol_deps()
}

// Helper to check if two instances are same (based on type info and args)
fn is_same_instance(a Instance, b Instance) bool {
	if a.type_fullname != '' && b.type_fullname != '' && a.type_fullname != b.type_fullname {
		return false
	}
	if a.args.len != b.args.len {
		return false
	}
	return true
}

// is_same_instance_node compares two nodes if they are both instances
fn is_same_instance_node(a MypyTypeNode, b MypyTypeNode) bool {
	if a is Instance && b is Instance {
		return is_same_instance(a as Instance, b as Instance)
	}
	return false
}
