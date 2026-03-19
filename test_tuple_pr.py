from typing import NamedTuple, Tuple

class Point(NamedTuple):
    x: int
    y: int

def move(p: Point, dp: Tuple[int, int]) -> Point:
    return Point(p.x + dp[0], p.y + dp[1])

def main() -> None:
    p1 = Point(10, 20)
    dp = (5, -5)
    p2 = move(p1, dp)
    print(p2.x, p2.y)

if __name__ == "__main__":
    main()
