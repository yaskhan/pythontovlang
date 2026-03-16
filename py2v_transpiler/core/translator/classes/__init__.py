"""Classes module for handling Python class definitions."""

import ast
from typing import TYPE_CHECKING

from .class_definition import ClassDefinitionHandler
from .class_decorators import ClassDecoratorHandler
from .class_fields import ClassFieldsHandler
from .class_bases import ClassBasesHandler
from .class_methods import ClassMethodsHandler
from .special_classes import SpecialClassesHandler
from .pydantic_handler import PydanticClassHandler

if TYPE_CHECKING:
    from .base import TranslatorBase


class ClassesMixin:
    """Mixin for handling class definitions in Python to V translation."""

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        """Visit a class definition node."""
        # Initialize handlers if not already done
        if not hasattr(self, "_class_handlers_initialized"):
            self.class_definition_handler = ClassDefinitionHandler(self)
            self.class_decorator_handler = ClassDecoratorHandler(self)
            self.class_fields_handler = ClassFieldsHandler(self)
            self.class_bases_handler = ClassBasesHandler(self)
            self.class_methods_handler = ClassMethodsHandler(self)
            self.special_classes_handler = SpecialClassesHandler(self)
            self.pydantic_handler = PydanticClassHandler(self)
            self._class_handlers_initialized = True

        self.class_definition_handler.visit_ClassDef(node)
