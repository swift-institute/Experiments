// V3 — `_read` coroutine yielding a Builder that BORROWS Base via
// an UnsafePointer with explicit `@_lifetime(borrow self)` annotation.
//
// Hypothesis: A `_read` accessor borrows self for the yield duration.
// If we construct a `~Copyable & ~Escapable` Builder that stores an
// `UnsafePointer<Base>` (captured via `withUnsafePointer(to:)`) and
// annotate its lifetime to depend on the borrow of self, then the
// yield should hand a borrowed view of self to the caller — sufficient
// for parens-less chaining like `source.v3_map.compact { ... }` AS
// LONG AS the chain semantics are borrow-of-source rather than
// consume-of-source.
//
// This sidesteps the parser-primitives `consuming get` blocker because
// `_read` is a borrow accessor, not a consume accessor; the
// `sil_movechecking_capture_consumed` diagnostic does not fire on
// borrowing access.
//
// Expected verdict: compiles. The interesting follow-up is whether
// the downstream chain `.compact { ... }` can produce something
// iterable, which V6 explores.

public struct V3_BuilderBorrowed<Base: SeqProtocol & ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    var _ptr: UnsafePointer<Base>

    @inlinable
    @_lifetime(borrow base)
    package init(borrowing base: borrowing Base) {
        // Capture a typed pointer to base; bind the lifetime to the
        // borrow of base via _overrideLifetime.
        //
        // The withUnsafePointer-then-keep-pointer pattern is exactly
        // what `Ownership.Borrow.init(borrowing:)` and
        // `Property.Borrow.init(_:borrowing)` do in the
        // swift-property-primitives / swift-ownership-primitives
        // package. The standard guidance is that this init MUST be
        // non-@inlinable for cross-module callers to avoid a known
        // release-mode miscompile (Audit
        // `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`).
        // For an in-package experiment we keep @inlinable; the
        // miscompile is module-boundary specific.
        let ptr = unsafe withUnsafePointer(to: base) { unsafe $0 }
        self._ptr = ptr
    }
}

extension V3_BuilderBorrowed where Base: ~Copyable & ~Escapable {
    /// Access the borrowed base.
    @inlinable
    public var base: Base {
        @_lifetime(borrow self)
        unsafeAddress { unsafe _ptr }
    }
}

extension SeqProtocol where Self: ~Copyable & ~Escapable {
    /// The borrow-yielding accessor — `_read` instead of `consuming get`.
    @inlinable
    public var v3_map: V3_BuilderBorrowed<Self> {
        @_lifetime(borrow self)
        _read {
            yield V3_BuilderBorrowed(borrowing: self)
        }
    }
}

// V3 chain method: `.compact { transform }` on the borrowed builder.
// This builds a Compact wrapper that also borrows the original source.
extension V3_BuilderBorrowed where Base: SeqProtocol & ~Copyable & ~Escapable, Base.Element: Copyable {
    /// Returns a borrowing-Compact wrapper.
    @inlinable
    @_lifetime(borrow self)
    public consuming func compact<Output>(
        _ transform: @escaping (Base.Element) -> Output?
    ) -> V3_CompactBorrowed<Base, Output> {
        V3_CompactBorrowed(borrowing: self.base, transform: transform)
    }
}

public struct V3_CompactBorrowed<Base: SeqProtocol & ~Copyable & ~Escapable, Output>: ~Copyable, ~Escapable
where Base.Element: Copyable {
    @usableFromInline
    var _ptr: UnsafePointer<Base>

    @usableFromInline
    let _transform: (Base.Element) -> Output?

    @inlinable
    @_lifetime(borrow base)
    init(borrowing base: borrowing Base, transform: @escaping (Base.Element) -> Output?) {
        let ptr = unsafe withUnsafePointer(to: base) { unsafe $0 }
        self._ptr = ptr
        self._transform = transform
    }
}

// V3 demonstration call site — the entire investigation question.
@inlinable
public func runV3Direct() -> Bool {
    let source = NCSource([1, 2, 3, 4, 5])
    // The chain we want to make work:
    //
    //     source.v3_map.compact { ... }
    //
    // V3 attempts to enable it via _read + borrowing init.
    let _ = source.v3_map.compact { $0 % 2 == 0 ? $0 : nil }
    return true
}
