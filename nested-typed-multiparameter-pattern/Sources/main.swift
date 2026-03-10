// MARK: - Nested Typed Multiparameter Pattern
// Purpose: Nested Typed<A>.Typed<B> for multi-parameter generics
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Production note: In swift-property-primitives, Property.View, Property.View.Typed<Element>,
// and Property.View.Typed<Element>.Valued<N> are all ~Copyable, ~Escapable with
// @_lifetime(borrow base) annotations. This experiment uses a simplified version without
// ~Escapable for clarity (adding it would require the Lifetimes feature flag).

// Pattern: Layered generic nesting for multi-parameter binding.
// View → View.Typed<Element> → View.Typed<Element>.Valued<N>

struct View<Tag, Base: ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>

    struct Typed<Element: ~Copyable>: ~Copyable {
        let base: UnsafeMutablePointer<Base>

        struct Valued<let n: Int>: ~Copyable {
            let base: UnsafeMutablePointer<Base>
        }
    }
}

// Container with value-generic capacity
struct Buffer<Element: ~Copyable>: ~Copyable {
    enum ReadOps {}

    struct Static<let capacity: Int>: ~Copyable {
        var count: Int = 0
    }
}

// KEY FINDING: All constraints (Tag ==, Base ==, Element: ~Copyable) MUST be at the
// extension level, not the method level. The compiler adds implicit Base: Copyable
// when Base isn't concretely constrained at extension level.
extension View.Typed.Valued
where Tag == Buffer<Element>.ReadOps,
      Base == Buffer<Element>.Static<n>,
      Element: ~Copyable
{
    func elementCount() -> Int {
        // Production uses: unsafe base.pointee.count
        unsafe base.pointee.count
    }
}

// Provide accessor on Static
extension Buffer.Static where Element: ~Copyable {
    typealias ReadView = View<Buffer<Element>.ReadOps, Buffer<Element>.Static<capacity>>.Typed<Element>.Valued<capacity>

    var read: ReadView {
        mutating _read {
            // Production uses: yield unsafe @_lifetime(borrow self) ReadView(base: &self)
            yield unsafe ReadView(base: &self)
        }
    }
}

var buf = Buffer<Int>.Static<16>(count: 7)
let c = buf.read.elementCount()
print("Element count: \(c)")
assert(c == 7)

// Works with ~Copyable element too
struct Resource: ~Copyable { var id: Int }
var resBuf = Buffer<Resource>.Static<8>(count: 3)
let rc = resBuf.read.elementCount()
print("Resource count: \(rc)")
assert(rc == 3)

print("nested-typed-multiparameter-pattern: CONFIRMED")
