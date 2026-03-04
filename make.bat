@echo off

if "%1" == "test" goto test
if "%1" == "mypy-stubs" goto mypy_stubs
if "%1" == "test-all" goto test_all

echo Usage: make.bat [test^|mypy-stubs^|test-all]
goto :eof

:test
pytest
goto :eof

:mypy_stubs
python py2v_transpiler/tests/scripts/generate_mypy_stubs_tests.py
echo Checking generated mypy stubs...
for /D %%d in (py2v_transpiler\tests\output\mypy_stubs\*) do (
    echo Checking %%d
    v -check "%%d" || ver>nul
)
goto :eof

:test_all
call :test
call :mypy_stubs
goto :eof
