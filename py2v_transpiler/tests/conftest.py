"""Pytest configuration for py2v_transpiler tests.

This file configures pytest to ignore certain directories during test collection.
"""

import pytest


import os

def pytest_collection_modifyitems(config, items):
    """Modify collected items to exclude tests from cpython and transpile directories."""
    # Filter out tests from cpython and transpile directories
    def should_exclude(path):
        parts = str(path).split(os.sep)
        return "cpython" in parts or "transpile" in parts

    items[:] = [
        item for item in items
        if not should_exclude(item.fspath)
    ]


def pytest_ignore_collect(collection_path, config):
    """Ignore the cpython and transpile directories during test collection."""
    parts = str(collection_path).split(os.sep)
    if "cpython" in parts or "transpile" in parts:
        return True
    return None
