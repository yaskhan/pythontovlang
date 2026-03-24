// I, Qwen Code, am working on this file. Started: 2026-03-22 20:30
// Split namespace for argparse to allow separating options by prefix.
// We use this to direct some options to an Options object and some to a regular namespace.
// (split_namespace.py)

module mypy

pub type AttributeValue = bool | int | string

// SplitNamespace allows separating options by prefix.
// In V, we use a struct with two namespaces and a prefix.
pub struct SplitNamespace {
pub mut:
	standard_namespace map[string]AttributeValue
	alt_namespace      map[string]AttributeValue
	alt_prefix         string
}

// new_split_namespace creates a new SplitNamespace.
pub fn new_split_namespace(standard_namespace map[string]AttributeValue, alt_namespace map[string]AttributeValue, alt_prefix string) SplitNamespace {
	return SplitNamespace{
		standard_namespace: standard_namespace
		alt_namespace:      alt_namespace
		alt_prefix:         alt_prefix
	}
}

// get returns both namespaces.
pub fn (mut s SplitNamespace) get() (map[string]AttributeValue, map[string]AttributeValue) {
	return s.standard_namespace, s.alt_namespace
}

// set_attr sets an attribute in the appropriate namespace based on prefix.
pub fn (mut s SplitNamespace) set_attr(name string, value AttributeValue) {
	if name.starts_with(s.alt_prefix) {
		// Remove prefix and set in alt namespace
		alt_name := name[s.alt_prefix.len..]
		s.alt_namespace[alt_name] = value
	} else {
		s.standard_namespace[name] = value
	}
}

// get_attr gets an attribute from the appropriate namespace based on prefix.
pub fn (mut s SplitNamespace) get_attr(name string) ?AttributeValue {
	if name.starts_with(s.alt_prefix) {
		// Remove prefix and get from alt namespace
		alt_name := name[s.alt_prefix.len..]
		return s.alt_namespace[alt_name]
	} else {
		return s.standard_namespace[name]
	}
}

// has_attr checks if an attribute exists in either namespace.
pub fn (mut s SplitNamespace) has_attr(name string) bool {
	if name.starts_with(s.alt_prefix) {
		alt_name := name[s.alt_prefix.len..]
		return alt_name in s.alt_namespace
	} else {
		return name in s.standard_namespace
	}
}
