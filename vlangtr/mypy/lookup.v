// lookup.v — Various lookup functions for finding semantic nodes by name
// Translated from mypy/lookup.py to V 0.5.x
//
// Work in progress by Cline. Started: 2026-03-22 08:25
//
// Translation notes:
//   - lookup_fully_qualified: finds a symbol using its fully qualified name
//   - Uses modules dictionary to find module, then traverses nested names

module mypy

// ---------------------------------------------------------------------------
// lookup_fully_qualified
// ---------------------------------------------------------------------------

// lookup_fully_qualified finds a symbol using its fully qualified name.
pub fn lookup_fully_qualified(name string, modules map[string]MypyFile) ?SymbolTableNode {
	// 1. Exclude the names of ad hoc instance intersections from step 2.
	i := name.index('<subclass ') or { -1 }
	mut head := if i == -1 { name } else { name[..i] }
	mut rest := []string{}

	// 2. Find a module tree in modules dictionary.
	for {
		if !head.contains('.') {
			return none
		}
		// Split on the last dot
		idx := head.last_index('.') or { -1 }
		tail := if idx != -1 { head[idx + 1..] } else { head }
		head = if idx != -1 { head[..idx] } else { '' }
		rest << tail
		if head in modules {
			mod := modules[head] or { continue }
			// Found the module
			names := mod.names
			// 3. Find the symbol in the module tree.
			if rest.len == 0 {
				// Looks like a module, don't use this to avoid confusions.
				return none
			}
			if i != -1 {
				rest[0] += name[i..]
			}
			// Traverse the rest of the path
			mut current_symbols := names.symbols.clone()
			for rest.len > 0 {
				key := rest.pop()
				if key !in current_symbols {
					return none
				}
				stnode := current_symbols[key] or { return none }
				if rest.len == 0 {
					return stnode
				}
				if n := stnode.node {
					if n is TypeInfo {
						current_symbols = (n as TypeInfo).names.symbols
					} else {
						return none
					}
				} else {
					return none
				}
			}
			break
		}
	}
	return none
}
