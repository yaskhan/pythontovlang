module main

// @line: test_classes_inheritance.py:1:0

pub interface Animal {
    name string
    speak() string
    info() string
}

// @line: test_classes_inheritance.py:1:0
pub struct Animal_Impl {
    name string
}
// @line: test_classes_inheritance.py:11:0
pub struct Dog {
    breed string
}
// @line: test_classes_inheritance.py:22:0
pub struct Cat {
    lives int
}
// @line: test_classes_inheritance.py:46:0

pub interface Vehicle {
    wheels int = 4
    brand string
}

// @line: test_classes_inheritance.py:46:0
pub struct Vehicle_Impl {
    wheels int = 4
    brand string
}
// @line: test_classes_inheritance.py:52:0
pub struct Car {
    model string
}

pub const Animal_Impl_new_animal_impl__annotations__ = { 'name': 'string' }
pub const Animal_Impl_speak__annotations__ = { 'return': 'string' }
pub const Animal_Impl_info__annotations__ = { 'return': 'string' }
pub const Dog_new_dog__annotations__ = { 'name': 'string', 'breed': 'string' }
pub const Dog_speak__annotations__ = { 'return': 'string' }
pub const Dog_fetch__annotations__ = { 'return': 'string' }
pub const Cat_new_cat__annotations__ = { 'name': 'string' }
pub const Cat_speak__annotations__ = { 'return': 'string' }
pub const Cat_climb__annotations__ = { 'return': 'string' }
pub const Vehicle_wheels = 4
pub const Vehicle_Impl_new_vehicle_impl__annotations__ = { 'brand': 'string' }
pub const Car_new_car__annotations__ = { 'brand': 'string', 'model': 'string' }
pub const Car_description__annotations__ = { 'return': 'string' }

// @line: test_classes_inheritance.py:2:4
pub fn new_animal_impl(name string) Animal_Impl {
    mut self := Animal_Impl{}
    self.name = name
    return self
}
// @line: test_classes_inheritance.py:5:4
pub fn (self Animal_Impl) speak() string {
    return 'Some sound'
}
// @line: test_classes_inheritance.py:8:4
pub fn (self Animal_Impl) info() string {
    return 'I am ${self.name}'
}
// @line: test_classes_inheritance.py:12:4
pub fn new_dog(name string, breed string) Dog {
    mut self := Dog{}
    self.Animal_Impl = new_animal_impl(name)
    self.breed = breed
    return self
}
// @line: test_classes_inheritance.py:16:4
pub fn (self Dog) speak() string {
    return 'Woof!'
}
// @line: test_classes_inheritance.py:19:4
pub fn (self Dog) fetch() string {
    return '${self.name} is fetching'
}
// @line: test_classes_inheritance.py:23:4
pub fn new_cat(name string) Cat {
    mut self := Cat{}
    self.Animal_Impl = new_animal_impl(name)
    self.lives = 9
    return self
}
// @line: test_classes_inheritance.py:27:4
pub fn (self Cat) speak() string {
    return 'Meow!'
}
// @line: test_classes_inheritance.py:30:4
pub fn (self Cat) climb() string {
    return '${self.name} is climbing'
}
// @line: test_classes_inheritance.py:33:0
pub fn test_basic_inheritance() {
    mut dog := new_dog('Buddy', 'Golden')
    println('${dog.name}')
    println('${dog.breed}')
    println('${dog.speak()}')
    println('${dog.info()}')
    println('${dog.fetch()}')
}
// @line: test_classes_inheritance.py:41:0
pub fn test_polymorphism() {
    mut animals := []Animal{}
    animals << new_dog('Rex', 'Shepherd')
    animals << new_cat('Whiskers')
    for animal in animals {
        println('${animal.name} says: ${animal.speak()}')
    }
}
// @line: test_classes_inheritance.py:49:4
pub fn new_vehicle_impl(brand string) Vehicle_Impl {
    mut self := Vehicle_Impl{}
    self.brand = brand
    return self
}
// @line: test_classes_inheritance.py:53:4
pub fn new_car(brand string, model string) Car {
    mut self := Car{}
    self.Vehicle_Impl = new_vehicle_impl(brand)
    self.model = model
    return self
}
// @line: test_classes_inheritance.py:57:4
pub fn (self Car) description() string {
    return '${self.brand} ${self.model}'
}
// @line: test_classes_inheritance.py:60:0
pub fn test_class_variables() {
    car := new_car('Toyota', 'Camry')
    println('Car: ${car.description()}')
    println('Wheels: ${car.wheels}')
    println('Class wheels: ${Vehicle_wheels}')
}
// @line: test_classes_inheritance.py:66:0
pub fn test_isinstance_issubclass() {
    mut dog := new_dog('Spot', 'Labrador')
    println('dog is Animal: ${dog is Animal}')
    println('dog is Dog: ${dog is Dog}')
    println('dog is Cat: ${dog is Cat}')
    println('Dog is subclass of Animal: ${/* issubclass(Dog, Animal) */ true}')
    println('Cat is subclass of Animal: ${/* issubclass(Cat, Animal) */ true}')
    println('Dog is subclass of Cat: ${/* issubclass(Dog, Cat) */ false}')
}
// @line: test_classes_inheritance.py:77:0
pub fn test() {
    test_basic_inheritance()
    test_polymorphism()
    test_class_variables()
    test_isinstance_issubclass()
}

fn main() {
    // @line: test_classes_inheritance.py:83:0
    // if __name__ == '__main__':
    test()
}