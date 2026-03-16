"""
Functions translation module.
This file now acts as a bridge to the modular implementation in the 'functions_split' package.
"""

from .functions_split import (
    FunctionCommonMixin,
    FunctionVisitorMixin,
    FunctionGenerationMixin,
    FunctionOverloadMixin,
    OtherFunctionVisitorsMixin,
)


class FunctionsMixin(
    FunctionCommonMixin,
    FunctionVisitorMixin,
    FunctionGenerationMixin,
    FunctionOverloadMixin,
    OtherFunctionVisitorsMixin,
):
    """
    Combined mixin for function-related translation logic.
    Inherits from modular components in functions_split.
    """
    pass


__all__ = ["FunctionsMixin"]
