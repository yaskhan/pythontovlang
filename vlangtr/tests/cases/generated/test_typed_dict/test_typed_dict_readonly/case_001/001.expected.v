@@in# "b string"
@@in# "d := MyDict{a: 1, b: 'hello'}"
@@in# "d.a = 2"
@@in# "$compile_error(\"Cannot assign to ReadOnly TypedDict field 'b'\")"
