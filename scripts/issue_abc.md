##title: Implement ABC (Abstract Base Class) Support for @abstractmethod and Metaclass Validation
##descr: The transpiler doesn't properly handle Python's abc module features including @abstractmethod, abstractproperty, abstractclassmethod, abstractstaticmethod, and ABCMeta metaclass validation.

### Problem
When transpiling code that uses Python's `abc` module for Abstract Base Classes, the transpiler fails to:
1. Generate proper interface/struct definitions for abstract classes
2. Handle `@abstractmethod` decorator and `__isabstractmethod__` attribute
3. Implement metaclass-based instantiation validation (TypeError for unimplemented abstract methods)
4. Support `__abstractmethods__` set tracking
5. Handle `abc.ABC` helper class
6. Support `@abc.update_abstractmethods()` function

### Analysis of test_abc.py → test_abc.v

**Python Input (test_abc.py):**
```python
import abc

class C(abc.ABC):
    @classmethod
    @abc.abstractmethod
    def foo(cls): return cls.__name__

# Should raise TypeError when instantiated
C()  # TypeError: Can't instantiate abstract class C with abstract method foo
```

**Current V Output (test_abc.v):**
```v
// Line 76-82
pub interface TestABC_C {
    foo(cls int)
}

// Line 511-517
pub interface TestABC_A {
    foo()
}

// Line 527-533
pub interface TestABC_A {
    bar()
}
```

### Identified Issues

#### 1. Incorrect Interface Method Signatures
**Problem:** Interface methods have incorrect parameter types (`cls int` instead of proper receiver).

**Current:**
```v
pub interface TestABC_C {
    foo(cls int)  // ❌ 'cls int' is not valid V
}
```

**Expected:**
```v
pub interface TestABC_C {
    foo() string  // ✅ Proper method signature
}
```

#### 2. Duplicate Interface Definitions
**Problem:** Same interface name defined multiple times with different methods.

**Current:**
```v
// Line 511
pub interface TestABC_A {
    foo()
}

// Line 527 - Duplicate!
pub interface TestABC_A {
    bar()
}
```

**Expected:** Single interface definition with all methods merged.

#### 3. Missing Abstract Method Validation
**Problem:** No runtime check to prevent instantiation of classes with unimplemented abstract methods.

**Python:**
```python
class C(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def foo(self): pass

C()  # Should raise TypeError
```

**Current V:**
```v
struct C {}
// No validation - can instantiate without foo implementation
```

**Expected V:**
```v
struct C {
    mut:
        __abstractmethods__ map[string]bool
}

fn new_C() !C {
    mut self := C{
        __abstractmethods__: {'foo': true}
    }
    if self.__abstractmethods__.len > 0 {
        return error("Can't instantiate abstract class C with abstract method 'foo'")
    }
    return self
}
```

#### 4. Missing __isabstractmethod__ Attribute
**Problem:** Decorated functions don't have `__isabstractmethod__` attribute set.

**Python:**
```python
@abc.abstractmethod
def foo(self): pass

print(foo.__isabstractmethod__)  # True
```

**Current V:**
```v
mut foo := fn () Any {
}
// No __isabstractmethod__ attribute
```

**Expected V:**
```v
mut foo := FooAbstractMethods{
    impl: fn () Any {}
    __isabstractmethod__: true
}
```

#### 5. Missing __abstractmethods__ Set
**Problem:** Classes don't track abstract methods in `__abstractmethods__` set.

**Python:**
```python
class C(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def foo(self): pass
    def bar(self): pass

print(C.__abstractmethods__)  # {'foo'}
```

**Current V:**
```v
struct C {}
// No __abstractmethods__ field
```

#### 6. Missing abc.update_abstractmethods() Support
**Problem:** Runtime update of abstract methods not supported.

**Python:**
```python
class A(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def foo(self): pass

del A.foo
abc.update_abstractmethods(A)
print(A.__abstractmethods__)  # Now empty, can instantiate
```

**Current V:** No equivalent functionality.

#### 7. Missing ABC Helper Class
**Problem:** `abc.ABC` helper class not implemented.

**Python:**
```python
class C(abc.ABC):
    @abc.abstractmethod
    def foo(self): pass
```

**Current V:** `abc.ABC` not defined in stdlib mapping.

#### 8. Missing Registration Support
**Problem:** `ABC.register()` for virtual subclass registration not implemented.

**Python:**
```python
class A(abc.ABC):
    pass

A.register(int)
isinstance(42, A)  # True
```

