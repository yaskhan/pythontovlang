def test_context_manager():
    class FileManager:
        def __init__(self, filename: str, mode: str):
            self.filename = filename
            self.mode = mode
            self.file = None
        
        def __enter__(self):
            print(f"Opening {self.filename}")
            self.file = open(self.filename, self.mode)
            return self.file
        
        def __exit__(self, exc_type, exc_val, exc_tb):
            print(f"Closing {self.filename}")
            self.file.close()
            return False
    
    # Note: This test creates a file, use with caution
    # with FileManager("test.txt", "w") as f:
    #     f.write("Hello")

def test_simple_context():
    class SimpleContext:
        def __enter__(self):
            print("Entering")
            return self
        
        def __exit__(self, *args):
            print("Exiting")
    
    with SimpleContext() as ctx:
        print("Inside context")

def test_context_with_value():
    class ValueContext:
        def __enter__(self):
            print("Getting value")
            return 42
        
        def __exit__(self, *args):
            print("Cleaning up")
    
    with ValueContext() as value:
        print(f"Got value: {value}")

def test_context_suppress_exception():
    class SuppressErrors:
        def __enter__(self):
            print("Entering (suppressing errors)")
            return self
        
        def __exit__(self, exc_type, exc_val, exc_tb):
            print(f"Caught exception: {exc_type}")
            return True  # Suppress exception
    
    with SuppressErrors():
        print("About to raise error")
        raise ValueError("This error is suppressed")
    print("After context (error was suppressed)")

def test_context_propagate_exception():
    class LogErrors:
        def __enter__(self):
            print("Entering")
            return self
        
        def __exit__(self, exc_type, exc_val, exc_tb):
            if exc_type is not None:
                print(f"Logging error: {exc_val}")
            return False  # Don't suppress
    
    try:
        with LogErrors():
            raise ValueError("This error propagates")
    except ValueError:
        print("Exception was propagated")

def test_nested_contexts():
    class ContextA:
        def __enter__(self):
            print("Context A enter")
            return "A"
        
        def __exit__(self, *args):
            print("Context A exit")
    
    class ContextB:
        def __enter__(self):
            print("Context B enter")
            return "B"
        
        def __exit__(self, *args):
            print("Context B exit")
    
    with ContextA() as a, ContextB() as b:
        print(f"Inside: {a}, {b}")

def test_context_exception_in_enter():
    class FailingEnter:
        def __enter__(self):
            print("About to fail")
            raise RuntimeError("Enter failed")
        
        def __exit__(self, *args):
            print("Exit called (cleanup)")
    
    try:
        with FailingEnter():
            print("Never reached")
    except RuntimeError:
        print("Caught RuntimeError")

def test_context_exception_in_exit():
    class FailingExit:
        def __enter__(self):
            print("Enter OK")
            return self
        
        def __exit__(self, *args):
            print("About to fail in exit")
            raise RuntimeError("Exit failed")
    
    try:
        with FailingExit():
            print("Inside")
    except RuntimeError:
        print("Caught RuntimeError from exit")

def test():
    test_simple_context()
    test_context_with_value()
    test_context_suppress_exception()
    test_context_propagate_exception()
    test_nested_contexts()
    test_context_exception_in_enter()
    test_context_exception_in_exit()

if __name__ == "__main__":
    test()
