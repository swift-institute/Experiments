// MARK: - Parser.Protocol Self: ~Copyable Witness-Table Probe
//
// Purpose: Empirically test whether adding `: ~Copyable` to `Self` on
//          `Parser.\`Protocol\`` introduces a cross-module witness-table
//          SIGSEGV at instantiation, per the pattern documented at
//          `swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`.
//
// Critical conditions for the original (2026-02-14, Swift 6.2.3) crash:
//   1. ~Copyable protocol constraint chain (Self or associated type)
//   2. Protocol composition (Wrapper<Upstream: Π> conforming to Π)
//   3. Cross-module concrete type
//   4. Cross-module instantiation (test target ≠ defining module)
//
// This experiment exercises (1)+(2)+(4) at minimum metadata complexity:
// no upstream package deps, all concrete types defined locally.
//
// Toolchain: invoked from default xcrun (Swift 6.3.x); re-runnable under
//            TOOLCHAINS=org.swift.<bundle-id> for 6.2.3 / 6.4-dev nightly.
//
// Result: PENDING — to be filled by execution.
// Date: 2026-05-13

import ProtocolModule

// MARK: - Local concrete Input (Copyable, simplest case)

struct LocalInput {
    var bytes: [UInt8]
}

// MARK: - V1: Construct a leaf Fail<LocalInput, Int, MyError>

enum MyError: Swift.Error {
    case failed
}

print("V1: Construct Parser.Fail<LocalInput, Int, MyError> cross-module...")
let leaf = Parser.Fail<LocalInput, Int, MyError>(.failed)
print("  V1 PASSED — leaf construction OK")

// MARK: - V2: Cross-module witness-table instantiation for the leaf

print("V2: Call Parser.Fail.parse(&input) — exercises Π conformance witness...")
var input = LocalInput(bytes: [0x41, 0x42])
do {
    let _ = try leaf.parse(&input)
    print("  V2 UNREACHABLE — Fail should throw")
} catch MyError.failed {
    print("  V2 PASSED — witness-table dispatch succeeded, error thrown as expected")
}

// MARK: - V3: Cross-module witness-table instantiation for the COMPOSED combinator
// This is the critical test — Map<Fail<...>>: Π wrapping Fail<...>: Π.

func runV3() {
    print("V3: Construct Parser.Map<Fail<LocalInput, Int, MyError>, String>...")
    let mapped = Parser.Map<Parser.Fail<LocalInput, Int, MyError>, String>(
        upstream: Parser.Fail<LocalInput, Int, MyError>(.failed),
        transform: { (i: Int) in "got \(i)" }
    )
    print("  V3a PASSED — composed wrapper construction OK")

    print("V3b: Call composed Map.parse(&input) — exercises Π conformance witness for composed type...")
    var input3 = LocalInput(bytes: [0x41, 0x42])
    do {
        let _ = try mapped.parse(&input3)
        print("  V3b UNREACHABLE — should throw")
    } catch {
        // Typed throws: error is statically MyError here.
        print("  V3b PASSED — composed witness-table dispatch succeeded (error: \(error))")
    }
}
runV3()

// MARK: - V4: Deeper composition — Map<Map<Fail<...>>>

func runV4() {
    print("V4: Triple-nested Map<Map<Fail<...>>>...")
    let inner = Parser.Map<Parser.Fail<LocalInput, Int, MyError>, String>(
        upstream: Parser.Fail<LocalInput, Int, MyError>(.failed),
        transform: { i in "inner-\(i)" }
    )
    let outer = Parser.Map<
        Parser.Map<Parser.Fail<LocalInput, Int, MyError>, String>,
        Int
    >(
        upstream: inner,
        transform: { (s: String) in s.count }
    )
    print("  V4a PASSED — triple-nested construction OK")

    print("V4b: Call triple-nested .parse(&input)...")
    var input4 = LocalInput(bytes: [0x41, 0x42])
    do {
        let _ = try outer.parse(&input4)
        print("  V4b UNREACHABLE — should throw")
    } catch {
        print("  V4b PASSED — triple-nested composition dispatch succeeded (error: \(error))")
    }
}
runV4()

// MARK: - V6: Closure capture — Parser.Lazy<P>: ~Copyable wraps `() -> P`

func runV6() {
    print("V6: Parser.Lazy<Fail<LocalInput, Int, MyError>> — closure returning ~Copyable...")
    let lazy = Parser.Lazy<Parser.Fail<LocalInput, Int, MyError>> {
        Parser.Fail<LocalInput, Int, MyError>(.failed)
    }
    print("  V6a PASSED — Lazy<~Copyable P> construction OK")

    print("V6b: Call Lazy.parse — exercises closure-return-~Copyable + nested Π witness dispatch...")
    var input6 = LocalInput(bytes: [0x50])
    do {
        let _ = try lazy.parse(&input6)
        print("  V6b UNREACHABLE — should throw")
    } catch {
        print("  V6b PASSED — closure-return-~Copyable dispatch succeeded (error: \(error))")
    }

    print("V6c: Compose Map<Lazy<Fail<...>>, String> — combinator wrapping a Lazy wrapping a leaf...")
    let mapped = Parser.Map<
        Parser.Lazy<Parser.Fail<LocalInput, Int, MyError>>,
        String
    >(
        upstream: Parser.Lazy<Parser.Fail<LocalInput, Int, MyError>> {
            Parser.Fail<LocalInput, Int, MyError>(.failed)
        },
        transform: { (i: Int) in "mapped-\(i)" }
    )
    var input6c = LocalInput(bytes: [0x51])
    do {
        let _ = try mapped.parse(&input6c)
        print("  V6c UNREACHABLE — should throw")
    } catch {
        print("  V6c PASSED — Map<Lazy<...>> composed dispatch succeeded (error: \(error))")
    }
}
runV6()

print("")
print("ALL TESTS COMPLETE — no SIGSEGV at cross-module witness-table instantiation")
print("  for Parser.\\`Protocol\\`: ~Copyable on Self under current toolchain.")
