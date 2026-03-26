class A:
    x = 10
def f(): return A()

# f() returns object (Call). Base is Call.
# _capture_target(f().x) -> base is f() (Call)
# Since base is Call (not L-value container like Name/Attr/Subscript), it uses _capture_value.
# tmp := f()
# tmp.x = ...
f().x **= 2
