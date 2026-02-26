from typing import List, Optional
from .base import Translator
from .models import VNode

def test_del_multiple():
    translator = Translator()
    code = "del a, b"
    v_code = translator.translate(code)
    assert "/* del a */" in v_code
    assert "/* del b */" in v_code

def test_bitwise_ops():
    translator = Translator()
    code = "c = a & b | d ^ e"
    v_code = translator.translate(code)
    assert "&" in v_code
    assert "|" in v_code
    assert "^" in v_code

def test_if_exp():
    translator = Translator()
    code = "x = 1 if y else 2"
    v_code = translator.translate(code)
    assert "if y { 1 } else { 2 }" in v_code

def test_dataclass():
    translator = Translator()
    code = """
from dataclasses import dataclass

@dataclass
class Point:
    x: int
    y: int

p = Point(1, 2)
"""
    v_code = translator.translate(code)
    assert "struct Point {" in v_code
    assert "x int" in v_code
    assert "y int" in v_code
    assert "Point{x: 1, y: 2}" in v_code
