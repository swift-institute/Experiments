// MARK: - Property.View Pattern
// Purpose: Property.View pattern for protocol extensions
// Status: CONFIRMED
// Result: CONFIRMED — Property.View pattern provides namespaced accessors through pointer-holding view struct with tag-constrained extensions
// Date: 2026-01-22
// Toolchain: Swift 6.2

// Production note: In swift-property-primitives, this pattern is implemented as
// Property<Tag, Base>.View which is ~Copyable, ~Escapable with @_lifetime(borrow base).
// This experiment uses a simplified Copyable, Escapable version for clarity.

// The Property.View pattern provides namespaced accessors
// through a pointer-holding view struct.

struct View<Tag, Base> {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

struct Counter {
    enum MathOps {}

    var value: Int = 0

    var math: View<MathOps, Counter> {
        mutating _read {
            // Production uses: yield unsafe @_lifetime(borrow self) View(&self)
            yield unsafe View(&self)
        }
    }
}

extension View where Tag == Counter.MathOps, Base == Counter {
    func add(_ n: Int) -> Int {
        // Production uses: unsafe base.pointee.value
        unsafe base.pointee.value + n
    }

    func doubled() -> Int {
        unsafe base.pointee.value * 2
    }
}

var counter = Counter(value: 10)
let sum = counter.math.add(5)
let dbl = counter.math.doubled()
print("add(5): \(sum)")       // 15
print("doubled(): \(dbl)")    // 20
assert(sum == 15)
assert(dbl == 20)
print("property-view-pattern: CONFIRMED")
