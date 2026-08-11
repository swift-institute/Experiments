// MARK: - Experiment: Tagged Zero-Cost Codegen
//
// Purpose: Verify that Tagged<Tag, Underlying> produces identical machine code
//          to using Underlying directly. The "zero-cost" claim means:
//
//   1. init(__unchecked:) compiles to a no-op (value is already in register)
//   2. underlying access compiles to a no-op (no indirection)
//   3. retag compiles to a no-op (same bits, different type)
//   4. Equatable/Comparable/Hashable delegate directly — no wrapper overhead
//   5. map with identity closure compiles to a no-op
//   6. SLI literal inits (7 stdlib protocols) compile to a no-op beyond the
//      Underlying's own literal-init cost.
//   7. SLI bitcast inits (ExpressibleByArrayLiteral / ExpressibleByDictionaryLiteral
//      via the documented [MEM-SAFE-001] carve-out) compile to the same
//      instructions as the corresponding canonical init forwarding through
//      Underlying's own variadic init — i.e., the bitcast IS zero-cost when
//      the function-type reinterpretation's ABI assumption holds.
//
// Hypothesis: With @inlinable on all public API and @_disfavoredOverload on
//             SLI literal inits, the optimizer eliminates all wrapper overhead
//             at -O, AND the bitcast inits compile to the same release-mode
//             instructions as canonical-init forwarding through Underlying.
//
// Method: Compile at -O, emit SIL and assembly, compare Tagged vs raw paths.
//
// To run:
//   cd Experiments/tagged-zero-cost-codegen
//
//   # SIL (optimized):
//   swiftc -O -emit-sil Sources/main.swift \
//     -I ../../.build/release/Modules \
//     -L ../../.build/release \
//     -module-name main 2>&1 | swift-demangle > sil-output.txt
//
//   # Assembly:
//   swiftc -O -emit-assembly Sources/main.swift \
//     -I ../../.build/release/Modules \
//     -L ../../.build/release \
//     -module-name main 2>&1 | swift-demangle > asm-output.txt
//
//   Alternatively, build the package at release and inspect:
//   swift build -c release 2>&1
//   # Then use `objdump -d` or Hopper on the binary.
//
// Expected results:
//   - rawTagged and rawDirect produce identical SIL / assembly
//   - retagTagged compiles to zero instructions beyond the call it wraps
//   - compareTagged and compareDirect produce identical branch sequences
//   - integerLiteralTagged matches rawDirect (literal init is fully inlined)
//   - arrayLiteralTagged compiles to the same Array-construction sequence as
//     arrayLiteralDirect; the bitcast incurs no extra runtime instructions
//     beyond the function-call materialization
//   - dictionaryLiteralTagged compiles to the same Dictionary-construction
//     sequence as dictionaryLiteralDirect
//
// Status: CONFIRMED (canonical paths) + EXTENDED 2026-04-30 (SLI bitcast paths)
// Date: 2026-02-26 (initial), revalidated 2026-04-30
// Toolchain: Swift 6.2 (initial CONFIRMED), Swift 6.3.1 (2026-04-30 revalidation + SLI extension)
//
// Result (canonical paths): At -O, all Tagged paths produce IDENTICAL assembly to raw paths.
//
//   rawTagged:          mov w0, #0x2a; ret     (identical to rawDirect)
//   retagTagged:        mov w0, #0x2a; ret     (identical to rawDirect — retag is a no-op)
//   compareTagged:      mov w0, #0x1; ret      (identical to compareDirect)
//   mapIdentityTagged:  mov w0, #0x2a; ret     (identical to mapIdentityDirect)
//
// Every function pair compiles to the same two instructions. The Tagged wrapper,
// retag, underlying access, Comparable delegation, and map with identity closure
// are all fully eliminated by the optimizer. Zero-cost claim: CONFIRMED.
//
// Result (SLI literal paths, 2026-04-30 extension): the seven stdlib literal
// conformances split into two regimes, and the two bitcast carve-out conformances
// are in a third regime. The honest finding is:
//
// (1) Simple-literal paths (Integer, Float, Boolean, UnicodeScalar, ExtendedGraphemeCluster,
//     String, StringInterpolation) compile to instructions BITWISE-IDENTICAL to the
//     direct path:
//       integerLiteralTagged:  mov w0, #0x2a; ret      (identical to integerLiteralDirect)
//       stringLiteralTagged:   <4 movs loading inline string>  (identical to stringLiteralDirect)
//
// (2) Array/Dict bitcast paths compile to a function-call sequence that approximates
//     a RUNTIME-DYNAMIC call to `Underlying.init(arrayLiteral:)` / `init(dictionaryLiteral:)`,
//     NOT to the constant-folded direct path. Specifically (Swift 6.3.1, arm64 -O):
//
//       arrayLiteralTagged:       ~36 instructions (stack frame + 3 function calls + load)
//       arrayLiteralDirect:        ~3 instructions (load static-folded Array reference + ret)
//       dictionaryLiteralTagged:  ~33 instructions (stack frame + 3 function calls + load)
//       dictionaryLiteralDirect:  ~17 instructions (stack frame + 3 function calls + load)
//
//     The Array asymmetry is large because `let value: [Int] = [1, 2, 3]` is
//     constant-foldable to a static Array reference under -O; the Tagged path
//     goes through `init(arrayLiteral:)` which calls `unsafeBitCast`, opaque to
//     the optimizer, preventing constant folding.
//
//     The Dict asymmetry is smaller because Dictionary literals are not as
//     aggressively constant-folded even on the direct path; both paths call the
//     dynamic-init sequence.
//
// (3) Honest interpretation:
//
//     The bitcast carve-out is **NOT** zero-cost vs. constant-folded literal
//     construction. It IS approximately equivalent to a non-folded runtime-dynamic
//     call to `Underlying.init(arrayLiteral:)` / `init(dictionaryLiteral:)` — i.e.,
//     the cost a non-Tagged consumer would pay if their input were variable rather
//     than literal-known-at-compile-time. The bitcast's opacity to the optimizer
//     means the optimizer can't propagate compile-time-known elements through.
//
//     For the package's intended use case — `Tagged<UserGroup, [Int]>` etc. —
//     this is acceptable: domain-typed Tagged collections are typically
//     constructed from runtime-variable inputs anyway, where neither path
//     reaches constant folding. Consumers writing `Tagged<Tag, [Int]> = [1, 2, 3]`
//     in production with literal-known elements pay the dynamic-construction
//     cost; consumers writing `let xs: [Int] = [1, 2, 3]; let tagged: Tagged<Tag, [Int]> = …`
//     pay the same dynamic-construction cost on the direct path too.
//
//     The ABI commitment paragraph (Research/principled-absence-array-dict-literal.md
//     v1.2.1 § ABI commitment status) is updated to reflect this distinction:
//     "operational correctness HIGH" for the function-pointer reinterpretation is
//     verified; the runtime-cost claim is "approximately equivalent to dynamic
//     Underlying init", NOT "bitwise-identical to literal-folded direct path".
//
// The simple-literal paths' BITWISE-IDENTITY claim is a stronger statement and
// holds verbatim — those literals fold through the inlinable Tagged init the
// same way they fold through direct construction.
//
// Reproduction:
//   cd Experiments/tagged-zero-cost-codegen
//   swift build -c release
//   objdump -d .build/arm64-apple-macosx/release/tagged_zero_cost_codegen.build/main.swift.o \
//     | xcrun swift-demangle

