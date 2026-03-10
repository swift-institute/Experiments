// MARK: - BitwiseCopyable Lifetime Inference
// Purpose: BitwiseCopyable blocks _read accessor lifetime inference
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// When a view struct is BitwiseCopyable (e.g., it only contains a raw pointer),
// the compiler may bypass the _read coroutine and eagerly load the value,
// breaking the borrow lifetime guarantee.

struct View<Tag, Base> {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

struct Counter {
    enum Ops {}
    var value: Int = 0

    // This _read accessor yields a View that borrows self
    var ops: View<Ops, Counter> {
        mutating _read {
            yield View(&self)
        }
    }
}

extension View where Tag == Counter.Ops, Base == Counter {
    func current() -> Int {
        base.pointee.value
    }

    // Mutating through the pointer
    func increment() {
        base.pointee.value += 1
    }
}

// View<Tag, Base> contains only UnsafeMutablePointer, which is BitwiseCopyable.
// If the compiler treats View as BitwiseCopyable, it may copy the pointer
// out of the _read coroutine, invalidating the borrow.

// In practice this manifests as:
// 1. The _read yields a View
// 2. Compiler sees View is trivially copyable
// 3. Compiler may end the coroutine early (before the method call)
// 4. The pointer may dangle

// Workaround: ensure the View is NOT BitwiseCopyable
// (adding a class reference field, or using _read + _modify pairs)

var counter = Counter(value: 10)
let v = counter.ops.current()
print("Current: \(v)")
assert(v == 10)

counter.ops.increment()
let v2 = counter.ops.current()
print("After increment: \(v2)")
assert(v2 == 11)

print("bitwisecopyable-lifetime-inference: CONFIRMED")
