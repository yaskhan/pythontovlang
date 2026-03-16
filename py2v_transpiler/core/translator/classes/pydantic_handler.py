"""Handler for Pydantic models in class definitions."""

import ast
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from py2v_transpiler.pydantic_support.model_processor import PydanticModelProcessor


class PydanticClassHandler:
    """Handles Pydantic model detection and processing."""

    def __init__(self, translator):
        self.translator = translator

    def handle_pydantic_model(self, node: ast.ClassDef) -> None:
        """Process a Pydantic model class."""
        from py2v_transpiler.pydantic_support.detector import PydanticDetector
        from py2v_transpiler.pydantic_support.model_processor import PydanticModelProcessor

        if PydanticDetector.is_pydantic_model(node):
            processor: PydanticModelProcessor = PydanticModelProcessor(self.translator)
            processor.process_model(node)
