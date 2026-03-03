from .base import TranslatorBase
from .expressions_split.calls import CallsMixin
from .expressions_split.attributes import AttributesMixin
from .expressions_split.operators import OperatorsMixin
from .expressions_split.comprehensions import ComprehensionsMixin
from .expressions_split.subscripts import SubscriptsMixin
from .expressions_split.basic import BasicExpressionsMixin
from .control_flow_split.loops import LoopsMixin
from .control_flow_split.conditionals import ConditionalsMixin
from .control_flow_split.exceptions import ExceptionsMixin
from .control_flow_split.context import ContextMixin
from .control_flow_split.control import ControlMixin
from .control_flow_split.match import MatchMixin

class ExpressionsMixin(
    CallsMixin,
    AttributesMixin,
    OperatorsMixin,
    ComprehensionsMixin,
    SubscriptsMixin,
    BasicExpressionsMixin,
    LoopsMixin,
    ConditionalsMixin,
    ExceptionsMixin,
    ContextMixin,
    ControlMixin,
    MatchMixin,
    TranslatorBase
):
    pass
