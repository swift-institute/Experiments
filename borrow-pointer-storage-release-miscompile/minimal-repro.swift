// Minimal reproducer for a Swift 6.3.1 / 6.4-dev release-mode miscompile.
//
// No package imports. Pure stdlib + two experimental features. This file
// lives adjacent to Package.swift (outside Sources/) so it builds with bare
// `swiftc`, independent of SwiftPM. The 9-variant hypothesis discriminator
// in Sources/main.swift extends the reproducer; this file is the
// minimum-bar attachment suitable for direct upstream bug-report filing.
//
// Claim: given
//
//   (1) a `~Escapable` struct that stores an `UnsafeRawPointer`,
//   (2) constructed via `withUnsafePointer(to: borrowing value)` inside
//       an `@inlinable` init with `@_lifetime(borrow value)`,
//   (3) generic over `Value: ~Copyable`,
//
// the stored pointer is invalid after the init returns in release mode.
// `.value` reads through the pointer return garbage (0 observed on macOS
// 26 arm64). The sibling construction — `inout value` parameter plus
// `withUnsafeMutablePointer(to: &value)` — works correctly with the same
// storage pattern. The difference is the calling convention: `inout` is
// always `@inout` (indirect); `borrowing Value: ~Copyable` is supposed to
// be `@in_guaranteed` (indirect) but the inlined form appears to lose it.
//
// Build + run (release, reproduces):
//
//   swiftc -O minimal-repro.swift \
//       -enable-experimental-feature Lifetimes \
//       -enable-experimental-feature LifetimeDependence \
//       -o /tmp/minimal-repro
//   /tmp/minimal-repro
//
// Build + run (debug, does not reproduce):
//
//   swiftc -Onone minimal-repro.swift \
//       -enable-experimental-feature Lifetimes \
//       -enable-experimental-feature LifetimeDependence \
//       -o /tmp/minimal-repro-debug
//   /tmp/minimal-repro-debug
//
// Toolchain:
//
//   Swift 6.3.1 (Xcode 26.4.1 default)           — STILL PRESENT
//   swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a      — STILL PRESENT
//   Platform: macOS 26 (arm64)
//
// Observed output (release):
//
//   V1 (borrowing): a = 0   b = 0    (expected 42, 42) — dangling
//   V2 (inout):     a = 42  b = 42                     — stable
//
// Observed output (debug): both variants print (42, 42).
//
// Narrow workaround observed empirically: remove `@inlinable` from V1's
// init. Cross-module function-call boundary preserves the `@in_guaranteed`
// indirect ABI; `Builtin.addressOfBorrow(value)` inside the callee then
// yields the caller's actual storage address. This file keeps `@inlinable`
// on V1 deliberately so the bug reproduces from a single file.
//
// Status: STILL PRESENT (as of Swift 6.3.1 and 6.4-dev snapshot 2026-03-16-a)
// Date:   2026-04-24

// MARK: - Test value

struct Payload: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}

// MARK: - V1: borrowing + withUnsafePointer (broken in release)

@safe
struct RefV1<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(_ value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

func readV1(_ value: borrowing Payload) -> (Int, Int) {
    let r = RefV1(value)
    let a = r.value.x
    let b = r.value.x
    return (a, b)
}

// MARK: - V2: inout + withUnsafeMutablePointer (works in release)

@safe
struct RefV2<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    @_lifetime(&value)
    init(_ value: inout Value) {
        unsafe (self._pointer = withUnsafeMutablePointer(to: &value) { $0 })
    }

    @inlinable
    var value: Value {
        _read { yield unsafe _pointer.pointee }
    }
}

func readV2(_ value: inout Payload) -> (Int, Int) {
    let r = RefV2(&value)
    let a = r.value.x
    let b = r.value.x
    return (a, b)
}

// MARK: - Drive

let source1 = Payload(42)
let (v1a, v1b) = readV1(source1)
print("V1 (borrowing): a = \(v1a)  b = \(v1b)  (expected 42, 42)")

var source2 = Payload(42)
let (v2a, v2b) = readV2(&source2)
print("V2 (inout):     a = \(v2a)  b = \(v2b)  (expected 42, 42)")
