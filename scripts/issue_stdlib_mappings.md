##title: Fix Missing Python Module Mappings (types, builtins, inspect) in Generated V Code
##descr: The transpiler generates references to Python modules (types.NotImplementedType, builtins.list, C.__dict__) that have no V equivalents, causing compilation errors.

### Problem
When transpiling Python code that uses standard library modules like `types`, `builtins`, `inspect`, the transpiler directly translates module paths to V syntax without providing proper mappings or implementations. This results in V code that references non-existent modules and types.

### Analysis of test_abc.py → test_abc.v

#### Issue 1: types.NotImplementedType

**Python Input (test_abc.py:466):**
```python
@classmethod
def __subclasshook__(cls, C):
    if cls is A:
        return 'foo' in C.__dict__
    return NotImplemented
```

**Current V Output (test_abc.v:827):**
```v
mut ___subclasshook__ := fn (C fn (...Any) Any) types.NotImplementedType {
    if TestABC_A == A {
        return 'foo' in C.__dict__
    }
    return NotImplemented
}
```

**Problems:**
1. ❌ `types.NotImplementedType` - Module `types` doesn't exist in V mapping
2. ❌ `NotImplemented` - Constant not defined
3. ❌ `C fn (...Any) Any` - Invalid parameter syntax (should be `C Any`)

**Expected V Output:**
```v
mut ___subclasshook__ := fn (C Any) Any {
    if TestABC_A == A {
        return strings.contains(map_keys(C.__dict__), 'foo')
    }
    return none  // NotImplemented mapped to none
}
```

---

#### Issue 2: C.__dict__ Attribute Access

**Python Input (test_abc.py:468):**
```python
return 'foo' in C.__dict__
```

**Current V Output (test_abc.v:829):**
```v
return 'foo' in C.__dict__
```

**Problems:**
1. ❌ `C.__dict__` - Python classes have `__dict__` attribute, V structs don't
2. ❌ `in` operator on dict - V uses different syntax for map key checking

**Expected V Output:**
```v
return C.__dict__ != none && 'foo' in C.__dict__.keys()
// Or with helper function
return py_hasattr(C, '__dict__') && 'foo' in py_dict_keys(C.__dict__)
```

---

#### Issue 3: builtins.list Type Annotation

**Python Input (test_abc.py:499):**
```python
def with_metaclass(meta, *bases):
    class metaclass(type):
        def __new__(cls, name, this_bases, d):
            return meta(name, bases, d)
    return type.__new__(metaclass, 'temporary_class', (), {})
```

**Current V Output (test_abc.v:858):**
```v
mut with_metaclass := fn (meta fn (...Any) Any, bases ...builtins.list[ast.expr]) Any {
    mut new_ := fn [bases, meta] (name Any, this_bases Any, d Any) Any {
        return meta(name, bases, d)
    }
    return py_type.__new__(metaclass, 'temporary_class', [], map[string]Any{})
}
```

**Problems:**
1. ❌ `builtins.list[ast.expr]` - Module `builtins` doesn't exist in V mapping
2. ❌ `ast.expr` - Module `ast` doesn't exist in V mapping
3. ❌ `...builtins.list[ast.expr]` - Invalid variadic type syntax

**Expected V Output:**
```v
mut with_metaclass := fn (meta fn (...Any) Any, bases ...[]Any) Any {
    mut new_ := fn [bases, meta] (name Any, this_bases Any, d Any) Any {
        return meta(name, bases, d)
    }
    return py_type.__new__(metaclass, 'temporary_class', [], map[string]Any{})
}
```

---

### Root Causes

1. **Missing stdlib mappings** - No V equivalents for `types`, `builtins`, `ast`, `inspect` modules
2. **Direct translation** - Type annotations are directly translated without mapping
3. **No fallback** - When module not found, transpiler doesn't provide fallback to `Any`
4. **Python-specific attributes** - `__dict__`, `__class__`, etc. not handled

### Impact

**Affected Code Patterns:**
- `types.NotImplementedType` → Return type of functions returning `NotImplemented`
- `builtins.list`, `builtins.dict`, `builtins.set` → Type annotations
- `builtins.object` → Base class references
- `C.__dict__` → Class attribute access
- `obj.__class__` → Instance class access
- `inspect.isabstract()` → Runtime inspection
- `ast.expr`, `ast.Name`, etc. → AST type annotations

