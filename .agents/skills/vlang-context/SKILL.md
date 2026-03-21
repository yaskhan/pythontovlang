---
name: vlang-context
description: V language (Vlang) technical context for 2025-2026 (v0.4.x-0.5.x). Use when writing or reviewing generated V code in the Python-to-V transpiler — covers error handling, Option/Result types, memory management, stdlib updates, and map/string syntax rules.
---

# Vlang Technical Context (2025-2026)

> Goal: Ensure AI Agent uses the most recent V syntax (0.4.x - 0.5.x branches) for the Python-to-V transpiler project.

## 1. Syntax & Core Language
* **Error Handling (Strict `or` blocks):** The `or { ... }` block now **must** either return a value of the same type, `panic`, or `exit`. Implicit returns from `or` blocks are deprecated.
* **Implicit Struct Initialization:** If a struct has default values, you can use `MyStruct{}` without repeating field names if they are being passed in order (though named fields are still preferred for clarity in transpiled code).
* **Option/Result Separation:** V has moved towards a clearer distinction between `?Type` (Option - maybe none) and `!Type` (Result - maybe error). In the transpiler, use `!Type` for functions that can fail with an error message.
* **Immutable by Default:** String indexing `s[i]` now returns a `u8` (byte) that is strictly immutable. Any "in-place" trickery used in 2024 is now a compiler error.

## 2. Memory & Concurrency
* **Coroutines (vthreads):** The syntax `spawn function()` is now more robust. If the transpiler handles Python's `async`, map it to `spawn` in V, but remember that `await` is handled via `handle.wait()`.
* **Shared & Lock:** The `shared` keyword and `lock` blocks now support a "timed lock" to prevent deadlocks in complex concurrent transpilation tasks.
* **Autofree 2.0:** The memory management engine was updated in late 2025. Manual `free()` is almost never needed, but avoid creating circular references in transpiled objects without using `[weak]` references.

## 3. Standard Library (vlib) Updates
* **`net.http`:** The API was simplified. `http.get()` now returns a `!http.Response`.
* **`arrays` module:** Added functional-style methods (`filter`, `map`, `any`, `all`) that work directly on arrays without extra allocations. Use these for cleaner generated code.
* **`json`:** `json.decode` now requires the first argument to be the type, and handles `[json: "-"]` tags strictly to skip fields.

## 4. Transpiler Specifics (Python to V)
* **Map Initialization:** In 2026 V, maps are initialized as `map[string]int{}`. Empty maps `m := {}` are discouraged if the type cannot be inferred immediately.
* **String Interpolation:** Use `${variable}` or `$variable`. Complex expressions inside `${...}` should be kept simple to avoid breaking the V parser's optimization.

## Instructions for the AI
1. **Always** check for `!` or `?` when calling standard library functions.
2. **Avoid** the old `voidptr` casting where possible; use `any` or generics.
3. **Ensure** that all `mut` variables are actually mutated; the 2026 compiler is very strict about unused `mut` keywords.
