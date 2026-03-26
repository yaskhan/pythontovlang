from typing import LiteralString

table = "users"
# This is NOT a LiteralString because it has a variable
s: LiteralString = f"SELECT * FROM {table}"

# This IS a LiteralString (f-string without variables, or just constants)
s2: LiteralString = f"SELECT * FROM {'users'}"
