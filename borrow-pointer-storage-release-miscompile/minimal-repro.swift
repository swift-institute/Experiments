// Minimal standalone reproducer for a Swift 6.3.1 / 6.4-dev release-mode bug.
//
// This file is deliberately NOT under Sources/ — it has its own entry point
// and is meant to be built with bare `swiftc`, independent of SwiftPM. The
// 9-variant hypothesis discriminator in Sources/main.swift is the extended
// reproducer; this file is the minimal-file version suitable for attaching
// directly to an upstream swiftlang/swift bug report.
//
// Claim: `withUnsafePointer(to: value)` where `value: borrowing T` for
//        `T: ~Copyable` does NOT return a stable caller address in release
//        mode, despite `@_lifetime(borrow value)` on the enclosing init.
//        The sibling pattern `withUnsafeMutablePointer(to: &value)` with
//        `value: inout T` DOES return a stable caller address, proving this
//        is specific to the `borrowing` overload of `withUnsafePointer` when
//        called from an `@inlinable` site that gets inlined at `-O`.
//
// Build + run (release, reproduces):
//   swiftc -O minimal-repro.swift \
//       -enable-experimental-feature Lifetimes \
//       -enable-experimental-feature LifetimeDependence \
//       -o /tmp/minimal-repro
//   /tmp/minimal-repro
//
// Build + run (debug, does not reproduce):
//   swiftc -Onone minimal-repro.swift \
//       -enable-experimental-feature Lifetimes \
//       -enable-experimental-feature LifetimeDependence \
//       -o /tmp/minimal-repro-debug
//   /tmp/minimal-repro-debug
//
// Observed on Swift 6.3.1 (Xcode 26.4.1) AND swift-DEVELOPMENT-SNAPSHOT-
// 2026-03-16-a (6.4-dev), macOS 26 arm64:
//   V1 (borrowing): a = 0  b = 0   (expected 42, 42) — dangling pointer
//   V2 (inout):     a = 42 b = 42  — stable
//
// Debug mode (`-Onone`): both variants print (42, 42).
//
// Workaround in ecosystem code: remove `@inlinable` from the enclosing init.
// See swift-primitives/swift-ownership-primitives commit `ece5d7e` and
// swift-institute/Audits/borrow-pointer-storage-release-miscompile.md.

struct NC: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}

// MARK: - V1 (broken): borrowing + withUnsafePointer

@safe
struct BorrowRef<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

func readBorrow(_ value: borrowing NC) -> (Int, Int) {
    let ref = BorrowRef(borrowing: value)
    let a = ref.value.x
    let b = ref.value.x
    return (a, b)
}

// MARK: - V2 (works): inout + withUnsafeMutablePointer

@safe
struct InoutRef<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    @_lifetime(&value)
    init(mutating value: inout Value) {
        unsafe (self._pointer = withUnsafeMutablePointer(to: &value) { $0 })
    }

    @inlinable
    var value: Value {
        _read { yield unsafe _pointer.pointee }
    }
}

func readInout(_ value: inout NC) -> (Int, Int) {
    let ref = InoutRef(mutating: &value)
    let a = ref.value.x
    let b = ref.value.x
    return (a, b)
}

// MARK: - Drive

let source1 = NC(42)
let (v1a, v1b) = readBorrow(source1)
print("V1 (borrowing): a = \(v1a)  b = \(v1b)  (expected 42, 42)")

var source2 = NC(42)
let (v2a, v2b) = readInout(&source2)
print("V2 (inout):     a = \(v2a)  b = \(v2b)  (expected 42, 42)")
