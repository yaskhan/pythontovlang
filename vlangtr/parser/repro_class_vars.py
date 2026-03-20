class Vehicle:
    wheels: int = 4

def update_wheels() -> None:
    Vehicle.wheels = 5
    print(Vehicle.wheels)

if __name__ == "__main__":
    update_wheels()
