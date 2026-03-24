from py2v_transpiler.core.translator.base_split.naming import NamingMixin

class Tester(NamingMixin):
    def test(self, name):
        return self._to_snake_case(name)

t = Tester()
print(f"'ServiceA_get_id__annotations__': {t.test('ServiceA_get_id__annotations__')}")