**Current V:** No registration mechanism.

### Root Causes

1. **No ABC metaclass handling** - `classes.py` doesn't detect `ABCMeta` metaclass
2. **No @abstractmethod decorator processing** - `decorators.py` doesn't handle abc decorators
3. **No abstract method tracking** - No mechanism to collect `__abstractmethods__` set
4. **No instantiation validation** - Factory functions don't check for abstract methods
5. **No attribute injection** - `__isabstractmethod__` not added to decorated functions

### Tasks

#### Phase 1: Core ABC Support
1. **Add ABC metaclass detection in `classes.py`**
   - Detect `metaclass=abc.ABCMeta` or `abc.ABC` base class
   - Mark class as abstract in `defined_classes`

2. **Implement @abstractmethod decorator in `decorators.py`**
   - Detect `@abc.abstractmethod`, `@abc.abstractproperty`, etc.
   - Set `__isabstractmethod__ = true` attribute

3. **Add abstract method collection**
   - Collect all methods with `__isabstractmethod__`
   - Generate `__abstractmethods__` set for class

4. **Implement instantiation validation**
   - Modify factory functions to check `__abstractmethods__`
   - Return error if abstract methods present

#### Phase 2: Advanced Features
5. **Add abc.ABC helper class**
   - Map to V interface or abstract struct
   - Set `ABCMeta` as metaclass

6. **Implement abc.update_abstractmethods()**
   - Recalculate `__abstractmethods__` set
   - Allow/deny instantiation based on update

7. **Add ABC.register() support**
   - Virtual subclass registration
   - Update `isinstance`/`issubclass` checks

8. **Support abstract classmethod/staticmethod**
   - Handle `@abc.abstractclassmethod`
   - Handle `@abc.abstractstaticmethod`

### Files to Modify

**Core Transpiler:**
- `py2v_transpiler/core/translator/classes.py` - ABC metaclass detection
- `py2v_transpiler/core/translator/functions.py` - Abstract method handling
- `py2v_transpiler/core/decorators.py` - @abstractmethod decorator
- `py2v_transpiler/stdlib_map/abc.v` - ABC module mapping (new file)

**Tests:**
- `py2v_transpiler/tests/translator/test_abc.py` - ABC test suite (new file)
- `py2v_transpiler/tests/input/cpython/test_abc.py` - Enable CPython test

### Acceptance Criteria

- [ ] Abstract classes generate proper V interfaces/structs
- [ ] @abstractmethod sets `__isabstractmethod__` attribute
- [ ] Classes track `__abstractmethods__` set
- [ ] Factory functions prevent instantiation with abstract methods
- [ ] abc.ABC helper class works correctly
- [ ] abc.update_abstractmethods() implemented
- [ ] ABC.register() for virtual subclasses
- [ ] abstractclassmethod/staticmethod supported
- [ ] test_abc.py compiles without errors
- [ ] At least 80% of CPython test_abc.py tests pass

### Priority

**High** - ABC is a core Python feature used in many libraries and frameworks. Lack of ABC support blocks transpilation of production code that uses abstract base classes for interfaces and APIs.

### Related Issues

- #336: Fix Method Overload Handling (@overload) for __init__ Methods in Generic Classes
- #341: Fix Generic Receiver Parameter Issue in @classmethod Generation
- #342: Fix Factory Function Naming to Follow V snake_case Conventions

### Example Test Cases

```python
# Test 1: Basic abstract class
import abc

class Animal(abc.ABC):
    @abc.abstractmethod
    def speak(self) -> str:
        pass

# Should fail
# Animal()  # TypeError

class Dog(Animal):
    def speak(self) -> str:
        return "Woof!"

# Should succeed
Dog()  # OK
```

```v
// Expected V output
pub interface Animal {
    speak() string
}

pub struct Dog {
    Animal
}

pub fn Dog_speak(self Dog) string {
    return 'Woof!'
}

pub fn new_Animal() !Animal {
    return error("Can't instantiate abstract class Animal with abstract method 'speak'")
}

pub fn new_Dog() Dog {
    return Dog{}
}
```

### References

- [Python abc module documentation](https://docs.python.org/3/library/abc.html)
- [PEP 3119 - Introducing Abstract Base Classes](https://peps.python.org/pep-3119/)
- [test_abc.py - CPython test suite](https://github.com/python/cpython/blob/main/Lib/test/test_abc.py)

---cut---
