<<<<<<< SEARCH
        if "py_set_xor" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_xor[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := map[K]bool{}
    for k, _ in a {
        if k !in b {
            res[k] = true
        }
    }
    for k, _ in b {
        if k !in a {
            res[k] = true
        }
    }
    return res
}""")
=======
        if "py_set_xor" in self.used_builtins:
             self.emitter.add_helper_function("""fn py_set_xor[K](a map[K]bool, b map[K]bool) map[K]bool {
    mut res := map[K]bool{}
    for k, _ in a {
        if k !in b {
            res[k] = true
        }
    }
    for k, _ in b {
        if k !in a {
            res[k] = true
        }
    }
    return res
}""")

        if "py_set_from_list" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_from_list[T](a []Any) T {
    mut res := T{}
    for x in a {
         T is map[string]bool {
            res[x.str()] = true
        }   T is map[int]bool {
            res[x as int] = true
        }  {
             // Fallback
        }
    }
    return res
}""")

        if "py_set_remove" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_remove[K](mut s map[K]bool, val K) {
    if val !in s { panic('KeyError') }
    s.delete(val)
}""")

        if "py_set_pop" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_pop[K](mut s map[K]bool) K {
    for k, _ in s {
        s.delete(k)
        return k
    }
    panic('KeyError: pop from an empty set')
}""")

        if "py_set_subset" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_subset[K](a map[K]bool, b map[K]bool) bool {
    for k, _ in a {
        if k !in b { return false }
    }
    return true
}""")

        if "py_set_strict_subset" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_strict_subset[K](a map[K]bool, b map[K]bool) bool {
    return a.len < b.len && py_set_subset(a, b)
}""")

        if "py_set_isdisjoint" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_isdisjoint[K](a map[K]bool, b map[K]bool) bool {
    for k, _ in a {
        if k in b { return false }
    }
    return true
}""")

        if "py_set_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_update[K](mut a map[K]bool, b map[K]bool) map[K]bool {
    for k, _ in b {
        a[k] = true
    }
    return a
}""")

        if "py_set_intersection_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_intersection_update[K](mut a map[K]bool, b map[K]bool) map[K]bool {
    mut to_delete := []K{}
    for k, _ in a {
        if k !in b { to_delete << k }
    }
    for k in to_delete {
        a.delete(k)
    }
    return a
}""")

        if "py_set_difference_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_difference_update[K](mut a map[K]bool, b map[K]bool) map[K]bool {
    for k, _ in b {
        a.delete(k)
    }
    return a
}""")

        if "py_set_xor_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_set_xor_update[K](mut a map[K]bool, b map[K]bool) map[K]bool {
    for k, _ in b {
        if k in a { a.delete(k) }
        else { a[k] = true }
    }
    return a
}""")
>>>>>>> REPLACE
