// Does Swift 6.3.1's stdlib already preserve typed throws on
// Optional.map / Optional.flatMap / Result.map / Result.mapError?
//
// If yes → no Property bridge needed; skip those in property-primitives
//          integration.
// If no  → add Property bridges.
//
// Result: PENDING

enum E: Swift.Error, Equatable { case foo, bar }

var failures: [String] = []

// Optional.map
do {
    let some: Int? = 3
    do throws(E) {
        let mapped: String? = try some.map { (x: Int) throws(E) -> String in
            if x == 3 { throw .foo }
            return "v\(x)"
        }
        print("Optional.map(typed-throws): FAIL — expected throw, got \(mapped ?? "nil")")
        failures.append("Optional.map-expected-throw")
    } catch {
        let e: E = error  // only compiles if catch binds E (not any Error)
        if e == .foo {
            print("Optional.map(typed-throws): STDLIB SUPPORTS — typed throw .foo propagated")
        } else {
            print("Optional.map(typed-throws): FAIL — wrong case: \(e)")
            failures.append("Optional.map-wrong-case")
        }
    }
}

// Optional.flatMap
do {
    let some: Int? = 3
    do throws(E) {
        let mapped: String? = try some.flatMap { (x: Int) throws(E) -> String? in
            if x == 3 { throw .bar }
            return "v\(x)"
        }
        print("Optional.flatMap(typed-throws): FAIL — expected throw, got \(mapped ?? "nil")")
        failures.append("Optional.flatMap-expected-throw")
    } catch {
        let e: E = error
        if e == .bar {
            print("Optional.flatMap(typed-throws): STDLIB SUPPORTS — typed throw .bar propagated")
        } else {
            print("Optional.flatMap(typed-throws): FAIL — wrong case: \(e)")
            failures.append("Optional.flatMap-wrong-case")
        }
    }
}

// Result.map — Result already carries typed Failure, so .map is non-throwing
// stdlib-side. The interesting question is whether the transform can be
// typed-throws and how the Failure recomposes.
do {
    let r: Result<Int, E> = .success(3)
    // Stdlib Result.map signature: map<NewSuccess>((Success) -> NewSuccess) -> Result<NewSuccess, Failure>
    // It does NOT take a throwing transform. So typed throws on transform
    // would not match stdlib's signature. We need a Property bridge if
    // we want typed-throws transforms that fold into the Result.
    let mapped: Result<String, E> = r.map { x in "v\(x)" }
    if case .success("v3") = mapped {
        print("Result.map(non-throwing): STDLIB WORKS — \(mapped)")
    } else {
        print("Result.map(non-throwing): FAIL — \(mapped)")
        failures.append("Result.map")
    }
}

// What we'd add as a bridge: Result.map with throws(E2) transform that
// either composes with original Failure (Either) or replaces it. That's
// the deeper design question. For now, skip and note that stdlib's
// non-throwing Result.map works.

if failures.isEmpty {
    print("=== PROBE COMPLETE: see lines above for STDLIB SUPPORTS / NEEDS BRIDGE verdict per method ===")
} else {
    print("=== UNEXPECTED FAILURES: \(failures.joined(separator: ", ")) ===")
}
