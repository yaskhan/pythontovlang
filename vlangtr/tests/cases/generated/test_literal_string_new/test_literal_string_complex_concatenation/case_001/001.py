from typing import LiteralString
def get_query(limit: int) -> LiteralString:
    query: LiteralString = "SELECT * FROM table"
    if limit > 0:
        return query + " LIMIT 10"
    return query
