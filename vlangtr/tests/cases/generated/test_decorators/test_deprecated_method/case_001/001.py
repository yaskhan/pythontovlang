from warnings import deprecated

class MyClass:
    @deprecated("Use new_method instead")
    def old_method(self):
        pass
