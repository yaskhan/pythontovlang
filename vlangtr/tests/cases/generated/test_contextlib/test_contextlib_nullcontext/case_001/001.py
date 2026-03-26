from contextlib import nullcontext
with nullcontext(1) as x:
    print(x)
