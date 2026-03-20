// Minimal reproduction: swiftlang/swift #86652
//
// The compiler does not synthesize member destruction for ~Copyable structs
// whose stored properties include @_rawLayout types from another package.
// Elements silently leak.
//
// Setup: 3 packages — Element → Storage (@_rawLayout) → Container
//
// When all tests pass, the bug is fixed and production workarounds can be removed.

import Element
import Storage

// MARK: - Control: regular stored property (no @_rawLayout)

struct Control: ~Copyable {
    var element: Tracked
    init(_ id: Int) { element = Tracked(id) }
    deinit {}
}

// MARK: - Bug: @_rawLayout stored property from another package

struct Bug: ~Copyable {
    var box: RawBox<Tracked>
    init(_ id: Int) { box = RawBox(Tracked(id)) }
    deinit {}
}

// MARK: - Workaround: AnyObject? forces deinit + manual cleanup

struct Fixed: ~Copyable {
    var box: RawBox<Tracked>
    private var _deinitWorkaround: AnyObject? = nil
    init(_ id: Int) { box = RawBox(Tracked(id)) }

    deinit {
        unsafe withUnsafePointer(to: box) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.destroy()
        }
    }
}

// MARK: - Test Runner

nonisolated(unsafe) var failures = 0

func test(_ name: String, expected: Int, body: () -> Void) {
    deinitCount = 0
    body()
    let passed = deinitCount == expected
    if !passed { failures += 1 }
    print("\(passed ? "PASS" : "FAIL"): \(name) — expected \(expected), got \(deinitCount)")
}

print("=== swiftlang/swift #86652 ===\n")

test("Control (no @_rawLayout)", expected: 1) {
    let _ = Control(1)
}

test("Bug (@_rawLayout cross-package)", expected: 1) {
    let _ = Bug(2)
}

test("Workaround (AnyObject? + manual cleanup)", expected: 1) {
    let _ = Fixed(3)
}

print("\n=== \(failures) failure(s) ===")
if failures > 0 {
    print("Bug #86652 still present.")
} else {
    print("Bug #86652 FIXED — remove all workarounds.")
}
