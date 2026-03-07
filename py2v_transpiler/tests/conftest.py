"""Pytest configuration for py2v_transpiler tests.

This file configures pytest to ignore certain directories during test collection.
"""

import pytest


import os

def pytest_collection_modifyitems(config, items):
    """Modify collected items to exclude tests from input directory."""
    # Filter out tests from input directory (cpython, transpile, tr)
    items[:] = [
        item for item in items
        if f"{os.sep}input{os.sep}" not in str(item.fspath)
    ]


def pytest_ignore_collect(collection_path, config):
    """Ignore the input directory during test collection."""
    if f"{os.sep}input{os.sep}" in str(collection_path):
        return True
    return None
