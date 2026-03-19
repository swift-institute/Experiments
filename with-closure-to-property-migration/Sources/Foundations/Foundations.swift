// ============================================================
// with-closure-to-property-migration — Foundations module
//
// Simulates swift-foundations types that wrap primitives types
// and provide cross-module ~Escapable property access.
//
// Gap D: Cross-module chaining. Can Foundations return a
//        ~Escapable value obtained from a Primitives property?
//
// Types:
//   FoundationPath  — wraps OwnedBuffer (mirrors Path in swift-paths)
//   BridgedView     — Foundations-side ~Escapable view (mirrors Kernel.Path.View bridge)
// ============================================================

public import Primitives


// ============================================================
// V6: Cross-module wrapper returning ~Escapable view
// Replaces: path.withKernelPath { kernelView in ... }
//
// Tests:
//   V6a — Return Primitives' BorrowedView through cross-module property
//   V6b — Create Foundations' BridgedView from Primitives' BorrowedView
//         (two-hop: FoundationPath → OwnedBuffer.view → BridgedView)
// ============================================================

public struct FoundationPath: ~Copyable {
    @usableFromInline
    internal let _inner: OwnedBuffer

    @inlinable
    public init(_ bytes: [UInt8]) {
        self._inner = OwnedBuffer(bytes)
    }

    /// V6a: Cross-module — return Primitives' ~Escapable type
    public var view: BorrowedView {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = _inner.view
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }

    /// V6b: Two-hop bridge — Primitives view → Foundations view
    /// Mirrors: Path.withKernelPath creating Kernel.Path.View
    public var bridgedView: BridgedView {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = _inner.view
            let bv = unsafe BridgedView(v.pointer, count: v.count)
            return unsafe _overrideLifetime(bv, borrowing: self)
        }
    }

    /// V6c: Cross-module Span chain
    /// FoundationPath → OwnedBuffer.view → BorrowedView.span
    public var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = _inner.view
            let s = v.span
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}


// ============================================================
// BridgedView — a DIFFERENT ~Escapable type defined in Foundations
// Mirrors Kernel.Path.View as seen from swift-paths
// ============================================================

public struct BridgedView: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<UInt8>
    public let count: Int

    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<UInt8>, count: Int) {
        unsafe (self.pointer = pointer)
        self.count = count
    }

    public var span: Span<UInt8> {
        @_lifetime(copy self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}


// ============================================================
// S11: Cross-module EXTENSION adding ~Escapable property
// to a type from Primitives.
//
// This is the EXACT production pattern:
//   swift-paths defines extension on Path (from primitives)
//   adding .kernelPath returning Kernel.Path.View
// ============================================================

extension OwnedBuffer {
    /// Property added by Foundations module on Primitives type
    public var extensionView: BridgedView {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = self.view
            let bv = unsafe BridgedView(v.pointer, count: v.count)
            return unsafe _overrideLifetime(bv, borrowing: self)
        }
    }
}
