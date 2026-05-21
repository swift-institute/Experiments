// Performance pass: Property bridges vs stdlib equivalents.
//
// Compares per-iteration cost of:
//   A. stdlib non-throwing form (baseline; resolves to stdlib inherited method)
//   B. Property typed-throws form (the new bridge; closure never throws at runtime)
//   C. Manual while-loop (lower bound)
//
// Built with -c release.

internal import Property_Primitives

@inline(never)
func consume(_ x: Int) {
    blackHole = blackHole &+ x
}

nonisolated(unsafe) var blackHole: Int = 0

enum NeverThrown: Swift.Error { case unreachable }

let iterations = 10_000_000

func pad(_ s: String, _ n: Int) -> String {
    if s.count >= n { return s }
    return s + String(repeating: " ", count: n - s.count)
}

func bench(_ name: String, _ work: () -> Void) {
    for _ in 0..<3 { work() }
    let clock = ContinuousClock()
    let start = clock.now
    work()
    let elapsed = clock.now - start
    let nanos = Double(elapsed.components.attoseconds) / 1e9 + Double(elapsed.components.seconds) * 1e9
    let perIter = nanos / Double(iterations)
    // Two-decimal manual formatter (Foundation-free)
    let perIterCenti = Int((perIter * 100).rounded())
    let msCenti = Int((nanos / 1e6 * 10).rounded())
    print("\(pad(name, 50)) \(perIterCenti / 100).\(pad(String(perIterCenti % 100), 2)) ns/iter (total \(msCenti / 10).\(msCenti % 10) ms)")
}

print("--- forEach (10M iters) ---")

bench("A. stdlib forEach { non-throwing }") {
    (0..<iterations).forEach { i in consume(i) }
}

bench("B. Property forEach { throws(NeverThrown) }") {
    try? (0..<iterations).forEach { (i: Int) throws(NeverThrown) in consume(i) }
}

bench("C. manual while-loop") {
    var i = 0
    while i < iterations {
        consume(i)
        i = i &+ 1
    }
}

print("--- map (10M iters) ---")

bench("A. stdlib map { non-throwing }") {
    let r = (0..<iterations).map { $0 &* 2 }
    consume(r.count)
}

bench("B. Property map { throws(NeverThrown) }") {
    let r = try? (0..<iterations).map { (i: Int) throws(NeverThrown) -> Int in i &* 2 }
    consume(r?.count ?? 0)
}

bench("C. manual array build") {
    var r: [Int] = []
    r.reserveCapacity(iterations)
    var i = 0
    while i < iterations {
        r.append(i &* 2)
        i = i &+ 1
    }
    consume(r.count)
}

print("--- filter (10M iters) ---")

bench("A. stdlib filter { non-throwing }") {
    let r = (0..<iterations).filter { $0.isMultiple(of: 2) }
    consume(r.count)
}

bench("B. Property filter { throws(NeverThrown) }") {
    let r = try? (0..<iterations).filter { (i: Int) throws(NeverThrown) in i.isMultiple(of: 2) }
    consume(r?.count ?? 0)
}

print("--- reduce (10M iters) ---")

bench("A. stdlib reduce(0, &+)") {
    let r = (0..<iterations).reduce(0, &+)
    consume(r)
}

bench("B. Property reduce(0) { throws(NeverThrown) }") {
    let r = try? (0..<iterations).reduce(0) { (acc: Int, i: Int) throws(NeverThrown) in acc &+ i }
    consume(r ?? 0)
}

print("\nblackHole = \(blackHole)")
