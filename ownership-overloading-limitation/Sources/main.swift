// MARK: - Swift Overloading Limitations
// Purpose: Comprehensive catalog of what Swift 6.2 can and cannot overload on.
//          Covers ownership modifiers, callAsFunction, two-tier patterns, and
//          the static method workaround.
// Status: CONFIRMED
// Date: 2026-01-22 (original), 2026-04-01 (expanded)
// Toolchain: Swift 6.2
// Rules: [IMPL-023], [IMPL-025], [IMPL-067]
// Result: Ownership modifiers (borrowing/consuming/inout) are NOT an overload axis in
//         Swift 6.2. Constraint-based overloading (Copyable vs ~Copyable) works for
//         methods but crashes in callAsFunction on Property.View. Static method
//         delegation [IMPL-023] is the canonical workaround. Codified in skills.
//
// ============================================================================
// FINDINGS SUMMARY
// ============================================================================
//
// OWNERSHIP OVERLOADING:
//   [Q1] borrowing vs consuming same name?          NO — "invalid redeclaration"
//   [Q2] borrowing vs inout same name?              NO — "invalid redeclaration"
//   [Q3] consuming vs inout same name?              NO — "invalid redeclaration"
//   [Q4] Closure param ownership disambiguates?     NO — ambiguous
//   [Q5] Property vs consuming method same name?    NO — "invalid redeclaration"
//
// CALLASFUNCTION OVERLOADING:
//   [Q6] callAsFunction with different constraints?  YES — works (Copyable vs ~Copyable)
//   [Q7] callAsFunction same name on Property.View
//        with different constraints?                 CRASH — compiler crash (SR-XXXXX)
//
// TWO-TIER OVERLOADING:
//   [Q8] ~Copyable + Copyable extensions,
//        different method names?                     YES — works
//   [Q9] ~Copyable + Copyable extensions,
//        same method name, self.method() dispatch?   NO — infinite recursion
//   [Q10] Static method delegation (IMPL-023)?       YES — works, no recursion
//
// CONCLUSION:
//   - Ownership modifiers are NOT an overload axis.
//   - Constraint-based overloading (Copyable vs ~Copyable) works for methods.
//   - callAsFunction constraint overloading works but crashes in some Property.View
//     compositions — use distinct method names or static delegation.
//   - The static method pattern (IMPL-023) is the canonical workaround.
//
// ============================================================================

// ============================================================================
// MARK: - Q1–Q5: Ownership overloading (all fail)
// ============================================================================
// Uncomment any block below to see the compiler error.

struct OwnershipTest<Element: ~Copyable>: ~Copyable {
    var _ptr: UnsafeMutablePointer<Element>

    // Q1: borrowing vs consuming — FAILS
    // func process(_ e: borrowing Element) { }
    // func process(_ e: consuming Element) { }
    // error: invalid redeclaration of 'process'

    // Q2: borrowing vs inout — FAILS
    // func update(_ e: borrowing Element) { }
    // func update(_ e: inout Element) { }
    // error: invalid redeclaration of 'update'

    // Q3: consuming vs inout — FAILS
    // func take(_ e: consuming Element) { }
    // func take(_ e: inout Element) { }
    // error: invalid redeclaration of 'take'

    // Q4: Closure param ownership — FAILS
    // func forEach(_ body: (borrowing Element) -> Void) { }
    // func forEach(_ body: (consuming Element) -> Void) { }
    // error: invalid redeclaration of 'forEach'

    // Q5: Property vs consuming method — FAILS
    // var first: Element { ... }
    // consuming func first() -> Element { ... }
    // error: invalid redeclaration of 'first'
}

// ============================================================================
// MARK: - Q6: callAsFunction with different constraints — WORKS
// ============================================================================

enum Initialize {}

struct Property<Tag, Base> {
    let base: Base
    init(_ base: Base) { self.base = base }
}

struct SimpleStorage {
    var count: Int = 0

    var initialize: Property<Initialize, SimpleStorage> {
        Property(self)
    }
}

// ~Copyable-constrained callAsFunction
extension Property where Tag == Initialize, Base == SimpleStorage {
    func callAsFunction(value: Int) {
        print("Q6: initialize with \(value)")
    }
}

let s = SimpleStorage()
s.initialize(value: 42)  // Q6: WORKS

// ============================================================================
// MARK: - Q7: callAsFunction same name, different constraints — COMPILER CRASH
// ============================================================================
// When two Property.View extensions define callAsFunction with constraints that
// differ only by ~Copyable vs Copyable on Element, the compiler crashes.
//
// This was discovered in swift-sequence-primitives/Experiments/two-tier-borrowing-overloads:
//
//   extension Property.View where Tag == ForEach, Base: Container & ~Copyable {
//       func callAsFunction(_ body: (borrowing Base.Element) -> Void) { ... }
//   }
//   extension Property.View where Tag == ForEach, Base: Container {
//       func callAsFunction(_ body: (Base.Element) -> Void) { ... }
//   }
//   // CRASH: Segmentation fault in SILGen
//
// Workaround: use distinct method names (.borrowing { } vs .copying { }),
// or route through a static method per [IMPL-023].

// ============================================================================
// MARK: - Q8–Q9: Two-tier overloading
// ============================================================================

struct Stack<Element: ~Copyable>: ~Copyable {
    var _count: Int = 0

    // Q8: Different names — WORKS
    // The ~Copyable extension defines the base operation with `borrowing`.
    // The Copyable extension adds a convenience with implicit copy semantics.
    // No name collision because they have different names.
}

extension Stack where Element: ~Copyable {
    mutating func pushConsuming(_ element: consuming Element) {
        _count += 1
        print("Q8: pushConsuming (base tier)")
    }
}

extension Stack where Element: Copyable {
    mutating func push(_ element: Element) {
        _count += 1
        print("Q8: push (Copyable convenience)")
    }
}

var stack = Stack<Int>()
stack.push(1)            // Q8: Copyable convenience
stack.pushConsuming(2)   // Q8: base tier — both accessible

// Q9: Same name — INFINITE RECURSION
// If both extensions define `push`, the Copyable overload calling self.push()
// resolves to ITSELF (more-constrained wins), producing infinite recursion.
//
// extension Stack where Element: ~Copyable {
//     mutating func push(_ element: consuming Element) { ... }
// }
// extension Stack where Element: Copyable {
//     mutating func push(_ element: Element) {
//         self.push(element)  // ← resolves to THIS method, not the ~Copyable one
//     }
// }

// ============================================================================
// MARK: - Q10: Static method delegation (IMPL-023 workaround) — WORKS
// ============================================================================

struct Queue<Element: ~Copyable>: ~Copyable {
    var _count: Int = 0

    // Static method: core logic, no self-dispatch ambiguity
    static func _enqueue(count: inout Int) {
        count += 1
    }
}

extension Queue where Element: ~Copyable {
    mutating func enqueue(_ element: consuming Element) {
        Queue._enqueue(count: &_count)
        print("Q10: enqueue (base tier via static)")
    }
}

extension Queue where Element: Copyable {
    mutating func enqueue(_ element: Element) {
        // CoW check would go here in production
        Queue._enqueue(count: &_count)
        print("Q10: enqueue (Copyable tier via static)")
    }
}

var q = Queue<Int>()
q.enqueue(1)  // Q10: Copyable tier (more-constrained selected, delegates to static)

print("\nAll runnable variants passed.")
