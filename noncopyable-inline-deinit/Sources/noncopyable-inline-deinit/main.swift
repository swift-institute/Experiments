// MARK: - ~Copyable Inline Storage Deinit Bug (Cross-Module)
// Purpose: Verify deinit fires correctly for ~Copyable structs with CROSS-MODULE elements
// Status: BUG REPRODUCED (2026-01-20, Swift 6.2)
// Revalidation: FIXED in Swift 6.2.4 — deinits fire correctly (2026-03-10)
// Result: BUG REPRODUCED — cross-module ~Copyable inline deinit was broken in Swift 6.2, fixed in 6.2.4
//
// This experiment mirrors production: Tracked element is defined in a separate Lib module,
// containers are defined here. This is the critical cross-module case that production uses.
//
// Variants:
//   V1: Header + Storage.Inline pattern (mirrors Buffer.Ring.Inline, Buffer.Linear.Inline)
//   V2: Two inline storages (mirrors Set.Ordered.Static with buffer + hash table)
//   V3: Inline + Optional heap (mirrors Set.Ordered.Small with buffer + optional hash table)
//   V4: Control — same as V1 but with AnyObject? property (the old workaround)

import Lib

// MARK: - Variant 1: Header + Inline Storage (no AnyObject)
// Mirrors: Buffer.Ring.Inline, Buffer.Linear.Inline WITHOUT _deinitWorkaround

struct V1_Container: ~Copyable {
    var header: Int  // value-type header
    var element: Tracked

    init(_ id: Int) {
        self.header = 0
        self.element = Tracked(id)
    }

    deinit {
        print("V1_Container deinit")
    }
}

// MARK: - Variant 2: Two value-type storages (no AnyObject)
// Mirrors: Set.Ordered.Static with buffer + hash table

struct V2_Container: ~Copyable {
    var a: Tracked
    var b: Tracked

    init(_ idA: Int, _ idB: Int) {
        self.a = Tracked(idA)
        self.b = Tracked(idB)
    }

    deinit {
        print("V2_Container deinit")
    }
}

// MARK: - Variant 3: Inline + Optional (no AnyObject)
// Mirrors: Set.Ordered.Small with buffer + optional heap hash table

struct V3_Container: ~Copyable {
    var element: Tracked
    var optionalRef: AnyObject?  // Optional class ref, but NOT the workaround pattern

    init(_ id: Int) {
        self.element = Tracked(id)
        self.optionalRef = nil
    }

    deinit {
        print("V3_Container deinit")
    }
}

// MARK: - Variant 4: Control — with AnyObject workaround
// This is the OLD pattern we're removing. Should also pass.

struct V4_Container: ~Copyable {
    var header: Int
    var element: Tracked
    var _deinitWorkaround: AnyObject? = nil

    init(_ id: Int) {
        self.header = 0
        self.element = Tracked(id)
    }

    deinit {
        print("V4_Container deinit")
    }
}

// MARK: - Test Runner

func test(_ name: String, expected: Int, body: () -> Void) {
    deinitCount = 0
    body()
    let passed = deinitCount == expected
    print("\(passed ? "PASS" : "FAIL"): \(name) — expected \(expected), got \(deinitCount)")
    if !passed { print("  *** REGRESSION: deinit not firing without workaround ***") }
}

print("=== Cross-Module Deinit Verification ===\n")

test("V1: Header + element (no workaround)", expected: 1) {
    let _ = V1_Container(1)
}

print()
test("V2: Two elements (no workaround)", expected: 2) {
    let _ = V2_Container(10, 20)
}

print()
test("V3: Element + optional ref (no workaround)", expected: 1) {
    let _ = V3_Container(30)
}

print()
test("V4: Control — with AnyObject workaround", expected: 1) {
    let _ = V4_Container(40)
}

print("\n=== Done ===")