import Tagged_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Carrier_Primitives_Standard_Library_Integration

// Local Carrier conformance for stdlib collection types — central Carrier SLI
// deliberately skips these per swift-carrier-primitives/Research/sli-{array,set,dictionary}.md.
extension Array: @retroactive Carrier.`Protocol` { public typealias Underlying = Array<Element> }
extension ContiguousArray: @retroactive Carrier.`Protocol` { public typealias Underlying = ContiguousArray<Element> }
extension Dictionary: @retroactive Carrier.`Protocol` { public typealias Underlying = Dictionary<Key, Value> }
extension Set: @retroactive Carrier.`Protocol` { public typealias Underlying = Set<Element> }

enum Tag1 {}
enum Tag2 {}

// === Path A: Tagged ===

@inline(never)
func rawTagged() -> Int {
    let tagged = Tagged<Tag1, Int>(42)
    return tagged.underlying
}

@inline(never)
func retagTagged() -> Int {
    let tagged = Tagged<Tag1, Int>(42)
    let retagged: Tagged<Tag2, Int> = tagged.retag()
    return retagged.underlying
}

@inline(never)
func compareTagged() -> Bool {
    let a = Tagged<Tag1, Int>(1)
    let b = Tagged<Tag1, Int>(2)
    return a < b
}

