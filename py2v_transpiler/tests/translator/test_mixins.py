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
    expected_v_code = """
struct User {
    is_authenticated bool = false
    username string
}

fn (self User) login() {
    self.is_authenticated = true
}

fn new_User(username string) User {
    mut self := User{}
    self.username = username
    return self
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
    expected_v_code = """
struct ServiceA {
    base_id int = 42
}

struct ServiceB {
    base_id int = 42
}

fn (self ServiceA) get_id() {
    return self.base_id
}

fn (self ServiceB) get_id() {
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
    expected_v_code = """
struct SystemUser {
    is_authenticated bool = false
    log_level int = 0
    username string
}

fn (self SystemUser) login() {
}

fn (self SystemUser) log(msg string) {
}
"""
    test.assert_transpilation(source, expected_v_code)
