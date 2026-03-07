module main

import abc
import _py_abc
import div72.vexc

// @line: test_abc.py:25:12
// Metaclass: abc_ABCMeta
pub struct TestLegacyAPI_C {
}
// @line: test_abc.py:29:12
pub struct TestLegacyAPI_D {
    C
}
// @line: test_abc.py:43:12
// Metaclass: abc_ABCMeta
pub struct TestLegacyAPI_C {
}
// @line: test_abc.py:47:12
pub struct TestLegacyAPI_D {
    C
}
// @line: test_abc.py:61:12
// Metaclass: abc_ABCMeta
pub struct TestLegacyAPI_C {
}
// @line: test_abc.py:65:12
pub struct TestLegacyAPI_D {
    C
}
// @line: test_abc.py:76:12

pub interface TestABC_C {
    foo()
}

// @line: test_abc.py:82:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:107:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:126:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:146:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:175:16
// Metaclass: abc_ABCMeta
pub struct TestABC_C {
}
// @line: test_abc.py:182:16
pub struct TestABC_D {
    C
}
// @line: test_abc.py:187:16
pub struct TestABC_E {
    D
}
// @line: test_abc.py:192:16
pub struct TestABC_F {
    E
}
// @line: test_abc.py:208:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:212:12
pub struct TestABC_E {
    D
}
// @line: test_abc.py:218:12
pub struct TestABC_NotBool {
}
// @line: test_abc.py:223:16
pub struct TestABC_F {
    C
}
// @line: test_abc.py:231:12
pub struct TestABC_Descriptor {
    _fget Any
    _fset Any
}
// @line: test_abc.py:251:12
pub struct TestABC_D {
    C
}
// @line: test_abc.py:255:12
pub struct TestABC_E {
    D
}
// @line: test_abc.py:262:12

// Metaclass: abc_ABCMeta

pub interface TestABC_A {
    x()
}

// @line: test_abc.py:267:12
pub struct TestABC_Meta {
    type
    A
}
// @line: test_abc.py:270:12
// Metaclass: meta
pub struct TestABC_C {
}
// @line: test_abc.py:274:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:276:12
pub struct TestABC_B {
}
// @line: test_abc.py:289:12
pub struct TestABC_C {
    B
}
// @line: test_abc.py:298:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:301:12
// @A.register
pub struct TestABC_B {
}
// @line: test_abc.py:309:12
// @A.register
pub struct TestABC_C {
    B
}
// @line: test_abc.py:319:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:321:12
pub struct TestABC_B {
}
// @line: test_abc.py:334:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:341:12
pub struct TestABC_B {
    A
}
// @line: test_abc.py:344:12
pub struct TestABC_C {
    Str
}
// @line: test_abc.py:353:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:356:12
pub struct TestABC_A1 {
    A
}
// @line: test_abc.py:359:12
pub struct TestABC_B {
}
// @line: test_abc.py:363:12
pub struct TestABC_C {
    A
}
// @line: test_abc.py:370:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:376:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:380:12
// Metaclass: abc_ABCMeta
pub struct TestABC_B {
}
// @line: test_abc.py:386:12
// Metaclass: abc_ABCMeta
pub struct TestABC_C {
}
// @line: test_abc.py:389:12
pub struct TestABC_B1 {
    B
}
// @line: test_abc.py:393:12
pub struct TestABC_C1 {
    C
}
// @line: test_abc.py:407:12
pub struct TestABC_MyInt {
    Int
}
// @line: test_abc.py:415:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:426:12
pub struct TestABC_C {
}
// @line: test_abc.py:442:16
// Metaclass: abc_ABCMeta
pub struct TestABC_S {
}
// @line: test_abc.py:451:12
pub struct TestABC_CustomError {
    Exception
}
// @line: test_abc.py:457:12
// Metaclass: abc_ABCMeta
pub struct TestABC_S {
}
// @line: test_abc.py:464:12
// Metaclass: abc.ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:472:12
pub struct TestABC_B {
}
// @line: test_abc.py:476:12
pub struct TestABC_C {
}
// @line: test_abc.py:482:12
// Metaclass: abc_ABCMeta
pub struct TestABC_A {
}
// @line: test_abc.py:484:12
pub struct TestABC_B {
}
// @line: test_abc.py:489:12
pub struct TestABC_C {
    A
    B
}
// @line: test_abc.py:500:16
pub struct TestABC_Metaclass {
    type
}
// @line: test_abc.py:504:12
pub struct TestABC_A {
}
// @line: test_abc.py:505:12
pub struct TestABC_B {
}
// @line: test_abc.py:506:12
pub struct TestABC_C {
}
// @line: test_abc.py:548:12
pub struct TestABC_B {
    A
}
// @line: test_abc.py:574:12
// @abc.update_abstractmethods
// @class_decorator
pub struct TestABC_B {
    A
}
// @line: test_abc.py:581:12
pub struct TestABC_A {
}
// @line: test_abc.py:599:12
pub struct TestABC_B {
    A
}
// @line: test_abc.py:618:12
pub struct TestABC_B {
    A
}
// @line: test_abc.py:621:12
pub struct TestABC_C {
    B
}
// @line: test_abc.py:640:12
// Metaclass: abc_ABCMeta
pub struct TestABC_B {
}
// @line: test_abc.py:662:12
// Metaclass: abc_ABCMeta
pub struct TestABCWithInitSubclass_Abc_ABC {
}
// @line: test_abc.py:665:12
pub struct TestABCWithInitSubclass_ReceivesClassKwargs {
}
// @line: test_abc.py:669:12
pub struct TestABCWithInitSubclass_Receiver {
    ReceivesClassKwargs
    Abc_ABC
}
// @line: test_abc.py:676:12
pub struct TestABCWithInitSubclass_A {
}
// @line: test_abc.py:681:12
// Metaclass: abc_ABCMeta
pub struct TestABCWithInitSubclass_B {
    A
}

pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_a() !TestABC_A {
    return TestABC_A{}
}
pub fn new_test_abc_c() !TestABC_C {
    return TestABC_C{}
}
// @line: test_abc.py:15:0
pub fn test_factory(abc_ABCMeta Any, abc_get_cache_token fn (...Any) Any) Any {
// @line: test_abc.py:18:8
    mut test_abstractproperty_basics_ := fn [abc_ABCMeta] () {
        assert foo.__isabstractmethod__
// @line: test_abc.py:22:12
        mut bar := fn () {
        }
        self.assertNotHasAttr(bar, '__isabstractmethod__')
        self.assertRaises(TypeError, C)
// @property
// @line: test_abc.py:31:16
        mut foo := fn () Any {
            return super().foo
        }
        assert D().foo == 3
        assert !(D.foo.__isabstractmethod__)
    }
// @line: test_abc.py:35:8
    mut test_abstractclassmethod_basics_ := fn [abc_ABCMeta] () {
        assert foo____isabstractmethod__
// @classmethod
// @line: test_abc.py:40:12
        mut _bar := fn () {
        }
        assert !(bar.__isabstractmethod__)
        self.assertRaises(TypeError, C)
// @classmethod
// @line: test_abc.py:49:16
        mut _foo := fn () Any {
            return self.C.foo()
        }
        assert D.foo() == 'D'
        assert D().foo() == 'D'
    }
// @line: test_abc.py:53:8
    mut test_abstractstaticmethod_basics_ := fn [abc_ABCMeta] () {
        assert foo____isabstractmethod__
// @staticmethod
// @line: test_abc.py:58:12
        mut _bar := fn () {
        }
        assert !(bar.__isabstractmethod__)
        self.assertRaises(TypeError, C)
// @staticmethod
// @line: test_abc.py:67:16
        mut _foo := fn () Any {
            return 4
        }
        assert D.foo() == 4
        assert D().foo() == 4
    }
// @line: test_abc.py:74:8
    mut test_ABC_helper_ := fn () {
        assert typeof(C).name == abc.ABCMeta
        self.assertRaises(TypeError, C)
// @classmethod
// @line: test_abc.py:84:16
        mut _foo := fn () Any {
            return self.C.foo()
        }
        assert D.foo() == 'D'
    }
// @line: test_abc.py:87:8
    mut test_abstractmethod_basics_ := fn () {
        assert foo____isabstractmethod__
// @line: test_abc.py:91:12
        mut bar := fn () {
        }
        self.assertNotHasAttr(bar, '__isabstractmethod__')
    }
// @line: test_abc.py:94:8
    mut test_abstractproperty_basics_ = fn [abc_ABCMeta] () {
        assert foo____isabstractmethod__
// @line: test_abc.py:99:12
        mut bar := fn () {
        }
        assert !(bar.__isabstractmethod__)
        self.assertRaises(TypeError, C)
// @C.foo.getter
// @line: test_abc.py:109:16
        mut foo := fn () Any {
            return super().foo
        }
        assert D().foo == 3
    }
// @line: test_abc.py:112:8
    mut test_abstractclassmethod_basics_ = fn [abc_ABCMeta] () {
        assert foo____isabstractmethod__
// @classmethod
// @line: test_abc.py:118:12
        mut _bar := fn () {
        }
        assert !(bar.__isabstractmethod__)
        self.assertRaises(TypeError, C)
// @classmethod
// @line: test_abc.py:128:16
        mut _foo := fn () Any {
            return self.C.foo()
        }
        assert D.foo() == 'D'
        assert D().foo() == 'D'
    }
// @line: test_abc.py:132:8
    mut test_abstractstaticmethod_basics_ = fn [abc_ABCMeta] () {
        assert foo____isabstractmethod__
// @staticmethod
// @line: test_abc.py:138:12
        mut _bar := fn () {
        }
        assert !(bar.__isabstractmethod__)
        self.assertRaises(TypeError, C)
// @staticmethod
// @line: test_abc.py:148:16
        mut _foo := fn () Any {
            return 4
        }
        assert D.foo() == 4
        assert D().foo() == 4
    }
// @line: test_abc.py:152:8
    mut test_object_new_with_one_abstractmethod_ := fn [abc_ABCMeta] () {
        mut msg := 'class C without an implementation for abstract method \'method_one\''
        self.assertRaisesRegex(TypeError, msg, C)
    }
// @line: test_abc.py:160:8
    mut test_object_new_with_many_abstractmethods_ := fn [abc_ABCMeta] () {
        mut msg := 'class C without an implementation for abstract methods \'method_one\', \'method_two\''
        self.assertRaisesRegex(TypeError, msg, C)
    }
// @line: test_abc.py:171:8
    mut test_abstractmethod_integration_ := fn [abc_ABCMeta] () {
        for abstractthing in [abc.abstractmethod, abc.abstractproperty, abc.abstractclassmethod, abc.abstractstaticmethod] {
// @abstractthing
// @line: test_abc.py:177:20
            mut foo := fn () Any {
            }
// @line: test_abc.py:178:20
            mut bar := fn () {
            }
            assert C.__abstractmethods__ == {'foo': true}
            self.assertRaises(TypeError, C)
            assert inspect.isabstract(C)
// @line: test_abc.py:183:20
            mut bar = fn () {
            }
            assert D.__abstractmethods__ == {'foo': true}
            self.assertRaises(TypeError, D)
            assert inspect.isabstract(D)
// @line: test_abc.py:188:20
            mut foo = fn () Any {
            }
            assert E.__abstractmethods__ == map[Any]bool{}
            E()
            assert !(inspect.isabstract(E))
// @abstractthing
// @line: test_abc.py:194:20
            mut bar = fn () {
            }
            assert F.__abstractmethods__ == {'bar': true}
            self.assertRaises(TypeError, F)
            assert inspect.isabstract(F)
        }
    }
// @line: test_abc.py:199:8
    mut test_descriptors_with_abstractmethod_ := fn [abc_ABCMeta] () {
        self.assertRaises(TypeError, C)
// @C.foo.getter
// @line: test_abc.py:210:16
        mut foo := fn () Any {
            return super().foo
        }
        self.assertRaises(TypeError, D)
// @D.foo.setter
// @line: test_abc.py:214:16
        mut set_foo := fn (val Any) Any {
        }
        assert E().foo == 3
// @line: test_abc.py:219:16
        mut __bool__ := fn () {
            vexc.raise('ValueError', '')
        }
        ctx_mgr_0 := self.assertRaises(ValueError)
        defer { ctx_mgr_0.exit(none, none, none) }
        ctx_mgr_0.enter()
// @line: test_abc.py:224:20
        mut bar := fn () {
        }
    }
// @line: test_abc.py:230:8
    mut test_customdescriptors_with_abstractmethod_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:232:16
        mut new_ := fn (fget Any, fset Any)  {
            mut self := {}
            self._fget = fget
            self._fset = fset
            return self
        }
// @line: test_abc.py:235:16
        mut getter := fn (callable Any) Any {
            return Descriptor(callable, self._fget)
        }
// @line: test_abc.py:237:16
        mut setter := fn (callable Any) Any {
            return Descriptor(self._fget, callable)
        }
// @property
// @line: test_abc.py:240:16
        mut __isabstractmethod__ := fn () Any {
            return self._fget.__isabstractmethod__ || self._fset.__isabstractmethod__
        }
        self.assertRaises(TypeError, C)
// @C.foo.getter
// @line: test_abc.py:253:16
        mut foo := fn () Any {
            return super().foo
        }
        self.assertRaises(TypeError, D)
// @D.foo.setter
// @line: test_abc.py:257:16
        mut set_foo := fn (val Any) Any {
        }
        assert !(E.foo.__isabstractmethod__)
    }
