import ast
from .state import TranslatorStateMixin
from .naming import NamingMixin
from .precedence import PrecedenceMixin
from .generics import GenericsMixin
from .type_utils import TypeUtilsMixin
from .type_registration import TypeRegistrationMixin
from .expression_utils import ExpressionUtilsMixin
from .type_guessing import TypeGuessingMixin


class TranslatorBase(
    ast.NodeVisitor,
    TranslatorStateMixin,
    NamingMixin,
    PrecedenceMixin,
    GenericsMixin,
    TypeUtilsMixin,
    TypeRegistrationMixin,
    ExpressionUtilsMixin,
    TypeGuessingMixin,
):
    """
    Base class for VNodeVisitor and its mixins.
    Defines shared state and helper methods by combining focused mixins.
    """
    pass