**Estimated Scope:**
- 10+ test files reference these modules
- Common in metaprogramming code
- Blocks transpilation of libraries using introspection

### Tasks

#### Phase 1: Core Module Mappings

1. **Create `stdlib_map/types.v`**
   ```v
   // types module mapping
   pub const NotImplemented = none
   
   pub fn NotImplementedType() Any {
       return none
   }
   
   pub fn LambdaType() Any {
       return none
   }
   
   // ... other type aliases
   ```

2. **Create `stdlib_map/builtins.v`**
   ```v
   // builtins module mapping
   pub fn list<T>(items ...T) []T {
       return items
   }
   
   pub fn dict<K, V>() map[K]V {
       return map[K]V{}
   }
   
   pub fn object {}  // Base object type
   
   pub fn hasattr(obj Any, name string) bool {
       // Runtime check
   }
   
   pub fn getattr(obj Any, name string, default Any) Any {
       // Runtime attribute access
   }
   ```

3. **Update type mapper in `v_types.py`**
   - Map `types.NotImplementedType` → `Any`
   - Map `builtins.list[T]` → `[]T`
   - Map `builtins.dict[K, V]` → `map[K]V`
   - Map `builtins.object` → `Any`

#### Phase 2: Attribute Access

4. **Handle `__dict__` attribute**
   - Add `__dict__` field to generated structs when needed
   - Generate helper functions for dict access
   - Map `'key' in obj.__dict__` to proper V syntax

5. **Handle `__class__` attribute**
   - Add `__class__` field or method to structs
   - Map `type(obj)` to appropriate V code

#### Phase 3: Module Cleanup

6. **Remove invalid module prefixes**
   - Strip `builtins.` from type annotations
   - Strip `types.` from return types
   - Replace with direct V types

7. **Add import cleanup**
   - Remove unused module imports
   - Add required stdlib imports automatically

### Files to Modify

**New Files:**
- `py2v_transpiler/stdlib_map/types.v` (new)
- `py2v_transpiler/stdlib_map/builtins.v` (new)
- `py2v_transpiler/stdlib_map/inspect.v` (new)

**Modified Files:**
- `py2v_transpiler/models/v_types.py` - Add type mappings
- `py2v_transpiler/core/translator/expressions_split/attributes.py` - Handle `__dict__`, `__class__`
- `py2v_transpiler/core/translator/variables_split/annotations.py` - Strip module prefixes
- `py2v_transpiler/stdlib_map/mapper.py` - Register new modules

### Acceptance Criteria

- [ ] `types.NotImplementedType` maps to `Any`
- [ ] `NotImplemented` constant defined
- [ ] `builtins.list[T]` maps to `[]T`
- [ ] `builtins.dict[K,V]` maps to `map[K]V`
- [ ] `__dict__` attribute access works
- [ ] No `builtins.*` or `types.*` in generated V code
- [ ] test_abc.v compiles without module errors
- [ ] At least 10 affected tests fixed

### Example Mappings

| Python | Current V (Broken) | Expected V |
|--------|-------------------|------------|
| `types.NotImplementedType` | `types.NotImplementedType` | `Any` |
| `NotImplemented` | `NotImplemented` | `none` |
| `builtins.list[int]` | `builtins.list[int]` | `[]int` |
| `builtins.dict[str, int]` | `builtins.dict[str, int]` | `map[string]int` |
| `builtins.object` | `builtins.object` | `Any` |
| `obj.__dict__` | `obj.__dict__` | `obj.__dict__` (with field) |
| `'key' in obj.__dict__` | `'key' in obj.__dict__` | `'key' in obj.__dict__.keys()` |

### Related Issues

- #375: Implement ABC (Abstract Base Class) Support
- #350: Fix Missing Module Imports in Generated V Code
- #351: Fix Invalid Type Syntax in Generated V Code

### Priority

**High** - These modules are fundamental to Python's runtime introspection and type system. Missing mappings block transpilation of any code using:
- Metaclasses and `__subclasshook__`
- Runtime type inspection
- Dynamic attribute access
- Generic type annotations with `builtins.*`

### References

- [Python types module](https://docs.python.org/3/library/types.html)
- [Python builtins module](https://docs.python.org/3/library/builtins.html)
- [Python inspect module](https://docs.python.org/3/library/inspect.html)

---cut---
