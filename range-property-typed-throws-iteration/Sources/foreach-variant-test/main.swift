// Tests whether `var forEach: Property` on Range coexists with stdlib's
// inherited `func forEach(_:)` and which one wins overload resolution at
// typed-throws call sites.
//
// Result: PENDING

internal import ForEachVariant

enum MyError: Swift.Error, Equatable {
    case foo
    case bar(Int)
}

var failures: [String] = []

// P1: typed-throws call site compiles + runs
do {
    do throws(MyError) {
        var collected: [Int] = []
        try (0..<3).forEach { (i: Int) throws(MyError) in
            collected.append(i)
        }
        if collected == [0, 1, 2] {
            print("P1 PASS (collected = \(collected))")
        } else {
            print("P1 FAIL (collected = \(collected))")
            failures.append("P1")
        }
    } catch {
        print("P1 FAIL (unexpected throw)")
        failures.append("P1")
    }
}

// P2/P5: typed throw propagates with shape intact
do {
    do throws(MyError) {
        try (0..<5).forEach { (i: Int) throws(MyError) in
            if i == 3 { throw .bar(i) }
        }
        print("P2/P5 FAIL (expected throw never fired)")
        failures.append("P2/P5")
    } catch {
        let e: MyError = error  // only compiles if catch binds MyError, not any Error
        switch e {
        case .bar(let n) where n == 3:
            print("P2/P5 PASS (typed throw propagated as MyError.bar(3))")
        default:
            print("P2/P5 FAIL (wrong case: \(e))")
            failures.append("P2/P5")
        }
    }
}

// P3: typed catch binds MyError directly
do {
    do throws(MyError) {
        try (0..<2).forEach { (_: Int) throws(MyError) in
            throw .foo
        }
        print("P3 FAIL (expected throw)")
        failures.append("P3")
    } catch {
        let e: MyError = error
        if e == .foo {
            print("P3 PASS (caught .foo)")
        } else {
            print("P3 FAIL (caught \(e))")
            failures.append("P3")
        }
    }
}

// P4: non-throwing closure path — does this still work?
do {
    var stdlibCollected: [Int] = []
    (0..<3).forEach { stdlibCollected.append($0) }
    if stdlibCollected == [0, 1, 2] {
        print("P4 PASS (non-throwing forEach output = \(stdlibCollected))")
    } else {
        print("P4 FAIL (non-throwing forEach output = \(stdlibCollected))")
        failures.append("P4")
    }
}

// P6/P7: cross-Bound generic
do {
    do throws(MyError) {
        var ints32: [Int32] = []
        try (Int32(0)..<Int32(3)).forEach { (i: Int32) throws(MyError) in
            ints32.append(i)
        }
        if ints32 == [0, 1, 2] {
            print("P6/P7-Int32 PASS")
        } else {
            print("P6/P7-Int32 FAIL")
            failures.append("P6/P7-Int32")
        }
    } catch {
        print("P6/P7-Int32 FAIL (unexpected throw)")
        failures.append("P6/P7-Int32")
    }
}

if failures.isEmpty {
    print("=== ALL PASS — `forEach` can be the verb on Range too ===")
} else {
    print("=== FAILURES: \(failures.joined(separator: ", ")) ===")
}
