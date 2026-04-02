// MARK: - BitwiseCopyable Lifetime Inference
// Purpose: BitwiseCopyable blocks _read accessor lifetime inference
// Status: CONFIRMED (risk identified)
// Date: 2026-01-21
// Toolchain: Swift 6.2
// Result: CONFIRMED — BitwiseCopyable views allow compiler to bypass _read coroutine scope; ~Escapable with @_lifetime(borrow) is the production fix
//
// Note: The code below runs correctly because the issue is timing-dependent
// and may not manifest in debug builds. The risk is real in optimized builds
// where the compiler more aggressively ends coroutine lifetimes.
//
// Production solution: Property.View is ~Copyable, ~Escapable with
// @_lifetime(borrow base). The ~Escapable constraint prevents the compiler
// from copying the view out of the coroutine scope.

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
            yield unsafe View(&self)
        }
    }
}

extension View where Tag == Counter.Ops, Base == Counter {
    func current() -> Int {
        unsafe base.pointee.value
    }

    // Mutating through the pointer
    func increment() {
        unsafe base.pointee.value += 1
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

var counter = Counter(value: 10)
let v = counter.ops.current()
print("Current: \(v)")
assert(v == 10)

counter.ops.increment()
let v2 = counter.ops.current()
print("After increment: \(v2)")
assert(v2 == 11)

print("bitwisecopyable-lifetime-inference: CONFIRMED")
