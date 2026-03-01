from .base import TranslatorBase
from .expressions_split.calls import CallsMixin
from .expressions_split.attributes import AttributesMixin
from .expressions_split.operators import OperatorsMixin
from .expressions_split.comprehensions import ComprehensionsMixin
from .expressions_split.subscripts import SubscriptsMixin
from .expressions_split.basic import BasicExpressionsMixin

class ExpressionsMixin(
    CallsMixin,
    AttributesMixin,
    OperatorsMixin,
    ComprehensionsMixin,
    SubscriptsMixin,
    BasicExpressionsMixin,
    TranslatorBase
):
    pass
