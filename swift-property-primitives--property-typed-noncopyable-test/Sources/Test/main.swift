// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//
// ===----------------------------------------------------------------------===//
// Experiment: Property.View.Typed for ~Copyable with Type Parameter
// ===----------------------------------------------------------------------===//
//
// QUESTION: Can we add Element type parameter to Property.View for ~Copyable?
//
// HYPOTHESIS: Property.View works for ~Copyable via pointer indirection.
// We can add a Typed variant that carries Element for property extensions.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// RESULT: [CONFIRMED] Property.View.Typed<Element: ~Copyable> enables
// property extensions for ~Copyable containers with Element type parameter.
// Requires explicit `where Base: ~Copyable` on the extension defining Typed.
// ===----------------------------------------------------------------------===//

// MARK: - Property (base from property-primitives)

public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self._base = base
    }

    @inlinable
    public var base: Base {
        _read { yield _base }
        _modify { yield &_base }
    }
}

extension Property: Copyable where Base: Copyable {}
extension Property: Sendable where Base: Sendable {}

// MARK: - Property.View (existing, for ~Copyable)

extension Property where Base: ~Copyable {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

// MARK: - NEW: Property.View.Typed (for ~Copyable with Element type)

extension Property.View where Base: ~Copyable {
    /// View with an Element type parameter for property extensions on ~Copyable types.
    ///
    /// This combines the pointer-based access of View with the type parameter
    /// of Typed, enabling property extensions for ~Copyable containers.
    @safe
    public struct Typed<Element: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

// MARK: - Test Container

struct SimpleContainer<Element: ~Copyable>: ~Copyable {
    var count: Int

    init() { self.count = 0 }

    enum Access {}
}

extension SimpleContainer where Element: ~Copyable {
    var access: Property<Access, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Access, Self>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Access, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// Extension with Element available for constraints
extension Property.View.Typed
where Tag == SimpleContainer<Element>.Access,
      Base == SimpleContainer<Element>,
      Element: ~Copyable
{
    func getCount() -> Int {
        unsafe base.pointee.count
    }

    @_lifetime(&self)
    mutating func incrementCount() {
        unsafe base.pointee.count += 1
    }
}

// MARK: - Main

func main() {
    // Test with Copyable element
    var copyableContainer = SimpleContainer<Int>()
    copyableContainer.access.incrementCount()
    print("Copyable count: \(copyableContainer.access.getCount())")

    // Test with ~Copyable element
    struct Resource: ~Copyable {
        var id: Int
    }

    var noncopyableContainer = SimpleContainer<Resource>()
    noncopyableContainer.access.incrementCount()
    print("NonCopyable count: \(noncopyableContainer.access.getCount())")

    print("SUCCESS: Property.View.Typed works with ~Copyable elements!")
}

main()
