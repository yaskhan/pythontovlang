def test_none_or():
    value: str | None = None
    if value:
        print("has value")
    else:
        print("no value")

    if not value:
        print("falsy")
