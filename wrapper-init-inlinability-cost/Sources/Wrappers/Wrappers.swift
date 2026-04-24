// MARK: - Inlinability Cost Wrappers
// Purpose: isolate the per-init cost of removing @inlinable from a one-line
//          ~Copyable, ~Escapable wrapper that captures a UnsafeMutableRawPointer
//          from withUnsafeMutablePointer(to: inout value).
//
// Provenance: 2026-04-24 Ownership.Borrow / Property.View @inlinable-removal
//             workaround (swift-primitives/swift-ownership-primitives `ece5d7e`;
//             swift-primitives/swift-property-primitives `764db07`).
//
// The production workaround removed @inlinable from init(borrowing:) because
// @inlinable + borrowing + ~Copyable + withUnsafePointer crashes in release
// (the compiler bug documented in the borrow-pointer-storage-release-miscompile
// experiment, V1). We cannot A/B benchmark that exact shape because the
// @inlinable variant crashes. Instead we measure the inout variant, which
// works correctly under @inlinable (V8 from the same experiment) and exhibits
// the same function-call-boundary calling convention: the delta is the pure
// per-init cost of crossing a non-inlined module boundary.

public struct InlineWrapper<Value: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _pointer: UnsafeMutableRawPointer

    @inlinable
    @_lifetime(&value)
    public init(_ value: inout Value) {
        unsafe (
            self._pointer = withUnsafeMutablePointer(to: &value) {
                UnsafeMutableRawPointer($0)
            }
        )
    }

    @inlinable
    public var opaque: UnsafeMutableRawPointer { _pointer }
}

public struct OutOfLineWrapper<Value: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _pointer: UnsafeMutableRawPointer

    @_lifetime(&value)
    public init(_ value: inout Value) {
        unsafe (
            self._pointer = withUnsafeMutablePointer(to: &value) {
                UnsafeMutableRawPointer($0)
            }
        )
    }

    @inlinable
    public var opaque: UnsafeMutableRawPointer { _pointer }
}
