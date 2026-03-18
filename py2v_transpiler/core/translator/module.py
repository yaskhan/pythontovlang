import ast
from typing import Any, List, Optional, Dict, Set
from .base import TranslatorBase

class ModuleMixin(TranslatorBase):
    def visit_Module(self, node: ast.Module) -> str:
        # Pre-scan for __all__ and symbols
        self.module_all = None
        for stmt in node.body:
            # Track imported symbols for re-export
            if isinstance(stmt, ast.Import):
                for alias in stmt.names:
                    self.defined_top_level_symbols.add(alias.asname if alias.asname else alias.name)
            elif isinstance(stmt, ast.ImportFrom):
                for alias in stmt.names:
                    self.defined_top_level_symbols.add(alias.asname if alias.asname else alias.name)

            if isinstance(stmt, ast.Assign):
                for target in stmt.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        if isinstance(stmt.value, (ast.List, ast.Tuple)):
                            self.module_all = []
                            for elt in stmt.value.elts:
                                if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                                    self.module_all.append(elt.value)
                        break

        self.emitter.module_name = self.current_module_name
        self.global_vars = set()
        for subnode in ast.walk(node):
            if isinstance(subnode, ast.Global):
                self.global_vars.update(subnode.names)

        self.coroutine_handler.scan_module(node)

        # Check module docstring
        if node.body and isinstance(node.body[0], ast.Expr) and isinstance(node.body[0].value, ast.Constant) and isinstance(node.body[0].value.value, str):
            # This is a docstring
            doc = node.body[0].value.value.strip()
            for line in doc.splitlines():
                self.emitter.add_main_statement(f"// {line}")
            # Skip first statement
            body = node.body[1:]
        else:
            body = node.body

        for stmt in body:
            # Skip __all__ assignment in output
            if isinstance(stmt, ast.Assign):
                is_all = False
                for target in stmt.targets:
                    if isinstance(target, ast.Name) and target.id == "__all__":
                        is_all = True
                        break
                if is_all:
                    continue

            # Check if statement is top-level expression or assignment
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Import, ast.ImportFrom)):
                self.in_main = False
                self.visit(stmt)
                self.in_main = True
            else:
                self.output = []
                if getattr(self.config, 'source_mapping', False):
                    self.output.append(f"// @line: {self._get_source_info(stmt)}")
                self.visit(stmt)
                for line in self.output:
                    self.emitter.add_main_statement(line.strip())
                self.output = []

        # Post-scan validation for __all__
        if self.module_all is not None:
            for name in self.module_all:
                if name not in self.defined_top_level_symbols:
                    self.warnings.append(f"Symbol '{name}' listed in __all__ but not defined in module")

        # Inject helpers based on usage
        if "sorted" in self.used_builtins:
             self.emitter.add_helper_function("fn py_sorted[T](a []T) []T {\n    mut res := a.clone()\n    res.sort()\n    return res\n}")

        if "reversed" in self.used_builtins:
             self.emitter.add_helper_function("fn py_reversed[T](a []T) []T {\n    mut res := a.clone()\n    res.reverse()\n    return res\n}")

        if "py_repeat" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repeat(s string, n int) string {\n    if n <= 0 { return '' }\n    return s.repeat(n)\n}")

        if "py_repeat_list" in self.used_builtins:
             self.emitter.add_helper_function("fn py_repeat_list[T](l []T, n int) []T {\n    if n <= 0 { return []T{} }\n    mut res := []T{cap: l.len * n}\n    for _ in 0..n {\n        res << l\n    }\n    return res\n}")

        if "round" in self.used_builtins:
             self.emitter.add_helper_function("fn py_round(val f64, ndigits int) f64 {\n    import math\n    if ndigits == 0 { return math.round(val) }\n    p := math.pow(10.0, f64(ndigits))\n    return math.round(val * p) / p\n}")

        if self.used_complex:
             self.emitter.add_helper_struct("struct PyComplex {\n    real f64\n    imag f64\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) + (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real + c2.real, imag: c1.imag + c2.imag}\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) - (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real - c2.real, imag: c1.imag - c2.imag}\n}")
             self.emitter.add_helper_function("fn (c1 PyComplex) * (c2 PyComplex) PyComplex {\n    return PyComplex{real: c1.real * c2.real - c1.imag * c2.imag, imag: c1.real * c2.imag + c1.imag * c2.real}\n}")
             self.emitter.add_helper_function("fn (c PyComplex) str() string {\n    sign := if c.imag >= 0 { '+' } else { '' }\n    return '(${c.real}${sign}${c.imag}j)'\n}")

        used_modules_from_symbols = set()
        for full_name in self.imported_symbols.values():
             parts = full_name.split(".")
             if len(parts) > 1:
                  used_modules_from_symbols.add(".".join(parts[:-1]))

        # Conditional helper injection for specific modules
        json_used = "json" in self.imported_modules.values()
        if not json_used:
             json_used = "json" in used_modules_from_symbols

        if json_used:
             self.emitter.add_helper_import("x.json2")
             self.emitter.add_helper_function("fn py_json_loads(s string) Any {\n    return json2.raw_decode(s) or { Any(NoneType{}) }\n}")
             self.emitter.add_helper_function("fn py_json_dumps(val Any) string {\n    return json2.encode(val)\n}")

        hashlib_used = "hashlib" in self.imported_modules.values()
        if not hashlib_used:
             hashlib_used = "hashlib" in used_modules_from_symbols

        if hashlib_used:
             self.emitter.add_helper_import("crypto.sha256")
             self.emitter.add_helper_import("crypto.md5")
             self.emitter.add_helper_struct("struct PyHashSha256 {\nmut:\n    data []u8\n}")
             self.emitter.add_helper_function("fn py_hash_sha256(data []u8) PyHashSha256 {\n    return PyHashSha256{data: data}\n}")
             self.emitter.add_helper_function("fn (mut h PyHashSha256) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_helper_function("fn (h PyHashSha256) digest() []u8 {\n    return sha256.sum(h.data)\n}")
             self.emitter.add_helper_function("fn (h PyHashSha256) hexdigest() string {\n    return sha256.hexhash(h.data)\n}")

             self.emitter.add_helper_struct("struct PyHashMd5 {\nmut:\n    data []u8\n}")
             self.emitter.add_helper_function("fn py_hash_md5(data []u8) PyHashMd5 {\n    return PyHashMd5{data: data}\n}")
             self.emitter.add_helper_function("fn (mut h PyHashMd5) update(data []u8) {\n    h.data << data\n}")
             self.emitter.add_helper_function("fn (h PyHashMd5) digest() []u8 {\n    return md5.sum(h.data)\n}")
             self.emitter.add_helper_function("fn (h PyHashMd5) hexdigest() string {\n    return md5.hexhash(h.data)\n}")

        if "py_bool" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_bool[T](val T) bool {
    $if T is bool { return val }
    $else $if T is string { return val != '' }
    $else $if T is int || T is i64 || T is f64 { return val != 0 }
    $else $if T is []Any { return val.len > 0 }
    $else $if T is map[string]Any { return val.len > 0 }
    $else $if T is NoneType { return false }
    $else { return true }
}""")

        if "py_list_pop_at" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_pop_at[T](mut a []T, index int) T {
    mut i := index
    if i < 0 { i += a.len }
    res := a[i]
    a.delete(i)
    return res
}""")

        if "py_list_remove" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_list_remove[T](mut a []T, val T) {
    idx := a.index(val)
    if idx >= 0 {
        a.delete(idx)
    }
}""")

        if self.used_list_concat:
            self.emitter.add_helper_function("""fn py_list_concat[T](lists ...[]T) []T {
    mut res := []T{}
    for l in lists {
        res << l
    }
    return res
}""")

        if "py_dict_pop" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_pop[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        val := d[key]
        d.delete(key)
        return val
    }
    return default
}""")

        if "py_dict_update" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_update[K, V](mut d map[K]V, other ...map[K]V) map[K]V {
    for o in other {
        for k, v in o {
            d[k] = v
        }
    }
    return d
}""")

        if "py_dict_setdefault" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_setdefault[K, V](mut d map[K]V, key K, default V) V {
    if key in d {
        return d[key]
    }
    d[key] = default
    return default
}""")

        if "py_dict_fromkeys" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_fromkeys[M, K, V](keys []K, val V) M {
    mut res := M{ }
    for k in keys {
        res[k] = val
    }
    return res
}""")

        if "py_dict_from_pairs" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_dict_from_pairs[M, K, V](pairs [][]Any) M {
    mut res := M{ }
    for p in pairs {
        if p.len >= 2 {
            mut key := K{}
            $if K is string {
                 key = (p[0] as string)
            } $else $if K is int {
                 key = (p[0] as int)
            } $else {
                 key = (p[0] as K)
            }
            mut value := V{}
             $if V is Any {
                 value = p[1]
            } $else {
                 value = (p[1] as V)
            }
            res[key] = value
        }
    }
    return res
}""")

        if self.used_dict_merge:
            self.emitter.add_helper_function("""fn py_dict_merge[K, V](dicts ...map[K]V) map[K]V {
    mut res := map[K]V{}
    for d in dicts {
        for k, v in d {
            res[k] = v
        }
    }
    return res
}""")

        if "py_slice" in self.used_builtins:
            self.emitter.add_helper_function("""fn py_slice(obj Any, lower ?Any, upper ?Any) Any {
    if obj is string {
        mut l := 0
        if lower_val := lower {
            if lower_val is int { l = lower_val }
        }
        mut u := obj.len
        if upper_val := upper {
            if upper_val is int { u = upper_val }
        }
        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }
        if l > u { return '' }
        return obj[l..u]
    } else if obj is []u8 {
        mut l := 0
        if lower_val := lower {
            if lower_val is int { l = lower_val }
        }
        mut u := obj.len
        if upper_val := upper {
            if upper_val is int { u = upper_val }
        }
        if l < 0 { l += obj.len }
        if u < 0 { u += obj.len }
        if l < 0 { l = 0 }
        if u > obj.len { u = obj.len }
        if l > u { return []u8{} }
        return obj[l..u]
    }
    return false
}""")

        return self.emitter.emit() + "\n" + self.emitter.emit_helpers()
