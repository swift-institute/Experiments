// Tests whether Property-accessor `var map: Property<...>` on Range
// coexists with stdlib's inherited `func map<T>(_:) rethrows -> [T]`,
// AND whether typed-throws disambiguation works when both return [T].
//
// Result: PENDING

internal import MapVariant

enum MyError: Swift.Error, Equatable {
    case bad(Int)
}

var failures: [String] = []

// M1: non-throwing map — should still produce [T] via either path
do {
    let result = (0..<3).map { $0 * 2 }
    if result == [0, 2, 4] {
        print("M1 PASS (non-throwing map = \(result))")
    } else {
        print("M1 FAIL (got \(result))")
        failures.append("M1")
    }
}

// M2: typed-throws map — must resolve to Property path
do {
    do throws(MyError) {
        let result = try (0..<3).map { (i: Int) throws(MyError) -> String in
            return "v\(i)"
        }
        if result == ["v0", "v1", "v2"] {
            print("M2 PASS (typed-throws map = \(result))")
        } else {
            print("M2 FAIL (got \(result))")
            failures.append("M2")
        }
    } catch {
        print("M2 FAIL (unexpected throw)")
        failures.append("M2")
    }
}

// M3: typed-throws map with propagated error — must preserve MyError, not erase
do {
    do throws(MyError) {
        let _: [Int] = try (0..<5).map { (i: Int) throws(MyError) -> Int in
            if i == 2 { throw .bad(i) }
            return i * 10
        }
        print("M3 FAIL (expected throw never fired)")
        failures.append("M3")
    } catch {
        let e: MyError = error  // only compiles if catch binds MyError
        if e == .bad(2) {
            print("M3 PASS (typed throw .bad(2) propagated)")
        } else {
            print("M3 FAIL (wrong case: \(e))")
            failures.append("M3")
        }
    }
}

// M4: cross-Bound generic
do {
    let result: [Int32] = (Int32(0)..<Int32(3)).map { $0 * 2 }
    if result == [0, 2, 4] {
        print("M4 PASS (Int32 map = \(result))")
    } else {
        print("M4 FAIL (got \(result))")
        failures.append("M4")
    }
}

if failures.isEmpty {
    print("=== ALL PASS — `map` Property bridge works for value-returning verb ===")
} else {
    print("=== FAILURES: \(failures.joined(separator: ", ")) ===")
}
