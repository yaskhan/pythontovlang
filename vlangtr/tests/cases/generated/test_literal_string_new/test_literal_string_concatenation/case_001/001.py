from typing import LiteralString

s1: LiteralString = "SELECT "
s2: LiteralString = "id FROM "
s3: LiteralString = s1 + s2 + "users"

def run_query(sql: LiteralString):
    pass

run_query(s3)
