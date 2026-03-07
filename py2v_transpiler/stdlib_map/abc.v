module abc

pub interface ABC {}

pub struct ABCMeta {}

pub fn (meta ABCMeta) register(cls Any) {
    // Virtual subclass registration implementation
    // In V, this is a no-op as interfaces are structural
}

pub fn update_abstractmethods(cls Any) {
    // Recalculates __abstractmethods__
}

pub fn abstractmethod(f fn()) fn() { return f }
pub fn abstractclassmethod(f fn()) fn() { return f }
pub fn abstractstaticmethod(f fn()) fn() { return f }
pub fn abstractproperty(f fn()) fn() { return f }
