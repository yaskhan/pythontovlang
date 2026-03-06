"""Pytest configuration for py2v_transpiler tests.

This file configures pytest to ignore certain directories during test collection.
"""

import pytest


def pytest_collection_modifyitems(config, items):
    """Modify collected items to exclude tests from cpython directory."""
    # Filter out tests from cpython directory
    items[:] = [
        item for item in items
        if "cpython" not in str(item.fspath)
    ]


def pytest_ignore_collect(collection_path, config):
    """Ignore the cpython directory during test collection."""
    if "cpython" in str(collection_path):
        return True
    return None