// @line: test_abc.py:260:8
    mut test_metaclass_abc_ := fn [abc_ABCMeta] () {
        assert A.__abstractmethods__ == {'x': true}
// @line: test_abc.py:268:16
        mut x := fn () int {
            return 1
        }
    }
// @line: test_abc.py:273:8
    mut test_registration_basics_ := fn [abc_ABCMeta] () {
        mut b := B()
        self.assertNotIsSubclass(B, A)
        self.assertNotIsSubclass(B, [A])
        self.assertNotIsInstance(b, A)
        self.assertNotIsInstance(b, [A])
        b1 := A.register(B)
        self.assertIsSubclass(B, A)
        self.assertIsSubclass(B, [A])
        self.assertIsInstance(b, A)
        self.assertIsInstance(b, [A])
        assert B1 == B
        mut c := C()
        self.assertIsSubclass(C, A)
        self.assertIsSubclass(C, [A])
        self.assertIsInstance(c, A)
        self.assertIsInstance(c, [A])
    }
// @line: test_abc.py:297:8
    mut test_register_as_class_deco_ := fn [abc_ABCMeta] () {
        mut b := B()
        self.assertIsSubclass(B, A)
        self.assertIsSubclass(B, [A])
        self.assertIsInstance(b, A)
        self.assertIsInstance(b, [A])
        mut c := C()
        self.assertIsSubclass(C, A)
        self.assertIsSubclass(C, [A])
        self.assertIsInstance(c, A)
        self.assertIsInstance(c, [A])
        assert C == A.register(C)
    }
