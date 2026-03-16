"""Module for handling Python AST expressions.

This package contains modules for handling various types of expressions:
- basic: basic expressions (Name, Constant, Lambda, etc.)
- calls: function calls (split into submodules)
- operators: operators (BinOp, UnaryOp, BoolOp, Compare)
- subscripts: subscripts and slices (Subscript)
- attributes: attributes (Attribute)
- comprehensions: list/dict/set comprehensions
"""

from .basic import BasicExpressionsMixin
from .calls import CallsMixin
from .operators import OperatorsMixin
from .subscripts import SubscriptsMixin
from .attributes import AttributesMixin
from .comprehensions import ComprehensionsMixin

# Export calls submodules for possible direct use
from .calls_builtin import BuiltinCallsMixin
from .calls_methods import MethodCallsMixin
from .calls_special import SpecialCallsMixin
from .calls_classes import ClassCallsMixin
from .calls_overloads import OverloadCallsMixin
from .calls_generators import GeneratorCallsMixin
from .calls_print import PrintCallsMixin

__all__ = [
    # Main mixins
    'BasicExpressionsMixin',
    'CallsMixin',
    'OperatorsMixin',
    'SubscriptsMixin',
    'AttributesMixin',
    'ComprehensionsMixin',
    # Calls submodules
    'BuiltinCallsMixin',
    'MethodCallsMixin',
    'SpecialCallsMixin',
    'ClassCallsMixin',
    'OverloadCallsMixin',
    'GeneratorCallsMixin',
    'PrintCallsMixin',
]
