param (
    [Parameter(Position=0)]
    [string]$Target = ""
)

function Run-Test {
    pytest
}

function Run-Mypy-Stubs {
    python py2v_transpiler/tests/scripts/generate_mypy_stubs_tests.py
    Write-Host "Checking generated mypy stubs..."
    $dirs = Get-ChildItem -Path "py2v_transpiler\tests\output\mypy_stubs" -Directory
    foreach ($dir in $dirs) {
        Write-Host "Checking $($dir.FullName)"
        v -check "$($dir.FullName)"
    }
}

switch ($Target) {
    "test" {
        Run-Test
    }
    "mypy-stubs" {
        Run-Mypy-Stubs
    }
    "test-all" {
        Run-Test
        Run-Mypy-Stubs
    }
    default {
        Write-Host "Usage: .\make.ps1 [test|mypy-stubs|test-all]"
    }
}