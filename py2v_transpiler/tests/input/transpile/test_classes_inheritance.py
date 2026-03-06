class Animal:
    def __init__(self, name: str):
        self.name = name
    
    def speak(self) -> str:
        return "Some sound"
    
    def info(self) -> str:
        return f"I am {self.name}"

class Dog(Animal):
    def __init__(self, name: str, breed: str):
        super().__init__(name)
        self.breed = breed
    
    def speak(self) -> str:
        return "Woof!"
    
    def fetch(self) -> str:
        return f"{self.name} is fetching"

class Cat(Animal):
    def __init__(self, name: str):
        super().__init__(name)
        self.lives = 9
    
    def speak(self) -> str:
        return "Meow!"
    
    def climb(self) -> str:
        return f"{self.name} is climbing"

def test_basic_inheritance():
    dog = Dog("Buddy", "Golden")
    print(dog.name)
    print(dog.breed)
    print(dog.speak())
    print(dog.info())
    print(dog.fetch())

def test_polymorphism():
    animals: list[Animal] = [Dog("Rex", "Shepherd"), Cat("Whiskers")]
    for animal in animals:
        print(f"{animal.name} says: {animal.speak()}")

class Vehicle:
    wheels = 4  # Class variable
    
    def __init__(self, brand: str):
        self.brand = brand

class Car(Vehicle):
    def __init__(self, brand: str, model: str):
        super().__init__(brand)
        self.model = model
    
    def description(self) -> str:
        return f"{self.brand} {self.model}"

def test_class_variables():
    car = Car("Toyota", "Camry")
    print(f"Car: {car.description()}")
    print(f"Wheels: {car.wheels}")
    print(f"Class wheels: {Vehicle.wheels}")

def test_isinstance_issubclass():
    dog = Dog("Spot", "Labrador")
    
    print(f"dog is Animal: {isinstance(dog, Animal)}")
    print(f"dog is Dog: {isinstance(dog, Dog)}")
    print(f"dog is Cat: {isinstance(dog, Cat)}")
    
    print(f"Dog is subclass of Animal: {issubclass(Dog, Animal)}")
    print(f"Cat is subclass of Animal: {issubclass(Cat, Animal)}")
    print(f"Dog is subclass of Cat: {issubclass(Dog, Cat)}")

def test():
    test_basic_inheritance()
    test_polymorphism()
    test_class_variables()
    test_isinstance_issubclass()

if __name__ == "__main__":
    test()
