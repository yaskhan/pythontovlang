from .common import FunctionCommonMixin
from .overloads import FunctionOverloadMixin
from .generation import FunctionGenerationMixin
from .visitor import FunctionVisitorMixin
from .other_visitors import OtherFunctionVisitorsMixin


class FunctionsMixin(
    FunctionCommonMixin,
    FunctionOverloadMixin,
    FunctionGenerationMixin,
    FunctionVisitorMixin,
    OtherFunctionVisitorsMixin,
):
    """
    Combined mixin for function translation.
    """
    pass
