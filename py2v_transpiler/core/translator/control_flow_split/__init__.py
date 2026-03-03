from ..base import TranslatorBase
from .loops import LoopsMixin
from .conditionals import ConditionalsMixin
from .exceptions import ExceptionsMixin
from .context import ContextMixin
from .control import ControlMixin
from .match import MatchMixin

class ControlFlowMixin(
    LoopsMixin,
    ConditionalsMixin,
    ExceptionsMixin,
    ContextMixin,
    ControlMixin,
    MatchMixin,
    TranslatorBase
):
    pass
