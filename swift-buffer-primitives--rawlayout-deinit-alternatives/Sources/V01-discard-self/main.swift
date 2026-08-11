// MARK: - V01: `discard self` Availability for Cleanup
// Purpose: Test whether `discard self` can replace deinit for @_rawLayout types.
//          `discard self` suppresses the implicit destructor, allowing consuming
//          cleanup methods. BUT it requires all stored properties to be trivially
//          destructible.
// Hypothesis: @_rawLayout types are trivially destructible (can use discard self)
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — @_rawLayout types are NOT trivially destructible.
//         `discard self` CANNOT be used with @_rawLayout stored properties.
//         AnyObject? and closures are also NOT trivially destructible (ARC).
//         Only tuples, raw pointers, and InlineArray of trivial types work.
//
//         V1: CONFIRMED — trivial properties (Int) support discard self
//         V2: REFUTED   — AnyObject? NOT trivially destructible
//         V4: REFUTED   — @_rawLayout NOT trivially destructible
//         V5: CONFIRMED — consuming pattern works but no discard
//         V6: CONFIRMED — UnsafeMutablePointer approach with discard
//         V7: CONFIRMED — InlineArray storage with discard
//         V8: CONFIRMED — Tuple storage with discard
//
// Date: 2026-03-21
//
// Swift 6.3: STILL BROKEN — workaround remains necessary
//
// Consolidates: discard-self-availability (V1-V10)
// Supports: eliminates discard self as workaround for @_rawLayout

// --- V1: Basic discard with trivial properties ---
// Result: CONFIRMED — works

struct V1_Trivial: ~Copyable {
    var value: Int

    consuming func destroy() {
        print("V1: destroying value \(value)")
        discard self
    }

    deinit {
        print("V1: deinit (should not be called if destroy() used)")
    }
}

// --- V4: @_rawLayout struct ---
// Result: REFUTED — error: "cannot use 'discard self' with non-trivially-destructible type"

// UNCOMMENT TO TEST:
// @_rawLayout(size: 16, alignment: 8)
// struct V4_RawLayout: ~Copyable {
//     consuming func destroy() {
//         discard self  // ERROR: @_rawLayout is not trivially destructible
//     }
//     deinit { }
// }

// --- V6: UnsafeMutablePointer approach (works with discard) ---
// Result: CONFIRMED

struct V6_Pointer: ~Copyable {
    let ptr: UnsafeMutablePointer<Int>
    let count: Int

    init(capacity: Int) {
        self.ptr = .allocate(capacity: capacity)
        self.count = 0
    }

    consuming func destroy() {
        for i in 0..<count {
            unsafe ptr.advanced(by: i).deinitialize(count: 1)
        }
        ptr.deallocate()
        discard self
    }

    deinit {
        for i in 0..<count {
            unsafe ptr.advanced(by: i).deinitialize(count: 1)
        }
        ptr.deallocate()
    }
}

// --- V7: InlineArray storage (works with discard) ---
// Result: CONFIRMED

struct V7_InlineArray: ~Copyable {
    var _storage: InlineArray<4, Int>
    var count: Int

    init() {
        self._storage = InlineArray(repeating: 0)
        self.count = 0
    }

    consuming func destroy() {
        print("V7: destroying InlineArray storage")
        discard self
    }

    deinit {
        print("V7: deinit")
    }
}

// --- Tests ---

func testV1() {
    print("=== V1: Trivial properties ===")
    var v = V1_Trivial(value: 42)
    v.destroy()
}

func testV6() {
    print("\n=== V6: UnsafeMutablePointer ===")
    var v = V6_Pointer(capacity: 4)
    v.destroy()
    print("V6: OK — pointer + discard works")
}

func testV7() {
    print("\n=== V7: InlineArray ===")
    var v = V7_InlineArray()
    v.destroy()
    print("V7: OK — InlineArray + discard works")
}

testV1()
testV6()
testV7()

print("\nSUMMARY:")
print("  @_rawLayout: NOT trivially destructible — discard self BLOCKED")
print("  AnyObject?:  NOT trivially destructible — ARC overhead")
print("  UnsafeMutablePointer: trivially destructible — discard works")
print("  InlineArray<N, Trivial>: trivially destructible — discard works")
print("  Tuple of trivials: trivially destructible — discard works")
print("\n  Cannot use discard self to avoid @_rawLayout + deinit bugs.")
print("  Recommendation: Option E + I (package-internal deinitialize)")
