// Smoke test for the full Range bridge batch shipped in
// swift-property-primitives' Property Primitives Standard Library
// Integration target.
//
// Result: PENDING

internal import Property_Primitives

enum E: Swift.Error, Equatable { case oops(Int) }

var failures: [String] = []

// filter
do {
    let evens: [Int] = (0..<10).filter { $0.isMultiple(of: 2) }
    if evens == [0, 2, 4, 6, 8] {
        print("filter(non-throwing) PASS = \(evens)")
    } else {
        print("filter(non-throwing) FAIL = \(evens)")
        failures.append("filter")
    }
}
do {
    do throws(E) {
        let _: [Int] = try (0..<5).filter { (i: Int) throws(E) in
            if i == 3 { throw .oops(i) }
            return i.isMultiple(of: 2)
        }
        print("filter(typed-throws) FAIL — expected throw")
        failures.append("filter-typed")
    } catch {
        let err: E = error
        if err == .oops(3) {
            print("filter(typed-throws) PASS — propagated .oops(3)")
        } else {
            print("filter(typed-throws) FAIL — got \(err)")
            failures.append("filter-typed")
        }
    }
}

// reduce
do {
    let sum: Int = (0..<5).reduce(0, +)
    if sum == 10 {
        print("reduce(non-throwing) PASS = \(sum)")
    } else {
        print("reduce(non-throwing) FAIL = \(sum)")
        failures.append("reduce")
    }
}
do {
    do throws(E) {
        let _: Int = try (0..<5).reduce(0) { (acc: Int, i: Int) throws(E) in
            if i == 2 { throw .oops(i) }
            return acc + i
        }
        print("reduce(typed-throws) FAIL — expected throw")
        failures.append("reduce-typed")
    } catch {
        let err: E = error
        if err == .oops(2) {
            print("reduce(typed-throws) PASS — propagated .oops(2)")
        } else {
            print("reduce(typed-throws) FAIL — got \(err)")
            failures.append("reduce-typed")
        }
    }
}

// allSatisfy
do {
    let all: Bool = (0..<5).allSatisfy { $0 >= 0 }
    if all {
        print("allSatisfy(non-throwing) PASS = \(all)")
    } else {
        print("allSatisfy(non-throwing) FAIL")
        failures.append("allSatisfy")
    }
}
do {
    do throws(E) {
        let _: Bool = try (0..<5).allSatisfy { (i: Int) throws(E) in
            if i == 4 { throw .oops(i) }
            return i < 10
        }
        print("allSatisfy(typed-throws) FAIL — expected throw")
        failures.append("allSatisfy-typed")
    } catch {
        let err: E = error
        if err == .oops(4) {
            print("allSatisfy(typed-throws) PASS — propagated .oops(4)")
        } else {
            print("allSatisfy(typed-throws) FAIL — got \(err)")
            failures.append("allSatisfy-typed")
        }
    }
}

// contains(where:)
do {
    let yes: Bool = (0..<5).contains { $0 == 3 }
    if yes {
        print("contains(non-throwing) PASS = true")
    } else {
        print("contains(non-throwing) FAIL")
        failures.append("contains")
    }
}
do {
    do throws(E) {
        let _: Bool = try (0..<5).contains { (i: Int) throws(E) in
            if i == 2 { throw .oops(i) }
            return false
        }
        print("contains(typed-throws) FAIL — expected throw")
        failures.append("contains-typed")
    } catch {
        let err: E = error
        if err == .oops(2) {
            print("contains(typed-throws) PASS — propagated .oops(2)")
        } else {
            print("contains(typed-throws) FAIL — got \(err)")
            failures.append("contains-typed")
        }
    }
}

// first(where:)
do {
    let found: Int? = (0..<5).first { $0 > 2 }
    if found == 3 {
        print("first(non-throwing) PASS = \(found!)")
    } else {
        print("first(non-throwing) FAIL = \(String(describing: found))")
        failures.append("first")
    }
}
do {
    do throws(E) {
        let _: Int? = try (0..<5).first { (i: Int) throws(E) in
            if i == 1 { throw .oops(i) }
            return false
        }
        print("first(typed-throws) FAIL — expected throw")
        failures.append("first-typed")
    } catch {
        let err: E = error
        if err == .oops(1) {
            print("first(typed-throws) PASS — propagated .oops(1)")
        } else {
            print("first(typed-throws) FAIL — got \(err)")
            failures.append("first-typed")
        }
    }
}

// compactMap
do {
    let parsed: [Int] = (0..<5).compactMap { $0.isMultiple(of: 2) ? $0 * 10 : nil }
    if parsed == [0, 20, 40] {
        print("compactMap(non-throwing) PASS = \(parsed)")
    } else {
        print("compactMap(non-throwing) FAIL = \(parsed)")
        failures.append("compactMap")
    }
}
do {
    do throws(E) {
        let _: [Int] = try (0..<5).compactMap { (i: Int) throws(E) -> Int? in
            if i == 3 { throw .oops(i) }
            return i.isMultiple(of: 2) ? i : nil
        }
        print("compactMap(typed-throws) FAIL — expected throw")
        failures.append("compactMap-typed")
    } catch {
        let err: E = error
        if err == .oops(3) {
            print("compactMap(typed-throws) PASS — propagated .oops(3)")
        } else {
            print("compactMap(typed-throws) FAIL — got \(err)")
            failures.append("compactMap-typed")
        }
    }
}

if failures.isEmpty {
    print("=== ALL Range bridges work — non-throwing AND typed-throws paths ===")
} else {
    print("=== FAILURES: \(failures.joined(separator: ", ")) ===")
}
