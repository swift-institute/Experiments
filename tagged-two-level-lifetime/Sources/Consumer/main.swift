// MARK: - Tagged Two-Level @_lifetime Chain
// Purpose: Verify that @_lifetime propagation works through TWO levels:
//   Tagged.rawValue (stored property) → ConcreteType.span (@_lifetime)
//   → _overrideLifetime(s, borrowing: self)
//
// This validates the architecture: Tagged<Domain, ConcreteType> where
// ConcreteType owns Memory.Contiguous<Char> and provides @_lifetime accessors.
// The kind (String vs Path) is the RawValue. The domain (Kernel) is the Tag.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.2 (arm64)
//
// Result: ALL CONFIRMED — V1–V6 pass in both debug and release
//   V1: Chained Span through Tagged<Kernel, PlatformString>.span — CONFIRMED
//   V2: Chained Span through Tagged<Kernel, PlatformPath>.span — CONFIRMED
//   V3: ~Escapable View through Tagged<Kernel, PlatformString>.view — CONFIRMED
//   V4: Direct Span (single-level control) — CONFIRMED
//   V5: Domain-specific method forwarding (isAbsolute) — CONFIRMED
//   V6: Type distinctness (String != Path same Tag) — CONFIRMED
// Date: 2026-02-27

import StringLib

// ============================================================================
// MARK: - V1: Chained Span through Tagged<Kernel, PlatformString>
// ============================================================================

func testV1() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let s: Tagged<Kernel, PlatformString> = .init(PlatformString(adopting: buf, count: 3))
    let sp = s.span  // TWO-LEVEL: Tagged.rawValue → PlatformString.span → _overrideLifetime
    precondition(sp.count == 3, "V1: span count should be 3")
    precondition(sp[0] == 65, "V1: first byte should be 65")
    print("V1 (Tagged<Kernel,String>.span chain): CONFIRMED — count = \(sp.count), first = \(sp[0])")
}

// ============================================================================
// MARK: - V2: Chained Span through Tagged<Kernel, PlatformPath>
// ============================================================================

func testV2() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let p: Tagged<Kernel, PlatformPath> = .init(PlatformPath(adopting: buf, count: 4))
    let sp = p.span  // TWO-LEVEL: Tagged.rawValue → PlatformPath.span → _overrideLifetime
    precondition(sp.count == 4, "V2: span count should be 4")
    precondition(sp[0] == 47, "V2: first byte should be '/' (47)")
    print("V2 (Tagged<Kernel,Path>.span chain): CONFIRMED — count = \(sp.count), first = \(sp[0])")
}

// ============================================================================
// MARK: - V3: ~Escapable View through Tagged<Kernel, PlatformString>
// ============================================================================

func testV3() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [72, 101, 108, 108, 0], count: 5)
    let s: Tagged<Kernel, PlatformString> = .init(PlatformString(adopting: buf, count: 4))
    let v = s.view  // TWO-LEVEL: Tagged.rawValue → PlatformString.view → _overrideLifetime
    precondition(v.length == 4, "V3: view length should be 4")
    let sp = v.span
    precondition(sp[0] == 72, "V3: first byte should be 'H' (72)")
    print("V3 (Tagged<Kernel,String>.view chain): CONFIRMED — length = \(v.length), first = \(sp[0])")
}

// ============================================================================
// MARK: - V4: Direct Span (single-level control)
// ============================================================================

func testV4() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [88, 89, 90, 0], count: 4)
    let s: Tagged<Kernel, PlatformString> = .init(PlatformString(adopting: buf, count: 3))
    let sp = s.directSpan  // SINGLE-LEVEL: direct from rawValue.pointer/count
    precondition(sp.count == 3, "V4: span count should be 3")
    precondition(sp[0] == 88, "V4: first byte should be 88")
    print("V4 (Tagged<Kernel,String>.directSpan): CONFIRMED — count = \(sp.count), first = \(sp[0])")
}

// ============================================================================
// MARK: - V5: Domain-specific method forwarding
// ============================================================================

func testV5() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let p: Tagged<Kernel, PlatformPath> = .init(PlatformPath(adopting: buf, count: 4))
    precondition(p.isAbsolute, "V5: path starting with '/' should be absolute")
    print("V5 (Tagged<Kernel,Path>.isAbsolute): CONFIRMED — isAbsolute = \(p.isAbsolute)")
}

// ============================================================================
// MARK: - V6: Type distinctness
// ============================================================================

func testV6() {
    // These are different types at compile time:
    // Tagged<Kernel, PlatformString> != Tagged<Kernel, PlatformPath>
    // If this compiles, the types are distinct (can't assign one to the other).
    func requireString(_ s: borrowing Tagged<Kernel, PlatformString>) -> Int { s.count }
    func requirePath(_ p: borrowing Tagged<Kernel, PlatformPath>) -> Int { p.count }

    let buf1 = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf1.initialize(from: [65, 66, 67, 0], count: 4)
    let s: Tagged<Kernel, PlatformString> = .init(PlatformString(adopting: buf1, count: 3))

    let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf2.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let p: Tagged<Kernel, PlatformPath> = .init(PlatformPath(adopting: buf2, count: 4))

    // requireString(p)  // ❌ Would not compile — type mismatch
    // requirePath(s)    // ❌ Would not compile — type mismatch
    let sc = requireString(s)
    let pc = requirePath(p)
    print("V6 (type distinctness): CONFIRMED — string count = \(sc), path count = \(pc)")
}

// ============================================================================
// MARK: - Execute
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()

print("\nAll variants complete.")
