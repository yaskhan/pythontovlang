def foo(d: Any):
    d.pop("key")
    d.update({"x": 1})