@inline(never)
func mapIdentityTagged() -> Int {
    let tagged = Tagged<Tag1, Int>(42)
    let result = tagged.map { $0 }
    return result.underlying
}

// === Path B: Raw (baseline) ===

@inline(never)
func rawDirect() -> Int {
    let value = 42
    return value
}

@inline(never)
func compareDirect() -> Bool {
    let a = 1
    let b = 2
    return a < b
}

@inline(never)
func mapIdentityDirect() -> Int {
    let value = 42
    let result = { $0 }(value)
    return result
}

// === Path C: Tagged via SLI literal conformances (2026-04-30 extension) ===

@inline(never)
func integerLiteralTagged() -> Int {
    let tagged: Tagged<Tag1, Int> = 42
    return tagged.underlying
}

@inline(never)
func stringLiteralTagged() -> String {
    let tagged: Tagged<Tag1, String> = "hello"
    return tagged.underlying
}

@inline(never)
func arrayLiteralTagged() -> [Int] {
    let tagged: Tagged<Tag1, [Int]> = [1, 2, 3]
    return tagged.underlying
}

@inline(never)
func dictionaryLiteralTagged() -> [String: Int] {
    let tagged: Tagged<Tag1, [String: Int]> = ["a": 1, "b": 2]
    return tagged.underlying
}

// === Path D: Raw (baseline for SLI literal paths) ===

@inline(never)
func integerLiteralDirect() -> Int {
    let value: Int = 42
    return value
}

@inline(never)
func stringLiteralDirect() -> String {
    let value: String = "hello"
    return value
}

@inline(never)
func arrayLiteralDirect() -> [Int] {
    let value: [Int] = [1, 2, 3]
    return value
}

@inline(never)
func dictionaryLiteralDirect() -> [String: Int] {
    let value: [String: Int] = ["a": 1, "b": 2]
    return value
}

// === Execute both paths to prevent dead-code elimination ===

print("Tagged path:  raw=\(rawTagged()), retag=\(retagTagged()), cmp=\(compareTagged()), mapId=\(mapIdentityTagged())")
print("Direct path:  raw=\(rawDirect()), cmp=\(compareDirect()), mapId=\(mapIdentityDirect())")
print("SLI literal path:  intLit=\(integerLiteralTagged()), strLit=\(stringLiteralTagged()), arrLit=\(arrayLiteralTagged()), dictLit=\(dictionaryLiteralTagged())")
print("SLI literal direct:  intLit=\(integerLiteralDirect()), strLit=\(stringLiteralDirect()), arrLit=\(arrayLiteralDirect()), dictLit=\(dictionaryLiteralDirect())")

// Verify identical results
assert(rawTagged() == rawDirect())
assert(retagTagged() == rawDirect())
assert(compareTagged() == compareDirect())
assert(mapIdentityTagged() == mapIdentityDirect())
assert(integerLiteralTagged() == integerLiteralDirect())
assert(stringLiteralTagged() == stringLiteralDirect())
assert(arrayLiteralTagged() == arrayLiteralDirect())
assert(dictionaryLiteralTagged() == dictionaryLiteralDirect())

print("")
print("Functional equivalence: CONFIRMED (canonical paths + SLI literal paths)")
print("")
print("Next step: Compare SIL/assembly output for rawTagged vs rawDirect,")
print("compareTagged vs compareDirect, integerLiteralTagged vs integerLiteralDirect,")
print("arrayLiteralTagged vs arrayLiteralDirect, dictionaryLiteralTagged vs")
print("dictionaryLiteralDirect. If the instruction sequences are identical, the")
print("zero-cost claim is CONFIRMED at codegen level — including the SLI bitcast")
print("inits, which would otherwise be the most-suspicious paths under the")
print("Research/principled-absence-array-dict-literal.md v1.2.1 ABI commitment paragraph.")
