class Pt:
    x = 0
arr = [Pt()]
# arr[0].x **= 2
# _capture_target(arr[0].x)
# Base arr[0] (Subscript). Recurse.
# Base arr (Name). Recurse -> "arr".
# Index 0 (Constant). Recurse -> "0".
# Returns arr[0].x
# No temp vars needed for static indices.
arr[0].x **= 2
