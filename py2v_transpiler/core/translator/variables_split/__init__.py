from ..base import TranslatorBase
from .assignments import AssignmentsMixin
from .aug_assign import AugAssignMixin
from .delete import DeleteMixin
from .annotations import AnnotationsMixin
from .names import NamesMixin
from .type_alias import TypeAliasMixin

class VariablesMixin(
    AssignmentsMixin,
    AugAssignMixin,
    DeleteMixin,
    AnnotationsMixin,
    NamesMixin,
    TypeAliasMixin,
    TranslatorBase
):
    pass
