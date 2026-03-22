// lookup.v — Various lookup functions for finding semantic nodes by name
// Translated from mypy/lookup.py to V 0.5.x
//
// Я Cline работаю над этим файлом. Начало: 2026-03-22 08:25
//
// Translation notes:
//   - lookup_fully_qualified: finds a symbol using its fully qualified name
//   - Uses modules dictionary to find module, then traverses nested names

module mypy

// ---------------------------------------------------------------------------
// lookup_fully_qualified
// ---------------------------------------------------------------------------

// lookup_fully_qualified finds a symbol using its fully qualified name.
//
// The algorithm has two steps: first we try splitting the name on '.' to find
// the module, then iteratively look for each next chunk after a '.' (e.g. for
// nested classes).
//
// This function should *not* be used to find a module. Those should be looked
// in the modules dictionary.
pub fn lookup_fully_qualified(name string, modules map[string]MypyFile, raise_on_missing bool) ?SymbolTableNode {
	// 1. Exclude the names of ad hoc instance intersections from step 2.
	i := name.index('<subclass ') or { -1 }
	mut head := if i == -1 { name } else { name[..i] }
	mut rest := []string{}

	// 2. Find a module tree in modules dictionary.
	for {
		if '.' !in head {
			if raise_on_missing {
				panic('Cannot find module for ${name}')
			}
			return none
		}
		// Split on the last dot
		parts := head.rsplit('.', 1)
		head = parts[0]
		tail := parts[1]
		rest << tail
		mod := modules[head] or { continue }
		// Found the module
		names := mod.names
		// 3. Find the symbol in the module tree.
		if rest.len == 0 {
			// Looks like a module, don't use this to avoid confusions.
			if raise_on_missing {
				panic('Cannot find ${name}, got a module symbol')
			}
			return none
		}
		if i != -1 {
			rest[0] += name[i..]
		}
		// Traverse the rest of the path
		mut current_names := names
		for rest.len > 0 {
			key := rest.pop()
			if key !in current_names {
				if raise_on_missing {
					panic('Cannot find component ${key} for ${name}')
				}
				return none
			}
			stnode := current_names[key] or { return none }
			if rest.len == 0 {
				return stnode
			}
			node := stnode.node
			// In fine-grained mode, could be a cross-reference to a deleted module
			// or a Var made up for a missing module.
			if node !is TypeInfo {
				if raise_on_missing {
					panic('Cannot find ${name}')
				}
				return none
			}
			current_names = node.names
		}
		break
	}
	return none
}