// @line: test_abc.py:318:8
    mut test_isinstance_invalidation_ := fn [abc_ABCMeta, abc_get_cache_token] () {
        mut b := B()
        self.assertNotIsInstance(b, A)
        self.assertNotIsInstance(b, [A])
        token_old := abc_get_cache_token()
        A.register(B)
        token_new := abc_get_cache_token()
        self.assertGreater(token_new, token_old)
        self.assertIsInstance(b, A)
        self.assertIsInstance(b, [A])
    }
// @line: test_abc.py:333:8
    mut test_registration_builtins_ := fn [abc_ABCMeta] () {
        A.register(int)
        self.assertIsInstance(42, A)
        self.assertIsInstance(42, [A])
        self.assertIsSubclass(int, A)
        self.assertIsSubclass(int, [A])
        B.register(str)
        self.assertIsInstance('', A)
        self.assertIsInstance('', [A])
        self.assertIsSubclass(str, A)
        self.assertIsSubclass(str, [A])
        self.assertIsSubclass(C, A)
        self.assertIsSubclass(C, [A])
    }
// @line: test_abc.py:352:8
    mut test_registration_edge_cases_ := fn [abc_ABCMeta] () {
        A.register(A)
        self.assertRaises(RuntimeError, A1.register, A)
        A1.register(B)
        A1.register(B)
        A.register(C)
        self.assertRaises(RuntimeError, C.register, A)
        C.register(B)
    }
// @line: test_abc.py:369:8
    mut test_register_non_class_ := fn [abc_ABCMeta] () {
        self.assertRaisesRegex(TypeError, 'Can only register classes', A.register, 4)
    }
// @line: test_abc.py:375:8
    mut test_registration_transitiveness_ := fn [abc_ABCMeta] () {
        self.assertIsSubclass(A, A)
        self.assertIsSubclass(A, [A])
        self.assertNotIsSubclass(A, B)
        self.assertNotIsSubclass(A, [B])
        self.assertNotIsSubclass(B, A)
        self.assertNotIsSubclass(B, [A])
        A.register(B)
        self.assertIsSubclass(B1, A)
        self.assertIsSubclass(B1, [A])
        B1.register(C1)
        self.assertNotIsSubclass(C, B)
        self.assertNotIsSubclass(C, [B])
        self.assertNotIsSubclass(C, B1)
        self.assertNotIsSubclass(C, [B1])
        self.assertIsSubclass(C1, A)
        self.assertIsSubclass(C1, [A])
        self.assertIsSubclass(C1, B)
        self.assertIsSubclass(C1, [B])
        self.assertIsSubclass(C1, B1)
        self.assertIsSubclass(C1, [B1])
        C1.register(int)
        self.assertIsSubclass(MyInt, A)
        self.assertIsSubclass(MyInt, [A])
        self.assertIsInstance(42, A)
        self.assertIsInstance(42, [A])
    }
