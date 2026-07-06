// MARK: - @_lifetime Through a Generic RawValue (String<Char, Backing>) — Design-Convergence Spike
//
// Purpose: Re-validate Option G's two-level @_lifetime chain when the concrete
//   RawValue (PlatformString) is replaced by a GENERIC String<Char, Backing>.
//   Baseline open question §8.3 (string-path-parameterization-arc-baseline.md).
//   The validated `tagged-two-level-lifetime` experiment proved the chain for a
//   CONCRETE RawValue; this spike adds exactly one factor — genericity — per
//   [EXP-021], modeling the PRODUCTION mechanism (the base-address detour through
//   the Tagged.underlying borrow boundary, per Tagged+String.swift:79 and
//   String.swift:186-216).
//
// Hypotheses (one distinct hypothesis per variant, per [EXP-011a]):
//   V1a  inner @_lifetime span — CharOnlyString<Char>          (axis ② only: generic Char, concrete backing)
//   V1b  inner @_lifetime span — GenericString<Char,Backing>   (axes ②+③: generic Char + generic Backing seam)
//   V2   inner @_lifetime ~Escapable View through the generic
//   V3   outer Tagged detour, CONCRETE  (where Underlying == GenericString<UInt8,HeapStub>)   — option (a)
//   V4   outer Tagged detour, GENERIC   (where Underlying: ContiguousString)                  — option (b), scalability crux
//   V5   outer Tagged ~Escapable View detour through the generic
//   V6   one-parameter String1<Storage>                        (folds Char+Backing — §8.1 comparison)
//   V7   type distinctness: encoding (UInt8 != UInt16) × domain (Kernel != Loader) through the generic
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101) — default toolchain
// Platform: macOS 26.0 (arm64)
// Settings: Lifetimes + LifetimeDependence + StrictMemorySafety; debug AND release; cross-module ([EXP-017])
// Status: CONFIRMED — V1a–V7 pass in BOTH debug and release (8/8 variants), 0 compile errors.
// Result:
//   V1a CONFIRMED  inner @_lifetime span — CharOnlyString<Char>            (count=3, first=65)
//   V1b CONFIRMED  inner @_lifetime span — GenericString<Char,Backing>     (count=2, first=72)
//   V2  CONFIRMED  ~Escapable View through the generic                     (length=4, first=88)
//   V3  CONFIRMED  outer Tagged detour, CONCRETE  (option a)               (count=4, first=47)
//   V4  CONFIRMED  outer Tagged detour, GENERIC where Underlying: ContiguousString (option b) (count=3, first=100)
//   V5  CONFIRMED  ~Escapable View two-level detour through the generic    (length=5, first=97)
//   V6  CONFIRMED  one-parameter String1<Storage>                         (count=3, first=10)
//   V7  CONFIRMED  encoding × domain distinctness through the generic      (kU8=2, kU16=1, lU8=3)
//
// Findings (feed baseline §8):
//   - §8.3 ANSWERED: the two-level @_lifetime chain (production base-address detour) holds
//     through a generic String<Char, Backing> — inner AND outer, Span AND ~Escapable View,
//     in RELEASE (where #87029-class SIL/CopyPropagation bugs surface). No new lifetime
//     limitation found by genericizing the RawValue.
//   - §8.1 input: BOTH the two-parameter (V1b) and one-parameter (V6) shapes compile and
//     propagate @_lifetime. Two-parameter call sites are flatter
//     (GenericString<UInt8,HeapStub> vs String1<HeapStorage<UInt8>>).
//   - §8.2 input: adding the Backing generic (V1a -> V1b) introduced NO lifetime friction;
//     the generic-Backing seam (per-access base derivation, [MEM-SAFE-029]) works.
//   - Cascade detail: the GENERIC outer Tagged extension (V4) is viable as a SINGLE extension
//     (`where Underlying: ContiguousString, Underlying: ~Copyable & ~Escapable`) — so one
//     protocol-mediated extension can replace per-instantiation Tagged extensions. It REQUIRES
//     the explicit ~Copyable/~Escapable suppression restatement ([COPY-FIX-003]); the CONCRETE
//     same-type extension (V3) compiles without it.
//
// Date: 2026-06-29
// Warnings: 4 residual, all strict-memory-safety annotation hygiene in the test-harness
//   allocation helpers (makeHeap/makeStorage). Non-load-bearing per [SUPER-037] (no
//   infinite-recursion / immediate-deinit / unreachable). Hypothesis code (StringLib /
//   TaggedLib) compiles warning-clean; the 8/8 runtime asserts prove correct behavior directly.
//
// Fidelity notes:
//   - Tag is ~Copyable & ~Escapable (production shape). Underlying is the generic String.
//   - Tagged.underlying is a stored property; production reaches it via a Carrier
//     `borrowing get` and uses the SAME base-address detour this spike exercises.
//   - No `#if os(...)` appears anywhere — [EXP-017a] (#if-gated matrix) does not apply.
//   - §6 shadowing (bare `String` vs `Swift.String`) is NOT re-tested here; it is already
//     CONFIRMED by `typealias-without-reexport` and is a by-construction win of genericity.

