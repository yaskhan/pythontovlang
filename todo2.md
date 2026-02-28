# New Features from mypy Changelog (Versions 1.15 to 1.19)

- [ ] Support for TypeForm[T] (PEP 747) as an experimental feature
- [ ] Improved reachability analysis and partial type handling in loops
- [ ] Disjoint Base Classes (`@disjoint_base`, PEP 800) support
- [ ] Support using different types for a property getter and setter
- [ ] Flexible variable redefinitions (allowing unannotated variables to be redefined with different types, `allow-redefinition-new`)
- [ ] Stricter type checking with imprecise types (e.g., `dict.get(x, None)` on `dict[str, Any]` resulting in `Any | None` instead of `Any`)
- [ ] Infer types for bare `ClassVar` from initializers
- [ ] Optionally check that match is exhaustive (`--enable-error-code exhaustive-match`)
- [ ] Mypyc: Support for `__getattr__`, `__setattr__`, and `__delattr__`
- [ ] Mypyc: Support for user-defined `__new__` methods
- [ ] Mypyc: Annotating native/non-native classes (`@mypyc_attr(native_class=False)`)

*(List extracted from mypy blog posts for versions 1.15, 1.16, 1.17, 1.18.1, 1.19)*