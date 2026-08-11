// MARK: - V03: ~Escapable Values in Deinit
// Purpose: Test approaches to use ~Escapable Property.View types in deinit.
//          Deinit has an immutable `self`, so ~Escapable values that borrow
//          stored properties face lifetime-dependent-value-escapes-scope errors.
// Hypothesis: @_unsafeNonescapableResult on get accessor enables ~Escapable in deinit
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — @_unsafeNonescapableResult on `get` accessor (not on the
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         property declaration itself) enables ~Escapable values in deinit.
//         Combined with `mutating _modify` for tracked operations under a single
//         property name. This is THE solution for Property.View accessors.
//
//         KEY SYNTAX: attribute goes on the GETTER, not the property:
//           var view: View {
//               @_unsafeNonescapableResult
//               get { ... }
//           }
//
//         REFUTED: _read accessor — "lifetime-dependent value escapes its scope"
//         CONFIRMED: get + @_unsafeNonescapableResult on getter — works in deinit
//         CONFIRMED: get + _modify combined under single property — works
//         COMPILER BUG: @_unsafeNonescapableResult on _read — signal 6
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: escapable-deinit-lifetime (18 variants, especially V17, V18)
// Supports: escapable-deinit-lifetime.md, Property.View accessor pattern

// --- Setup: Simulated Property.View pattern ---

struct View: ~Escapable {
    var value: Int

    @_unsafeNonescapableResult
    init(value: Int) {
        self.value = value
    }
}

// --- CONFIRMED: @_unsafeNonescapableResult on get accessor ---
// The attribute MUST be on the `get` accessor, NOT on the property declaration.
// `get` returns @owned values, so the lifetime suppression works.
// `_read` yields @guaranteed values — attribute crashes the compiler (Bug).

struct Owner: ~Copyable {
    var _value: Int

    init(_ value: Int) { self._value = value }

    // Single property with both read (get) and mutate (_modify) paths.
    // get: used in deinit (non-mutating context)
    // _modify: used in mutating context
    var view: View {
        @_unsafeNonescapableResult
        get { View(value: _value) }
        _modify {
            var v = View(value: _value)
            yield &v
            _value = v.value
        }
    }

    deinit {
        // This works because `view` getter uses @_unsafeNonescapableResult
        let v = view
        print("  Owner deinit: value=\(v.value)")
    }
}

// --- V9: withUnsafePointer closure (alternative that also works in deinit) ---

struct V9_Closure: ~Copyable {
    var _value: Int

    init(_ value: Int) { self._value = value }

    func withView(_ body: (Int) -> Void) {
        body(_value)
    }

    deinit {
        withView { value in
            print("  V9 deinit: value=\(value)")
        }
    }
}

// --- Tests ---

func testOwner() {
    print("=== get + @_unsafeNonescapableResult (on getter) ===")
    do {
        var owner = Owner(42)
        print("  Read: \(owner.view.value)")
        owner.view.value = 99
        print("  After modify: \(owner.view.value)")
        // deinit prints the final value
    }
}

func testV9() {
    print("\n=== V9: withUnsafePointer closure ===")
    do {
        let _ = V9_Closure(77)
        // deinit uses closure pattern
    }
}

testOwner()
testV9()

print("\nSUMMARY:")
print("  `_read` in deinit: BLOCKED — yields @guaranteed, carries lifetime")
print("  `get` + @_unsafeNonescapableResult ON GETTER: WORKS — returns @owned")
print("  @_unsafeNonescapableResult ON PROPERTY: REJECTED — wrong placement")
print("  `_read` + @_unsafeNonescapableResult: COMPILER CRASH (signal 6)")
print("  withUnsafePointer closure: WORKS — alternative when _read not needed")
print("\n  THE SOLUTION: @_unsafeNonescapableResult on `get` accessor (not property)")
print("  Combined with `mutating _modify` for tracked mutation paths.")
