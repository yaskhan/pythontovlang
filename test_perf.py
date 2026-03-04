import timeit

def concat_str(n):
    res = "interface Foo {\n"
    # To defeat CPython's inplace concatenation optimization:
    for i in range(n):
        res += f"    method_{i}()\n"
        pass
    res += "}"
    return res

def list_join(n):
    res = ["interface Foo {"]
    for i in range(n):
        res.append(f"    method_{i}()")
    res.append("}")
    return "\n".join(res) + "\n"

print("concat_str:", timeit.timeit(lambda: concat_str(10000), number=10))
print("list_join:", timeit.timeit(lambda: list_join(10000), number=10))
