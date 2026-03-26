from typing import LiteralString

def run_query(sql: LiteralString) -> None:
    pass

s: LiteralString = "SELECT * FROM users"
run_query(s)
run_query("SELECT 1")
