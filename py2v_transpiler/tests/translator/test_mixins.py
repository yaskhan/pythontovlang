import pytest
from py2v_transpiler.tests.translator.utils import TranspilerTest

def test_mixin_translation():
    test = TranspilerTest()
    source = """
class AuthMixin:
    is_authenticated: bool = False
    def login(self):
        self.is_authenticated = True

class User(AuthMixin):
    username: str

    def __init__(self, username: str):
        self.username = username
"""
    # User fields:
    # is_authenticated (from AuthMixin) - mutated in login
    # username (from __init__) - assigned in __init__
    expected_v_code = """
@[heap]
struct User {
pub:
    is_authenticated bool = false
pub mut:
    username string
}

const user_new_user_annotations = { 'username': 'string' }

fn (mut self User) login() {
    self.is_authenticated = true
}

fn new_user(username string) &User {
    mut self := &User{}
    self.username = username
    return &self
}
"""
    test.assert_transpilation(source, expected_v_code)

def test_mixin_multiple_implementors():
    test = TranspilerTest()
    source = """
class BaseMixin:
    base_id = 42
    def get_id(self):
        return self.base_id

class ServiceA(BaseMixin):
    pass

class ServiceB(BaseMixin):
    pass
"""
    # In mixins, assignments in the body are currently treated as instance fields
    # when collected by collect_mixin_fields.
    expected_v_code = """
@[heap]
struct ServiceA {
pub:
    base_id int = 42
}

@[heap]
struct ServiceB {
pub:
    base_id int = 42
}

const service_a_get_id_annotations = { 'return': 'int' }
const service_b_get_id_annotations = { 'return': 'int' }

fn (self ServiceA) get_id() int {
    return self.base_id
}

fn (self ServiceB) get_id() int {
    return self.base_id
}
"""
    test.assert_transpilation(source, expected_v_code)

def test_multiple_mixins():
    test = TranspilerTest()
    source = """
class AuthMixin:
    is_authenticated: bool = False
    def login(self):
        pass

class LogMixin:
    log_level: int = 0
    def log(self, msg: str):
        pass

class SystemUser(AuthMixin, LogMixin):
    username: str
"""
    # All these are unmutated pub fields
    expected_v_code = """
@[heap]
struct SystemUser {
pub:
    is_authenticated bool = false
    log_level int = 0
    username string
}

const system_user_log_annotations = { 'msg': 'string' }

fn (self SystemUser) login() {
}

fn (self SystemUser) log(msg string) {
}
"""
    test.assert_transpilation(source, expected_v_code)
