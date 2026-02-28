class TranspilerConfig:
    def __init__(self, strict_types: bool = False, output_dir: str = "output", mypy_enabled: bool = True, warn_dynamic: bool = False):
        self.strict_types = strict_types
        self.output_dir = output_dir
        self.mypy_enabled = mypy_enabled
        self.warn_dynamic = warn_dynamic
