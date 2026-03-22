// graph_utils.v — Helpers for manipulations with graphs
// Translated from mypy/graph_utils.py to V 0.5.x
//
// Work in progress by Cline. Started: 2026-03-22 04:48
//
// Translation notes:
//   - strongly_connected_components: Tarjan's algorithm for SCCs
//   - prepare_sccs: organize SCCs by dependencies
//   - topsort: topological sort using Kahn's algorithm

module mypy

// ---------------------------------------------------------------------------
// strongly_connected_components
// ---------------------------------------------------------------------------

// strongly_connected_components computes Strongly Connected Components of a directed graph.
//
// Args:
//   vertices: the labels for the vertices
//   edges: for each vertex, gives the target vertices of its outgoing edges
//
// Returns:
//   An iterator yielding strongly connected components, each
//   represented as a set of vertices. Each input vertex will occur
//   exactly once; vertices not part of a SCC are returned as
//   singleton sets.
pub fn strongly_connected_components[T](vertices []T, edges map[T][]T) [][]T {
	mut identified := map[T]bool{}
	mut stack := []T{}
	mut index := map[T]int{}
	mut boundaries := []int{}
	mut result := [][]T{}

	mut dfs := fn [mut identified, mut stack, mut index, mut boundaries, mut result, edges] (v T) {
		index[v] = stack.len
		stack << v
		boundaries << index[v]

		for w in edges[v] or { []T{} } {
			if w !in index {
				dfs(w)
			} else if w !in identified {
				for index[w] < boundaries[boundaries.len - 1] {
					boundaries.pop()
				}
			}
		}

		if boundaries[boundaries.len - 1] == index[v] {
			boundaries.pop()
			mut scc := []T{}
			for i in index[v] .. stack.len {
				scc << stack[i]
			}
			stack.trim(stack.len - scc.len)
			for sv in scc {
				identified[sv] = true
			}
			result << scc
		}
	}

	for v in vertices {
		if v !in index {
			dfs(v)
		}
	}

	return result
}

// ---------------------------------------------------------------------------
// prepare_sccs
// ---------------------------------------------------------------------------

// prepare_sccs uses original edges to organize SCCs in a graph by dependencies between them.
pub fn prepare_sccs[T](sccs [][]T, edges map[T][]T) map[string][]string {
	mut sccsmap := map[T]string{}
	mut scc_names := []string{}

	for idx, scc in sccs {
		scc_name := 'scc_${idx}'
		scc_names << scc_name
		for v in scc {
			sccsmap[v] = scc_name
		}
	}

	mut data := map[string][]string{}
	for idx, scc in sccs {
		scc_name := 'scc_${idx}'
		mut deps := []string{}
		for v in scc {
			for x in edges[v] or { []T{} } {
				dep_scc := sccsmap[x] or { continue }
				if dep_scc !in deps {
					deps << dep_scc
				}
			}
		}
		data[scc_name] = deps
	}
	return data
}

// ---------------------------------------------------------------------------
// topsort
// ---------------------------------------------------------------------------

// topsort implements topological sort using Kahn's algorithm.
//
// Uses in-degree counters and a reverse adjacency list, so the total work
// is O(V + E).
//
// Args:
//   data: A map from vertices to all vertices that it has an edge
//         connecting it to.
//
// Returns:
//   An iterator yielding sets of vertices that have an equivalent
//   ordering.
pub struct TopSort[T] {
pub mut:
	in_degree map[T]int
	rev       map[T][]T
	ready     []T
	remaining int
}

pub fn TopSort.new[T](data map[T][]T) TopSort[T] {
	mut in_degree := map[T]int{}
	mut rev := map[T][]T{}
	mut ready := []T{}

	for item, deps in data {
		// Ignore self dependencies
		mut filtered_deps := []T{}
		for dep in deps {
			if dep != item {
				filtered_deps << dep
			}
		}

		deg := filtered_deps.len
		in_degree[item] = deg
		if deg == 0 {
			ready << item
		}

		if item !in rev {
			rev[item] = []
		}

		for dep in filtered_deps {
			if dep in rev {
				rev[dep] << item
			} else {
				rev[dep] = [item]
				if dep !in data {
					// Orphan: appears as dependency but has no entry in data
					in_degree[dep] = 0
					ready << dep
				}
			}
		}
	}

	return TopSort[T]{
		in_degree: in_degree
		rev:       rev
		ready:     ready
		remaining: in_degree.len - ready.len
	}
}

pub fn (mut ts TopSort[T]) next() ?[]T {
	if ts.ready.len == 0 {
		if ts.remaining != 0 {
			// Cyclic dependency exists
			mut cyclic := []T{}
			for k, deg in ts.in_degree {
				if deg > 0 {
					cyclic << k
				}
			}
			panic('A cyclic dependency exists amongst ${cyclic}')
		}
		return none
	}

	mut new_ready := []T{}
	for item in ts.ready {
		for dependent in ts.rev[item] or { []T{} } {
			new_deg := ts.in_degree[dependent] - 1
			ts.in_degree[dependent] = new_deg
			if new_deg == 0 {
				new_ready << dependent
			}
		}
	}

	ts.remaining -= new_ready.len
	result := ts.ready
	ts.ready = new_ready
	return result
}

// ---------------------------------------------------------------------------
// set_from helper
// ---------------------------------------------------------------------------

// set_from creates a set from a list
fn set_from[T](items []T) []T {
	mut s := []T{}
	for item in items {
		if item !in s {
			s << item
		}
	}
	return s
}
