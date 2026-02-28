import ast
from mypy import api

result, error, exit_code = api.run(['test_mypy.py', '--show-traceback'])
print(f"Result: {result}")
print(f"Error: {error}")
print(f"Exit code: {exit_code}")