import StringLib

// --- allocation helpers: all raw-pointer plumbing is contained here, so the
// --- test bodies stay @safe-clean (the helpers return the @safe *Stub types). ---
func makeHeap(_ bytes: [UInt8]) -> HeapStub {
    let n = bytes.count
    let raw = unsafe UnsafeMutableRawPointer.allocate(
        byteCount: n, alignment: MemoryLayout<UInt8>.alignment
    )
    let typed = raw.bindMemory(to: UInt8.self, capacity: n)
    for i in 0..<n { unsafe typed[i] = bytes[i] }
    return unsafe HeapStub(adopting: raw)
}

func makeStorage(_ bytes: [UInt8]) -> HeapStorage<UInt8> {
    let n = bytes.count
    let raw = unsafe UnsafeMutableRawPointer.allocate(
        byteCount: n, alignment: MemoryLayout<UInt8>.alignment
    )
    let typed = raw.bindMemory(to: UInt8.self, capacity: n)
    for i in 0..<n { unsafe typed[i] = bytes[i] }
    return unsafe HeapStorage<UInt8>(adopting: raw, count: n)
}

// ============================================================================
// V1a — inner span through CharOnlyString<Char> (generic Char, concrete backing)
// ============================================================================
func testV1a() {
    let s = CharOnlyString<UInt8>(backing: makeHeap([65, 66, 67]), count: 3)   // "ABC"
    let sp = s.span
    precondition(sp.count == 3, "V1a: count")
    precondition(sp[0] == 65 && sp[2] == 67, "V1a: content")
    print("V1a (CharOnlyString<Char>.span — generic Char): CONFIRMED — count=\(sp.count), first=\(sp[0])")
}

// ============================================================================
// V1b — inner span through GenericString<Char, Backing> (both axes generic)
// ============================================================================
func testV1b() {
    let s = GenericString<UInt8, HeapStub>(backing: makeHeap([72, 73]), count: 2)   // "HI"
    let sp = s.span
    precondition(sp.count == 2, "V1b: count")
    precondition(sp[0] == 72 && sp[1] == 73, "V1b: content")
    print("V1b (GenericString<Char,Backing>.span — generic Char + generic Backing): CONFIRMED — count=\(sp.count), first=\(sp[0])")
}

// ============================================================================
// V2 — ~Escapable View through GenericString<Char, Backing>
// ============================================================================
func testV2() {
    let s = GenericString<UInt8, HeapStub>(backing: makeHeap([88, 89, 90, 87]), count: 4)   // "XYZW"
    let v = s.view
    precondition(v.length == 4, "V2: view length")
    let sp = v.span
    precondition(sp[0] == 88 && sp[3] == 87, "V2: view content")
    print("V2 (GenericString.View — ~Escapable through generic): CONFIRMED — length=\(v.length), first=\(sp[0])")
}