// @line: test_abc.py:414:8
    mut test_issubclass_bad_arguments_ := fn [abc_ABCMeta] () {
        ctx_mgr_1 := self.assertRaises(TypeError)
        defer { ctx_mgr_1.exit(none, none, none) }
        ctx_mgr_1.enter()
        issubclass(map[string]Any{}, A)
        ctx_mgr_2 := self.assertRaises(TypeError)
        defer { ctx_mgr_2.exit(none, none, none) }
        ctx_mgr_2.enter()
        issubclass(42, A)
        ctx_mgr_3 := self.assertRaises(TypeError)
        defer { ctx_mgr_3.exit(none, none, none) }
        ctx_mgr_3.enter()
        issubclass(C(), A)
        mut bogus_subclasses := []Any{cap: 4}
        bogus_subclasses << none
        bogus_subclasses << fn (x int) []Any { return []Any{} }
        bogus_subclasses << fn () int { return 42 }
        bogus_subclasses << fn () []int { return [42] }
        for i, func in bogus_subclasses {
            ctx_mgr_4 := self.subTest()
            defer { ctx_mgr_4.exit(none, none, none) }
            ctx_mgr_4.enter()
            ctx_mgr_5 := self.assertRaises(TypeError)
            defer { ctx_mgr_5.exit(none, none, none) }
            ctx_mgr_5.enter()
            issubclass(int, S)
        }
        exc_msg := 'exception from __subclasses__'
// @line: test_abc.py:454:12
        mut raise_exc := fn [exc_msg] () {
            vexc.raise('CustomError', 'exc_msg')
        }
        ctx_mgr_6 := self.assertRaisesRegex(CustomError, exc_msg)
        defer { ctx_mgr_6.exit(none, none, none) }
        ctx_mgr_6.enter()
        issubclass(int, S)
    }
// @line: test_abc.py:463:8
    mut test_subclasshook_ := fn () {
// @classmethod
// @line: test_abc.py:466:16
        mut ___subclasshook__ := fn (C fn (...Any) Any) Any {
            if TestABC_A == A {
                return 'foo' in C.__dict__
            }
            return NotImplemented
        }
        self.assertNotIsSubclass(A, A)
        self.assertNotIsSubclass(A, [A])
        self.assertIsSubclass(B, A)
        self.assertIsSubclass(B, [A])
        self.assertNotIsSubclass(C, A)
        self.assertNotIsSubclass(C, [A])
    }
// @line: test_abc.py:481:8
    mut test_all_new_methods_are_called_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:486:16
        mut new_ := fn () Any {
            B.counter += 1
            return /* super().__new__ call without known parent */
        }
        assert B.counter == 0
        C()
        assert B.counter == 1
    }
// @line: test_abc.py:495:8
    mut test_ABC_has___slots___ := fn () {
        self.assertHasAttr(abc.ABC, '__slots__')
    }
// @line: test_abc.py:498:8
    mut test_tricky_new_works_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:499:12
        mut with_metaclass := fn (meta fn (...Any) Any, bases ...int) Any {
// @line: test_abc.py:501:20
            mut new_ := fn [bases, meta] (name Any, this_bases Any, d Any) Any {
                return meta(name, bases, d)
            }
            return py_type.__new__(metaclass, 'temporary_class', [], map[string]Any{})
        }
        assert typeof(C) == abc_ABCMeta
    }
// @line: test_abc.py:510:8
    mut test_update_del_ := fn [abc_ABCMeta] () {
        /* del A.foo */
        assert A.__abstractmethods__ == {'foo': true}
        self.assertNotHasAttr(A, 'foo')
        abc.update_abstractmethods(A)
        assert A.__abstractmethods__ == map[Any]bool{}
        A()
    }
// @line: test_abc.py:526:8
    mut test_update_new_abstractmethods_ := fn [abc_ABCMeta] () {
        A.foo = updated_foo
        abc.update_abstractmethods(A)
        assert A.__abstractmethods__ == {'foo': true, 'bar': true}
        mut msg := 'class A without an implementation for abstract methods \'bar\', \'foo\''
        self.assertRaisesRegex(TypeError, msg, A)
    }
