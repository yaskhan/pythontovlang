class TranspilerConfig:
    def __init__(self, strict_types: bool = False, output_dir: str = "output", mypy_enabled: bool = True, warn_dynamic: bool = False, no_helpers: bool = False, helpers_only: bool = False, include_all_symbols: bool = False, strict_export_mode: bool = False):
        self.strict_types = strict_types
        self.output_dir = output_dir
        self.mypy_enabled = mypy_enabled
        self.warn_dynamic = warn_dynamic
        self.no_helpers = no_helpers
        self.helpers_only = helpers_only
        self.include_all_symbols = include_all_symbols
        self.strict_export_mode = strict_export_mode