// ============================================================================
// V3 — CONCRETE outer Tagged detour (where Underlying == GenericString<UInt8,HeapStub>)
// ============================================================================
func testV3() {
    let t: Tagged<Kernel, GenericString<UInt8, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([47, 116, 109, 112]), count: 4))   // "/tmp"
    let sp = t.spanConcrete                      // two-level: Tagged -> underlying.base+count -> rebuild -> re-parent
    precondition(sp.count == 4, "V3: count")
    precondition(sp[0] == 47, "V3: content")
    print("V3 (Tagged concrete .spanConcrete — option a): CONFIRMED — count=\(sp.count), first=\(sp[0])")
}

// ============================================================================
// V4 — GENERIC outer Tagged detour (where Underlying: ContiguousString) — THE crux
// ============================================================================
func testV4() {
    let t: Tagged<Kernel, GenericString<UInt8, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([100, 101, 102]), count: 3))   // "def"
    let sp = t.span                              // resolves via `where Underlying: ContiguousString`
    precondition(sp.count == 3, "V4: count")
    precondition(sp[0] == 100 && sp[2] == 102, "V4: content")
    print("V4 (Tagged generic .span where Underlying: ContiguousString — option b): CONFIRMED — count=\(sp.count), first=\(sp[0])")
}

// ============================================================================
// V5 — ~Escapable View through the outer Tagged layer (two-level, generic inner)
// ============================================================================
func testV5() {
    let t: Tagged<Kernel, GenericString<UInt8, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([97, 98, 99, 100, 101]), count: 5))   // "abcde"
    let v = t.view                               // two-level ~Escapable detour
    precondition(v.length == 5, "V5: length")
    let sp = v.span
    precondition(sp[0] == 97 && sp[4] == 101, "V5: content")
    print("V5 (Tagged.view — ~Escapable two-level through generic): CONFIRMED — length=\(v.length), first=\(sp[0])")
}

// ============================================================================
// V6 — one-parameter String1<Storage> (§8.1 comparison)
// ============================================================================
func testV6() {
    let s = String1<HeapStorage<UInt8>>(makeStorage([10, 20, 30]))
    let sp = s.span
    precondition(sp.count == 3, "V6: count")
    precondition(sp[0] == 10 && sp[2] == 30, "V6: content")
    print("V6 (String1<Storage>.span — one-parameter framing): CONFIRMED — count=\(sp.count), first=\(sp[0])")
}

// ============================================================================
// V7 — type distinctness: encoding × domain orthogonality through the generic
// ============================================================================
// These functions only typecheck if the four instantiations are distinct nominal
// types. The commented calls document the negative (they would NOT compile).
func wantKernelU8(_ s: borrowing Tagged<Kernel, GenericString<UInt8, HeapStub>>) -> Int { s.count }
func wantKernelU16(_ s: borrowing Tagged<Kernel, GenericString<UInt16, HeapStub>>) -> Int { s.count }
func wantLoaderU8(_ s: borrowing Tagged<Loader, GenericString<UInt8, HeapStub>>) -> Int { s.count }

func testV7() {
    let kU8: Tagged<Kernel, GenericString<UInt8, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([1, 2]), count: 2))
    // UInt16: 1 element = 2 bytes.
    let kU16: Tagged<Kernel, GenericString<UInt16, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([3, 0]), count: 1))
    let lU8: Tagged<Loader, GenericString<UInt8, HeapStub>> =
        .init(_unchecked: GenericString(backing: makeHeap([4, 5, 6]), count: 3))

    let a = wantKernelU8(kU8)
    let b = wantKernelU16(kU16)
    let c = wantLoaderU8(lU8)
    // wantKernelU8(kU16) // ❌ encoding mismatch (UInt8 != UInt16) — would not compile
    // wantKernelU8(lU8)  // ❌ domain mismatch (Kernel != Loader)   — would not compile
    precondition(a == 2 && b == 1 && c == 3, "V7: counts")
    print("V7 (distinctness: encoding × domain through generic): CONFIRMED — kU8=\(a), kU16=\(b), lU8=\(c)")
}

testV1a()
testV1b()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()

print("\nAll variants complete.")
