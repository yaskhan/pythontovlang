from typing import TypedDict, Any

class Point2D(TypedDict):
    x: int
    y: int

class Point3D(TypedDict, total=False):
    x: int
    y: int
    z: int

def foo():
    p1: Point2D = {"x": 1, "y": 2}
    p2: Point3D = {"x": 1, "y": 2, "z": 3}
    p3 = {"a": 1, "b": 2} # untyped fallback

    print(p1["x"])
    print(p2.get("z", 0))

foo()
