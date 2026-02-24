class TranspilerConfig:
    def __init__(self, strict_types: bool = False, output_dir: str = "output", mypy_enabled: bool = True):
        self.strict_types = strict_types
        self.output_dir = output_dir
        self.mypy_enabled = mypy_enabled
