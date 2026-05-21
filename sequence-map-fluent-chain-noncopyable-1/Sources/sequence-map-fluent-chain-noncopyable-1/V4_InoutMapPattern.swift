// V4 — `mutating _read` yielding a Builder that borrows self mutably,
// modeled on the Property.Inout / Property.View pattern. Requires the
// caller to declare source as `var`, not `let`.
//
// Hypothesis: With `mutating _read` and a Builder constructed from
// `inout self`, the accessor is mutating-borrow which differs from
// the consuming-borrow that fails V1, and from the read-only borrow
// of V3. This is the canonical Property.View pattern documented in
// the `property-primitives` skill at [PRP-008].
//
// The interesting test is whether this works on a PROTOCOL EXTENSION
// where Self: ~Copyable & ~Escapable. The property-primitives skill
// demonstrates the pattern on concrete-type extensions; protocol-Self
// support is the open question for this experiment.

public struct V4_BuilderInout<Base: SeqProtocol & ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline
    var _ptr: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(&base)
    package init(_ base: inout Base) {
        self._ptr = unsafe withUnsafeMutablePointer(to: &base) { unsafe $0 }
    }
}

extension SeqProtocol where Self: ~Copyable & ~Escapable {
    @inlinable
    public var v4_map: V4_BuilderInout<Self> {
        @_lifetime(&self)
        mutating _read {
            yield V4_BuilderInout(&self)
        }
    }
}

// V4 chain method
extension V4_BuilderInout where Base: SeqProtocol & ~Copyable & ~Escapable, Base.Element: Copyable {
    @inlinable
    @_lifetime(copy self)
    public consuming func compact<Output>(
        _ transform: @escaping (Base.Element) -> Output?
    ) -> V4_CompactInout<Base, Output> {
        V4_CompactInout(ptr: _ptr, transform: transform)
    }
}

public struct V4_CompactInout<Base: SeqProtocol & ~Copyable & ~Escapable, Output>: ~Copyable, ~Escapable
where Base.Element: Copyable {
    @usableFromInline
    var _ptr: UnsafeMutablePointer<Base>

    @usableFromInline
    let _transform: (Base.Element) -> Output?

    @inlinable
    init(ptr: UnsafeMutablePointer<Base>, transform: @escaping (Base.Element) -> Output?) {
        self._ptr = ptr
        self._transform = transform
    }
}

// V4 demonstration call site.
@inlinable
public func runV4Direct() -> Bool {
    var source = NCSource([1, 2, 3, 4, 5])    // NOTE: `var`, not `let`
    let _ = source.v4_map.compact { $0 % 2 == 0 ? $0 : nil }
    return true
}
