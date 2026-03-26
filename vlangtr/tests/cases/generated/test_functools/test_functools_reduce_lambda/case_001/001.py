import functools
l = [1, 2, 3]
res = functools.reduce(lambda x, y: x * y, l)
