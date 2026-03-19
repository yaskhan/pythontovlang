import ast
import os
import json
import tempfile
from typing import Tuple
from py2v_transpiler.models.v_types import map_python_type_to_v
from .base import TypeInferenceBase

try:
    from mypy import api as mypy_api_module
except ImportError:
    mypy_api_module = None  # type: ignore


class TypeInferenceMypyMixin(TypeInferenceBase):
    def run_mypy(self, path: str, experimental: bool = False) -> Tuple[str, str, int]:
        """Runs mypy on the given file path and returns the output."""
        if not mypy_api_module:
            return ("Mypy not installed.", "", 1)

        # Create a temporary config file to load the plugin
        with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
            f.write("[mypy]\nplugins = py2v_transpiler.core.mypy_plugin\n")
            config_path = f.name

        # Store original PYTHONPATH to restore it later
        original_pythonpath = os.environ.get("PYTHONPATH")
        project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

        try:
            # Set PYTHONPATH so mypy can find the plugin
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = f"{project_root}{os.pathsep}{original_pythonpath}"
            else:
                os.environ["PYTHONPATH"] = project_root

            # Ensure the global dict is clean before running mypy
            try:
                import py2v_transpiler.core.mypy_plugin as m_p

                m_p._global_collected_types.clear()
                m_p._global_collected_sigs.clear()
                m_p._global_collected_mutability.clear()
            except ImportError:
                pass

            args = [path, "--config-file", config_path]
            if experimental:
                args.append("--enable-incomplete-feature=TypeForm")

            result, error, exit_code = mypy_api_module.run(args)

            collected_types = None
            collected_sigs = None
            collected_mut = None
            # First try to read from the memory (global state injected by the plugin)
            try:
                import py2v_transpiler.core.mypy_plugin as m_p

                if m_p._global_collected_types:
                    collected_types = dict(m_p._global_collected_types)
                if m_p._global_collected_sigs:
                    collected_sigs = dict(m_p._global_collected_sigs)
                if m_p._global_collected_mutability:
                    collected_mut = dict(m_p._global_collected_mutability)
            except ImportError:
                pass

            # Fallback to reading the generated types mapping from JSON
            if not collected_types and os.path.exists("types_for_vlang.json"):
                try:
                    with open("types_for_vlang.json", "r") as json_file:
                        collected_types = json.load(json_file)
                except Exception:
                    pass

            if collected_types:
                for fullname, types in collected_types.items():
                    for location, typ in types.items():
                        v_type = map_python_type_to_v(typ)
                        # Store by fullname@location and name@location for precise lookup
                        self.type_map[f"{fullname}@{location}"] = v_type
                        name = fullname.split('.')[-1]
                        self.type_map[f"{name}@{location}"] = v_type

                        # Store base type if location-less entry is missing
                        if fullname not in self.type_map:
                            self.type_map[fullname] = v_type
                        if name not in self.type_map:
                            self.type_map[name] = v_type
                            
                        # Also store raw types
                        self.raw_type_map[f"{fullname}@{location}"] = typ
                        self.raw_type_map[f"{name}@{location}"] = typ
                        if fullname not in self.raw_type_map:
                            self.raw_type_map[fullname] = typ
                        if name not in self.raw_type_map:
                            self.raw_type_map[name] = typ

                        # Populate location_map for O(1) lookups by location
                        if (
                            "builtins.float" in fullname
                            or location not in self.location_map
                        ):
                            self.location_map[location] = v_type

            if collected_sigs:
                for fullname, sigs in collected_sigs.items():
                    for location, sig_json in sigs.items():
                        try:
                            sig_data = json.loads(sig_json)
                            # the function name itself is usually enough, but we store full location too
                            self.call_signatures[f"{fullname}@{location}"] = sig_data
                            self.call_signatures[location] = sig_data
                        except Exception:
                            pass

            if collected_mut:
                for fullname, muts in collected_mut.items():
                    for location, mut_data in muts.items():
                        # Store by fullname@location and name@location for precise lookup
                        self.mutability_map[f"{fullname}@{location}"] = mut_data
                        name = fullname.split('.')[-1]
                        self.mutability_map[f"{name}@{location}"] = mut_data

            if os.path.exists("types_for_vlang.json"):
                try:
                    os.remove("types_for_vlang.json")
                except Exception:
                    pass
        finally:
            if original_pythonpath is not None:
                os.environ["PYTHONPATH"] = original_pythonpath
            elif "PYTHONPATH" in os.environ:
                del os.environ["PYTHONPATH"]

            os.remove(config_path)

        return result, error, exit_code
