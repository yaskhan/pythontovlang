def process_numbers(nums: list[int | str]) -> list[int]:
    """Process a list of numbers and strings."""
    result: list[int] = []

    for num in nums:
        try:
            if isinstance(num, str):
                result.append(int(num))
            else:
                result.append(num)
        except ValueError:
            print(f"Failed to convert: {num}")
        finally:
            print("Processing complete for element.")

    return result

def create_multiplier(factor: int):
    """Creates a closure."""
    def multiplier(n: int) -> int:
        return n * factor
    return multiplier

def test():
    data: list[int | str] = [1, "2", "three", 4]
    processed = process_numbers(data)

    times_two = create_multiplier(2)
    final_result = [times_two(x) for x in processed]

    print(final_result)

if __name__ == "__main__":
    test()
