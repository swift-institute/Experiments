// MARK: - Property.View Pattern
// Purpose: Property.View pattern for protocol extensions
// Status: CONFIRMED
// Date: 2026-01-22
// Toolchain: Swift 6.2

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
            yield View(&self)
        }
    }
}

extension View where Tag == Counter.MathOps, Base == Counter {
    func add(_ n: Int) -> Int {
        base.pointee.value + n
    }

    func doubled() -> Int {
        base.pointee.value * 2
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
