import functools
import operator
l = [1, 2, 3]
res = functools.reduce(operator.add, l)