// @line: test_abc.py:542:8
    mut test_update_implementation_ := fn [abc_ABCMeta] () {
        mut msg := 'class B without an implementation for abstract method \'foo\''
        self.assertRaisesRegex(TypeError, msg, B)
        assert B.__abstractmethods__ == {'foo': true}
        B.foo = fn (self int) Any { return none }
        abc.update_abstractmethods(B)
        B()
        assert B.__abstractmethods__ == map[Any]bool{}
    }
// @line: test_abc.py:562:8
    mut test_update_as_decorator_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:568:12
        mut class_decorator := fn () Any {
            cls.foo = fn (self int) Any { return none }
            return cls
        }
        B()
        assert B.__abstractmethods__ == map[Any]bool{}
    }
// @line: test_abc.py:580:8
    mut test_update_non_abc_ := fn () {
        A.foo = updated_foo
        abc.update_abstractmethods(A)
        A()
        self.assertNotHasAttr(A, '__abstractmethods__')
    }
// @line: test_abc.py:593:8
    mut test_update_del_implementation_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:600:16
        mut foo := fn () Any {
        }
        B()
        /* del B.foo */
        abc.update_abstractmethods(B)
        mut msg := 'class B without an implementation for abstract method \'foo\''
        self.assertRaisesRegex(TypeError, msg, B)
    }
// @line: test_abc.py:612:8
    mut test_update_layered_implementation_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:622:16
        mut foo := fn () Any {
        }
        C()
        /* del C.foo */
        abc.update_abstractmethods(C)
        mut msg := 'class C without an implementation for abstract method \'foo\''
        self.assertRaisesRegex(TypeError, msg, C)
    }
// @line: test_abc.py:634:8
    mut test_update_multi_inheritance_ := fn [abc_ABCMeta] () {
// @line: test_abc.py:641:16
        mut foo := fn () Any {
        }
        assert C.__abstractmethods__ == {'foo': true}
        /* del C.foo */
        abc.update_abstractmethods(C)
        assert C.__abstractmethods__ == map[Any]bool{}
        C()
    }
// @line: test_abc.py:661:8
    mut test_works_with_init_subclass_ := fn [abc_ABCMeta] () {
        mut saved_kwargs := map[string]Any{}
// @line: test_abc.py:666:16
        mut init_subclass := fn [saved_kwargs] (kwargs map[string]string) {
            /* super().__init_subclass__ call without known parent */
            saved_kwargs.update(kwargs)
        }
        assert saved_kwargs == map[string]Any{}
    }
// @line: test_abc.py:673:8
    mut test_positional_only_and_kwonlyargs_with_init_subclass_ := fn [abc_ABCMeta] () {
        mut saved_kwargs := map[string]Any{}
// @line: test_abc.py:677:16
        mut init_subclass := fn [saved_kwargs] (kwargs map[string]string) {
            /* super().__init_subclass__ call without known parent */
            saved_kwargs.update(kwargs)
        }
        assert saved_kwargs == map[string]Any{}
    }
    return [TestLegacyAPI, TestABC, TestABCWithInitSubclass]
}

fn main() {
    // Unit tests for abc.py.
    // @line: test_abc.py:687:0
    py_destruct_7 := test_factory(_py_abc.ABCMeta, _py_abc.get_cache_token)
    TestLegacyAPI_Py := py_destruct_7[0]
    TestABC_Py := py_destruct_7[1]
    TestABCWithInitSubclass_Py := py_destruct_7[2]
    // @line: test_abc.py:689:0
    py_destruct_8 := test_factory(abc.ABCMeta, abc.get_cache_token)
    TestLegacyAPI_C := py_destruct_8[0]
    TestABC_C := py_destruct_8[1]
    TestABCWithInitSubclass_C := py_destruct_8[2]
    // @line: test_abc.py:694:0
    TestLegacyAPI_Py.__unittest_thread_unsafe__ = true
    // @line: test_abc.py:695:0
    TestABC_Py.__unittest_thread_unsafe__ = true
    // @line: test_abc.py:696:0
    TestABCWithInitSubclass_Py.__unittest_thread_unsafe__ = true
    // @line: test_abc.py:698:0
    // if __name__ == '__main__':
    // unittest.main() ignored
}