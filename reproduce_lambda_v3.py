from py2v_transpiler.main import Transpiler
t = Transpiler()
code = "f = lambda x: print(x)"
print(t.transpile(code))
code2 = "g = lambda x: None"
print(t.transpile(code2))
