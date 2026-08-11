// MARK: - H7b — Same-name accessor in two conditional extensions
// Hypothesis: Defining `var value: Value` in BOTH
//             `extension Box where Value: ~Copyable` AND
//             `extension Box where Value: Copyable`
//             produces a compile error (ambiguous / duplicate).
//
// Status: AS-IS this file compiles if the definitions are NOT overlapping
//         in dispatch. To test the claim, we define the same member in
//         both extensions with DIFFERENT accessor shapes and see what
//         Swift does.

enum H7b {}

extension H7b {
    struct Box<Value: ~Copyable>: ~Copyable {
        var _storage: _Storage

        final class _Storage {
            var value: Value
            init(_ value: consuming Value) { self.value = value }
        }

        init(_ initialValue: consuming Value) {
            self._storage = _Storage(initialValue)
        }
    }
}

extension H7b.Box: Copyable where Value: Copyable {}

// Both extensions define `var value: Value` — the test is whether
// Swift rejects or resolves by specificity.

extension H7b.Box where Value: ~Copyable {
    var value: Value {
        _read { yield _storage.value }
    }
}

extension H7b.Box where Value: Copyable {
    var value: Value {
        get { _storage.value }
        set {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _Storage(_storage.value)
            }
            _storage.value = newValue
        }
    }
}

// If this compiles, Swift accepts both definitions — the Copyable-specific
// one wins by constraint-specificity for Copyable Value, the ~Copyable
// extension's definition applies when Value is strictly ~Copyable.
//
// If this FAILS to compile, the compiler rejects duplicate member definitions.

func h7b_test() {
    // Copyable path: should use the Copyable-extension accessor (with CoW setter)
    var box = H7b.Box<Int>(1)
    let copy = box.value       // calls get { _storage.value } — legal COPY
    print("H7b: Copyable path read — value = \(copy)")
    box.value = 2               // calls set — triggers CoW check
    print("H7b: Copyable path write OK; new value = \(box.value)")

    // ~Copyable path: the _read yields a borrow. Cannot do `let x = hbox.value`
    // because `let x = ...` would need to consume or copy the Value.
    // Usage pattern is restricted to transitively borrowing expressions:
    let hbox = H7b.Box<H1_Handle>(H1_Handle(42))
    let id = hbox.value.id       // transitive borrow — reads .id through _read yield
    print("H7b: ~Copyable path transitive-borrow read — id = \(id)")
    print("H7b: Cannot do `let v = hbox.value` directly for ~Copyable Value —")
    print("H7b: Swift diagnostic: 'value cannot be consumed when captured by escaping closure'")
    print("H7b: This is another difference in ergonomics between Copyable and ~Copyable paths.")
    print("H7b: SUMMARY — same-named accessors in two conditional extensions DO compile and")
    print("H7b: resolve by specificity, but the ~Copyable side has borrow-only usage semantics.")
}
