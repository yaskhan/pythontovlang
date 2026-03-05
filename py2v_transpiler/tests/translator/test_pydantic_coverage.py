import sys
import os
import pytest
from py2v_transpiler.core.parser import PyASTParser
from py2v_transpiler.core.translator import VNodeVisitor
from py2v_transpiler.core.analyzer import TypeInference

def test_pydantic_full_coverage():
    test_codes = [
        """
from pydantic import BaseModel, Field, PrivateAttr, field_validator, model_validator, validator, ConfigDict

class User(BaseModel):
    id: int
    name: str = Field(alias='userName', max_length=50, min_length=2, pattern='^[A-Z]')
    age: int = Field(gt=0, lt=150, ge=18, le=100, multiple_of=1, default=18)
    _secret: str = PrivateAttr(default='password')

    model_config = ConfigDict(extra='forbid')

    @field_validator('name')
    @classmethod
    def name_must_be_capitalized(cls, v: str) -> str:
        return v.capitalize()

    @model_validator(mode='after')
    def check_something(self) -> 'User':
        return self

class Config:
    populate_by_name = True
        """,
        """
from typing import Generic, TypeVar
from pydantic import BaseModel
T = TypeVar('T')
class Box(BaseModel, Generic[T]):
    content: T
        """
    ]

    parser = PyASTParser()
    for code in test_codes:
        tree = parser.parse(code)
        ti = TypeInference()
        ti.run_mypy(code)
        visitor = VNodeVisitor(ti)
        visitor.visit(tree)
        visitor.emitter.emit()
