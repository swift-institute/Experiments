// Parse-performance bench for swift-json.
//
// Standing measurement + verification harness used by the Tier-0/1/3/4
// parse-performance research. See Package.swift for mode docs and the
// research arc at swift-foundations/swift-json/Research/parse-performance.md.
//
// Foundation import: this experiment is the Foundation-vs-swift-json
// comparison harness; production swift-json Sources/ remains
// Foundation-free.

import Foundation
import JSON
import Dictionary_Ordered_Primitives
import Hash_Primitives
import ASCII_Decimal_Parser_Primitives
import Lexer_Primitives
import ASCII_Primitives

// MARK: - Schema for codable-lookup mode
//
// Minimal Symbol Graph schema covering the fields the canonical
// workload's traversal pattern actually touches:
//   symbols[].kind.identifier   — String
//   symbols[].identifier.precise — String
//   symbols[].pathComponents     — [String]
//
// Defined at file scope so both Foundation Decodable and swift-json
// JSON.Serializable can extend it.

struct SymbolKind: Decodable, JSON.Serializable {
    let identifier: String

    static func deserialize(_ json: JSON) throws(JSON.Error) -> SymbolKind {
        return SymbolKind(identifier: String(json.identifier))
    }

    static func serialize(_ value: SymbolKind) -> JSON {
        ["identifier": .string(value.identifier)]
    }

    static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> SymbolKind {
        try events.expectObjectStart()
        var identifier: String? = nil
        while let token = try events.next() {
            if token == .objectEnd { break }
            if token == .comma { continue }
            guard token == .string else {
                throw .invalidSyntax(message: "expected object key", location: events.position().location)
            }
            let key = try events.currentString()
            try events.expectColon()
            switch key {
            case "identifier":
                identifier = try String.deserialize(events: &events)
            default:
                try events.skipValue()
            }
        }
        guard let identifier = identifier else {
            throw .missingKey("identifier")
        }
        return SymbolKind(identifier: identifier)
    }
}

struct SymbolIdentifier: Decodable, JSON.Serializable {
    let precise: String

    static func deserialize(_ json: JSON) throws(JSON.Error) -> SymbolIdentifier {
        return SymbolIdentifier(precise: String(json.precise))
    }

    static func serialize(_ value: SymbolIdentifier) -> JSON {
        ["precise": .string(value.precise)]
    }

    static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> SymbolIdentifier {
        try events.expectObjectStart()
        var precise: String? = nil
        while let token = try events.next() {
            if token == .objectEnd { break }
            if token == .comma { continue }
            guard token == .string else {
                throw .invalidSyntax(message: "expected object key", location: events.position().location)
            }
            let key = try events.currentString()
            try events.expectColon()
            switch key {
            case "precise":
                precise = try String.deserialize(events: &events)
            default:
                try events.skipValue()
            }
        }
        guard let precise = precise else {
            throw .missingKey("precise")
        }
        return SymbolIdentifier(precise: precise)
    }
}

struct Symbol: Decodable, JSON.Serializable {
    let kind: SymbolKind
    let identifier: SymbolIdentifier
    let pathComponents: [String]

    static func deserialize(_ json: JSON) throws(JSON.Error) -> Symbol {
        let kind = try SymbolKind(json: json.kind)
        let identifier = try SymbolIdentifier(json: json.identifier)
        let pathComponents = try [String](json: json.pathComponents)
        return Symbol(kind: kind, identifier: identifier, pathComponents: pathComponents)
    }

    static func serialize(_ value: Symbol) -> JSON {
        [
            "kind": SymbolKind.serialize(value.kind),
            "identifier": SymbolIdentifier.serialize(value.identifier),
            "pathComponents": .array(value.pathComponents.map { .string($0) })
        ]
    }

    /// Opt-in event-grain deserialize. The wedge: only 3 of ~9 keys
    /// per symbol are declared; the rest go through skipValue() which
    /// walks bytes without materialising values. This is the §4.6
    /// end-to-end example translated to the Symbol schema.
    static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> Symbol {
        try events.expectObjectStart()
        var kind: SymbolKind? = nil
        var identifier: SymbolIdentifier? = nil
        var pathComponents: [String]? = nil
        while let token = try events.next() {
            if token == .objectEnd { break }
            if token == .comma { continue }
            guard token == .string else {
                throw .invalidSyntax(message: "expected object key", location: events.position().location)
            }
            let key = try events.currentString()
            try events.expectColon()
            switch key {
            case "kind":
                kind = try SymbolKind.deserialize(events: &events)
            case "identifier":
                identifier = try SymbolIdentifier.deserialize(events: &events)
            case "pathComponents":
                pathComponents = try [String].deserialize(events: &events)
            default:
                try events.skipValue() // ← the wedge
            }
        }
        guard let kind = kind, let identifier = identifier,
              let pathComponents = pathComponents else {
            throw .missingKey("kind/identifier/pathComponents")
        }
        return Symbol(kind: kind, identifier: identifier, pathComponents: pathComponents)
    }
}

struct SymbolGraph: Decodable, JSON.Serializable {
    let symbols: [Symbol]

    static func deserialize(_ json: JSON) throws(JSON.Error) -> SymbolGraph {
        let symbols = try [Symbol](json: json.symbols)
        return SymbolGraph(symbols: symbols)
    }

    static func serialize(_ value: SymbolGraph) -> JSON {
        ["symbols": .array(value.symbols.map { Symbol.serialize($0) })]
    }

    static func deserialize(events: inout JSON.Span.EventStream) throws(JSON.Error) -> SymbolGraph {
        try events.expectObjectStart()
        var symbols: [Symbol]? = nil
        while let token = try events.next() {
            if token == .objectEnd { break }
            if token == .comma { continue }
            guard token == .string else {
                throw .invalidSyntax(message: "expected object key", location: events.position().location)
            }
            let key = try events.currentString()
            try events.expectColon()
            switch key {
            case "symbols":
                symbols = try [Symbol].deserialize(events: &events)
            default:
                try events.skipValue()
            }
        }
        guard let symbols = symbols else {
            throw .missingKey("symbols")
        }
        return SymbolGraph(symbols: symbols)
    }
}

func mono() -> Double {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1e9
}

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}

func report(_ label: String, _ seconds: Double) {
    print("\(pad(label, 50)) \(String(format: "%8.3f", seconds))s")
}

// MARK: - Stats helpers (stats + float-microbench modes)

struct Stats {
    let min: Double
    let median: Double
    let p90: Double
    let mean: Double
}

func computeStats(_ samples: [Double]) -> Stats {
    precondition(!samples.isEmpty, "computeStats requires at least one sample")
    let sorted = samples.sorted()
    let n = sorted.count
    let minVal = sorted[0]
    let median = n % 2 == 0
        ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
        : sorted[n / 2]
    let p90Idx = Swift.min(Int((Double(n) * 0.9).rounded(.down)), n - 1)
    let p90 = sorted[p90Idx]
    let mean = samples.reduce(0.0, +) / Double(n)
    return Stats(min: minVal, median: median, p90: p90, mean: mean)
}

/// Apple's NewCodable methodology: small warmup excludes cold-cache + JIT-ish
/// effects; MIN-of-N is the canonical low-noise summary. Default warmup
/// scales with N but is clamped to [8, 32].
func warmupCount(for iters: Int) -> Int {
    return Swift.max(8, Swift.min(32, iters / 16))
}

func reportStat(_ label: String, _ stats: Stats, unit: String, fmt: String = "%10.3f") {
    print("    \(pad("min", 10)) \(String(format: fmt, stats.min)) \(unit)")
    print("    \(pad("median", 10)) \(String(format: fmt, stats.median)) \(unit)")
    print("    \(pad("p90", 10)) \(String(format: fmt, stats.p90)) \(unit)")
    print("    \(pad("mean", 10)) \(String(format: fmt, stats.mean)) \(unit)")
    _ = label
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: \(args[0]) <path> [iters] [mode]\n".utf8))
    exit(2)
}
let path = args[1]
let iters = args.count >= 3 ? (Int(args[2]) ?? 1) : 1
let mode = args.count >= 4 ? args[3] : "all"

guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
    print("could not read \(path)")
    exit(1)
}
let mb = Double(data.count) / 1048576.0
print("input size: \(data.count) bytes (\(String(format: "%.2f", mb)) MB)")
print("iterations: \(iters), mode: \(mode)")
print("")

let stringForm: String = String(decoding: data, as: UTF8.self)
let bytesForm: [Byte] = data.map(Byte.init)
print("prepared String + [UInt8] forms")
print("")

// FLOOR: byte iteration
if mode == "all" || mode == "floor" {
    do {
        let t0 = mono()
        for _ in 0..<iters {
            var sum: UInt64 = 0
            for b in data { sum = sum &+ UInt64(b) }
            if sum == 0 { print("(DCE)") }
        }
        report("[FLOOR]   byte-iterate Data", mono() - t0)
    }
    do {
        let t0 = mono()
        for _ in 0..<iters {
            var sum: UInt64 = 0
            for b in bytesForm { sum = sum &+ UInt64(b) }
            if sum == 0 { print("(DCE)") }
        }
        report("[FLOOR]   byte-iterate [UInt8]", mono() - t0)
    }
}

// Foundation: JSONSerialization
if mode == "all" || mode == "foundation" {
    let t0 = mono()
    for _ in 0..<iters {
        _ = try JSONSerialization.jsonObject(with: data, options: [])
    }
    report("Foundation.JSONSerialization.jsonObject(with:)", mono() - t0)
}

// swift-json: String path
if mode == "all" || mode == "swift-json-string" {
    let t0 = mono()
    for _ in 0..<iters {
        _ = try JSON.parse(stringForm)
    }
    report("swift-json JSON.parse(String)", mono() - t0)
}

// swift-json: bytes path
if mode == "all" || mode == "swift-json-bytes" {
    let t0 = mono()
    for _ in 0..<iters {
        _ = try JSON.parse(bytesForm)
    }
    report("swift-json JSON.parse([UInt8])", mono() - t0)
}

// CROSSOVER mode: storage micro-bench. For each object size N in
// {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024} build a representative
// (key, value) container in three storage shapes and measure raw
// lookup throughput. Pre-randomised lookup keys; tight loop; minimal
// overhead. Answers: at what N does Dictionary.Ordered beat the
// current [(String, Value)] linear scan? At what N does it beat
// Swift.Dictionary?
if mode == "crossover" {
    print("=== CROSSOVER: storage micro-bench by object size ===")
    print("Per-row: ns/lookup at object-size N, over 10 000 lookups against random hit keys.")
    print("")
    let sizes = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
    let nLookups = 10_000
    print(pad("size", 6), pad("array(curr)", 14), pad("Swift.Dict", 14), pad("Dict.Ordered", 14), pad("array/Ordered", 14))
    for size in sizes {
        // Pre-generate keys; "k_NNN" pattern roughly matches real-world short keys.
        let keys = (0..<size).map { "k_\($0)" }
        let values = (0..<size).map { $0 }
        let array: [(String, Int)] = zip(keys, values).map { ($0.0, $0.1) }
        let swiftDict: Swift.Dictionary<String, Int> = Swift.Dictionary(uniqueKeysWithValues: zip(keys, values).map { ($0, $1) })
        var orderedDict = Dictionary<String, Int>.Ordered()
        for (k, v) in zip(keys, values) { orderedDict.set(k, v) }

        // Pre-generate lookup keys (always hits).
        var rng = SystemRandomNumberGenerator()
        let lookupKeys: [String] = (0..<nLookups).map { _ in keys[Int.random(in: 0..<size, using: &rng)] }

        // Bench: array linear scan
        let t0 = mono()
        var sinkA = 0
        for k in lookupKeys {
            if let v = array.first(where: { $0.0 == k })?.1 { sinkA &+= v }
        }
        let tA = mono() - t0
        if sinkA == 0 { print("(DCE A)") }

        // Bench: Swift.Dictionary
        let t1 = mono()
        var sinkS = 0
        for k in lookupKeys {
            if let v = swiftDict[k] { sinkS &+= v }
        }
        let tS = mono() - t1
        if sinkS == 0 { print("(DCE S)") }

        // Bench: Dictionary.Ordered
        let t2 = mono()
        var sinkO = 0
        for k in lookupKeys {
            if let v = orderedDict[k] { sinkO &+= v }
        }
        let tO = mono() - t2
        if sinkO == 0 { print("(DCE O)") }

        // ns/lookup
        let nsA = Int(tA * 1e9 / Double(nLookups))
        let nsS = Int(tS * 1e9 / Double(nLookups))
        let nsO = Int(tO * 1e9 / Double(nLookups))
        let ratio = String(format: "%.2f×", tA / tO)
        print(pad("\(size)", 6), pad("\(nsA) ns", 14), pad("\(nsS) ns", 14), pad("\(nsO) ns", 14), pad(ratio, 14))
    }
    print("")
    print("Reading: where Dict.Ordered < array(curr), the storage change wins on that size.")
    print("Where array/Ordered > 1, the linear scan is faster than Dict.Ordered.")
}

// SYNTHETIC-LOOKUP mode: build a JSON document of `iters` objects each
// with N keys, parse with both parsers, time the lookup pass. Mirrors
// the canonical workload but lets us scale N to find the end-to-end
// crossover including the Any-cast cost in Foundation's path.
if mode == "synthetic-lookup" {
    print("=== SYNTHETIC-LOOKUP: end-to-end at varying object size ===")
    print("Per-row: lookup ms (parse excluded) for swift-json vs Foundation at object-size N, summed over 5000 objects.")
    print("")
    let sizes = [1, 4, 8, 16, 32, 64, 128, 256]
    let nObjects = 5_000
    print(pad("size", 6), pad("swift-json", 12), pad("Foundation", 12), pad("Fnd/swift-json", 16))
    for size in sizes {
        // Build a JSON string: an array of N-key objects.
        // Each object: {"k_0":0, "k_1":1, ..., "k_{N-1}":N-1}
        var doc = "["
        for i in 0..<nObjects {
            if i > 0 { doc.append(",") }
            doc.append("{")
            for j in 0..<size {
                if j > 0 { doc.append(",") }
                doc.append("\"k_\(j)\":\(j)")
            }
            doc.append("}")
        }
        doc.append("]")
        let docData = Data(doc.utf8)

        let sjRoot = try JSON.parse(doc)
        let fnRoot = try JSONSerialization.jsonObject(with: docData, options: []) as! [Any]

        guard let sjArr = sjRoot.array else { print("sj array missing"); continue }

        // Lookup: read `k_0` from every object (single hop).
        // Single lookup per object isolates the lookup cost from
        // multi-hop chain noise.
        let lookupKey = "k_0"

        let t0 = mono()
        var sinkSJ: Int = 0
        for o in sjArr {
            if let i = Int(o[lookupKey]) {
                sinkSJ &+= i
            }
        }
        let tSJ = mono() - t0
        if sinkSJ == 0 { print("(DCE SJ)") }

        let t1 = mono()
        var sinkFN: Int = 0
        for o in fnRoot {
            if let dict = o as? [String: Any], let i = dict[lookupKey] as? Int {
                sinkFN &+= i
            }
        }
        let tFN = mono() - t1
        if sinkFN == 0 { print("(DCE FN)") }

        let msSJ = String(format: "%.3f ms", tSJ * 1000)
        let msFN = String(format: "%.3f ms", tFN * 1000)
        let ratio = String(format: "%.2f×", tFN / tSJ)
        print(pad("\(size)", 6), pad(msSJ, 12), pad(msFN, 12), pad(ratio, 16))
    }
}

// SIZE-DIST mode: walk the parsed swift-json tree once and build a
// histogram of object sizes. Answers: what's the actual distribution
// of keys-per-object in this real-world workload?
if mode == "size-dist" {
    print("=== SIZE-DIST: object-size histogram for the input ===")
    let root = try JSON.parse(stringForm)
    var sizeHistogram: [Int: Int] = [:]
    var totalObjects: Int = 0
    var totalKeys: Int = 0
    var maxSize: Int = 0

    func walk(_ json: JSON) {
        if let obj = json.object {
            let n = obj.count
            sizeHistogram[n, default: 0] &+= 1
            totalObjects &+= 1
            totalKeys &+= n
            if n > maxSize { maxSize = n }
            for (_, v) in obj { walk(v) }
        } else if let arr = json.array {
            for v in arr { walk(v) }
        }
    }
    walk(root)

    let mean = Double(totalKeys) / Double(totalObjects)
    print("Total objects: \(totalObjects)")
    print("Total keys:    \(totalKeys)")
    print("Mean keys/object: \(String(format: "%.2f", mean))")
    print("Max keys/object:  \(maxSize)")
    print("")
    print(pad("size", 6), pad("count", 10), pad("% of total", 12), "histogram")
    let sortedSizes = sizeHistogram.keys.sorted()
    for s in sortedSizes {
        let count = sizeHistogram[s]!
        let pct = 100.0 * Double(count) / Double(totalObjects)
        let bar = String(repeating: "#", count: min(Int(pct / 2.0), 50))
        print(pad("\(s)", 6), pad("\(count)", 10), pad(String(format: "%.2f%%", pct), 12), bar)
    }
}

// LOOKUP mode: measures the lookup-heavy traversal pattern that the
// symbol-graph oracle uses. Parses the file ONCE per parser, then runs
// the access pattern `iters` times. Wall-clock excludes parse; lookup
// throughput is what's reported.
//
// The access pattern mirrors `symbol-graph-conformance-oracle`:
//   for each symbol in root.symbols:
//     - read .kind.identifier
//     - read .identifier.precise
//     - read .pathComponents (array length only — counts the inner reads)
//
// Establishes the pre-L1-1 baseline for v2 architecture's measurement
// gate. Re-run after the storage change in L1-1 to verify the gap
// closed.
if mode == "lookup" {
    print("=== LOOKUP: parse once, traverse N times ===")
    print("(Parse times excluded from lookup measurement; tree built once per parser.)")
    print("")

    // Parse once with each. Time the parses themselves separately for
    // context, but the LOOKUP measurement is just the traversal loop.
    let pT0 = mono()
    let sjRoot = try JSON.parse(stringForm)
    let pT1 = mono()
    let fnRoot = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    let pT2 = mono()
    report("(once)  swift-json parse", pT1 - pT0)
    report("(once)  Foundation parse", pT2 - pT1)
    print("")

    // Pre-cache the symbols arrays so we don't repeat the top-level lookup.
    guard let sjSymbols = sjRoot.symbols.array,
          let fnSymbols = fnRoot["symbols"] as? [Any] else {
        print("symbols array missing")
        exit(1)
    }
    let symbolCount = sjSymbols.count
    guard symbolCount == fnSymbols.count else {
        print("symbol counts diverge: swift-json=\(symbolCount) Foundation=\(fnSymbols.count)")
        exit(1)
    }
    print("symbol count: \(symbolCount)")
    print("")

    // swift-json traversal
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in sjSymbols {
                if sym.kind.identifier.isString { sink &+= 1 }
                if sym.identifier.precise.isString { sink &+= 1 }
                if let pc = sym.pathComponents.array { sink &+= pc.count }
            }
        }
        if sink == 0 { print("(DCE)") }
        report("swift-json lookup pass (×\(iters))", mono() - t0)
    }

    // Foundation traversal — same shape, Any-cast at each hop
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in fnSymbols {
                guard let symDict = sym as? [String: Any] else { continue }
                if let kind = symDict["kind"] as? [String: Any],
                   kind["identifier"] is String { sink &+= 1 }
                if let ident = symDict["identifier"] as? [String: Any],
                   ident["precise"] is String { sink &+= 1 }
                if let pc = symDict["pathComponents"] as? [Any] { sink &+= pc.count }
            }
        }
        if sink == 0 { print("(DCE)") }
        report("Foundation lookup pass (×\(iters))", mono() - t0)
    }

    print("")
    print("Equivalent reads per iteration: 3 × \(symbolCount) = \(3 * symbolCount)")
    print("Total reads over \(iters) iters: \(3 * symbolCount * iters)")
}

// CODABLE-LOOKUP mode: schema-known typed-decode comparison.
//
// The standard `lookup` mode compares JSONSerialization (untyped Any
// + per-hop casts) against swift-json's typed dynamic-member-lookup.
// This mode runs the schema-known counterpart: Foundation's
// JSONDecoder + Codable struct vs swift-json's JSON.Serializable
// extension. Both produce a native Swift struct after parse+decode;
// post-decode lookup is native struct member access on both sides
// (no casts, no dynamic dispatch).
//
// Three measurements per parser:
//   1. Full parse + decode (single shot from bytes/string to struct)
//   2. Lookup pass over the decoded struct (native access)
//   3. Combined wall-clock for parse-once-then-lookup-N-times
//
// Expected: lookup is ≈ equal because both sides do native struct
// access. Parse+decode may differ — Foundation's JSONDecoder is
// selective (parses only fields the Decodable declares); swift-json
// parses the full tree first via JSON.parse(...) then extracts.
if mode == "codable-lookup" {
    print("=== CODABLE-LOOKUP: schema-known typed-decode comparison ===")
    print("Symbol schema: kind.identifier + identifier.precise + pathComponents")
    print("Foundation:  JSONDecoder().decode(SymbolGraph.self, from: data)")
    print("swift-json:  SymbolGraph(jsonBytes: bytesForm)")
    print("")

    // Time parse+decode for each parser (single iteration).
    let p0 = mono()
    let fnGraph = try JSONDecoder().decode(SymbolGraph.self, from: data)
    let p1 = mono()
    let sjGraph = try SymbolGraph(jsonBytes: bytesForm)
    let p2 = mono()
    report("(once)  Foundation parse+decode", p1 - p0)
    report("(once)  swift-json parse+decode", p2 - p1)
    print("")

    // Validate equivalent results
    let fnCount = fnGraph.symbols.count
    let sjCount = sjGraph.symbols.count
    guard fnCount == sjCount else {
        print("symbol counts diverge: fn=\(fnCount) sj=\(sjCount)")
        exit(1)
    }
    print("symbol count: \(fnCount) (match: \(fnCount == sjCount))")
    print("")

    // Foundation lookup pass — native struct access
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in fnGraph.symbols {
                sink &+= sym.kind.identifier.count
                sink &+= sym.identifier.precise.count
                sink &+= sym.pathComponents.count
            }
        }
        if sink == 0 { print("(DCE FN)") }
        report("Foundation lookup pass (×\(iters))", mono() - t0)
    }

    // swift-json lookup pass — native struct access (same shape)
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in sjGraph.symbols {
                sink &+= sym.kind.identifier.count
                sink &+= sym.identifier.precise.count
                sink &+= sym.pathComponents.count
            }
        }
        if sink == 0 { print("(DCE SJ)") }
        report("swift-json lookup pass (×\(iters))", mono() - t0)
    }

    print("")
    print("Equivalent reads per iteration: 3 × \(fnCount) = \(3 * fnCount)")
    print("Total reads over \(iters) iters: \(3 * fnCount * iters)")
}

// CODABLE-LOOKUP-EVENT-GRAIN mode (Phase A1 of streaming-deserialize).
//
// Three measurements:
//   1. Foundation parse+decode (control)
//   2. swift-json status-quo SymbolGraph(jsonBytes:) (control)
//   3. swift-json event-grain SymbolGraph.from(eventDecodingJsonBytes:)
//      with opt-in deserialize(events:) — the wedge
//
// Plus the §4.3 default-fallback non-regression axis: a non-opt-in
// String.from(eventDecodingJsonBytes:) on a small JSON-encoded string
// should match status-quo init(jsonBytes:) performance within noise.
// Existing String, Int, Array, Dictionary conformers DO override
// deserialize(events:); to exercise the default-fallback path we
// build a small bespoke conformer DefaultFallbackProbe that
// inherits the default.
//
// Expected (per streaming-json-deserialize-comparative-analysis.md
// v1.0.1 §9.3 binding A2 gate):
//   - axis (a): opt-in SymbolGraph closes most of the 37% gap to
//     Foundation: target ≤1.10× Foundation parse+decode.
//   - axis (b): non-opt-in default-fallback path within ±5% of the
//     existing codable-lookup mode's swift-json baseline.
struct DefaultFallbackProbe: JSON.Serializable {
    let name: String
    let age: Int

    static func serialize(_ value: DefaultFallbackProbe) -> JSON {
        ["name": .string(value.name), "age": .number(value.age)]
    }

    static func deserialize(_ json: JSON) throws(JSON.Error) -> DefaultFallbackProbe {
        let name = String(json.name)
        guard !name.isEmpty else { throw .missingKey("name") }
        guard let age = Int(json.age) else { throw .missingKey("age") }
        return DefaultFallbackProbe(name: name, age: age)
    }
    // Deliberately does NOT override deserialize(events:) — exercises
    // the §4.3 default-fallback path with the short-circuit.
}

if mode == "codable-lookup-event-grain" {
    print("=== CODABLE-LOOKUP-EVENT-GRAIN: opt-in fast path ===")
    print("Symbol schema: kind.identifier + identifier.precise + pathComponents")
    print("Foundation:  JSONDecoder().decode(SymbolGraph.self, from: data)")
    print("swift-json status-quo:  SymbolGraph(jsonBytes: bytesForm)")
    print("swift-json event-grain: SymbolGraph.from(eventDecodingJsonBytes: bytesForm)")
    print("")

    // Time parse+decode for each path (single iteration).
    let p0 = mono()
    let fnGraph = try JSONDecoder().decode(SymbolGraph.self, from: data)
    let p1 = mono()
    let sjStatusQuoGraph = try SymbolGraph(jsonBytes: bytesForm)
    let p2 = mono()
    let sjEventGrainGraph = try SymbolGraph.from(eventDecodingJsonBytes: bytesForm)
    let p3 = mono()
    let foundationTime = p1 - p0
    let statusQuoTime = p2 - p1
    let eventGrainTime = p3 - p2
    report("(once)  Foundation parse+decode", foundationTime)
    report("(once)  swift-json status-quo parse+decode", statusQuoTime)
    report("(once)  swift-json EVENT-GRAIN parse+decode", eventGrainTime)
    print("")
    print("Ratios:")
    print("  status-quo / Foundation:  \(String(format: "%.3f", statusQuoTime / foundationTime))x")
    print("  event-grain / Foundation: \(String(format: "%.3f", eventGrainTime / foundationTime))x   [A2 axis (a)]")
    print("  event-grain / status-quo: \(String(format: "%.3f", eventGrainTime / statusQuoTime))x   (wedge close)")
    print("")

    // Validate equivalent results
    let fnCount = fnGraph.symbols.count
    let sjStatusQuoCount = sjStatusQuoGraph.symbols.count
    let sjEventGrainCount = sjEventGrainGraph.symbols.count
    guard fnCount == sjStatusQuoCount, sjStatusQuoCount == sjEventGrainCount else {
        print("symbol counts diverge: fn=\(fnCount) sj-sq=\(sjStatusQuoCount) sj-eg=\(sjEventGrainCount)")
        exit(1)
    }
    print("symbol count: \(fnCount) (all three paths match)")
    print("")

    // Lookup pass parity check across all three.
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in fnGraph.symbols {
                sink &+= sym.kind.identifier.count
                sink &+= sym.identifier.precise.count
                sink &+= sym.pathComponents.count
            }
        }
        if sink == 0 { print("(DCE FN)") }
        report("Foundation lookup pass (×\(iters))", mono() - t0)
    }
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in sjStatusQuoGraph.symbols {
                sink &+= sym.kind.identifier.count
                sink &+= sym.identifier.precise.count
                sink &+= sym.pathComponents.count
            }
        }
        if sink == 0 { print("(DCE SJ-SQ)") }
        report("swift-json status-quo lookup pass (×\(iters))", mono() - t0)
    }
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<iters {
            for sym in sjEventGrainGraph.symbols {
                sink &+= sym.kind.identifier.count
                sink &+= sym.identifier.precise.count
                sink &+= sym.pathComponents.count
            }
        }
        if sink == 0 { print("(DCE SJ-EG)") }
        report("swift-json event-grain lookup pass (×\(iters))", mono() - t0)
    }

    print("")
    print("=== A2 axis (b): default-fallback non-regression probe ===")
    print("Tiny JSON {\"name\":\"x\",\"age\":1}; 100 000 iters; both paths.")
    let probeJSON = #"{"name":"Alice","age":30}"#
    let probeBytes: [Byte] = probeJSON.utf8.map(Byte.init)
    let probeIters = 100_000

    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<probeIters {
            let v = try DefaultFallbackProbe(jsonBytes: probeBytes)
            sink &+= v.age
        }
        if sink == 0 { print("(DCE probe-SQ)") }
        let dt = mono() - t0
        report("DefaultFallbackProbe status-quo (×\(probeIters))", dt)
    }
    do {
        let t0 = mono()
        var sink: Int = 0
        for _ in 0..<probeIters {
            let v = try DefaultFallbackProbe.from(eventDecodingJsonBytes: probeBytes)
            sink &+= v.age
        }
        if sink == 0 { print("(DCE probe-EG)") }
        let dt = mono() - t0
        report("DefaultFallbackProbe default-fallback (×\(probeIters))", dt)
    }

    print("")
    print("Equivalent reads per iteration: 3 × \(fnCount) = \(3 * fnCount)")
    print("Total reads over \(iters) iters: \(3 * fnCount * iters)")
}

// SANITY mode: verify both parsers actually built the tree by extracting
// known fields. Run with `... 1 sanity` to engage.
if mode == "sanity" {
    print("=== SANITY: extract module.name from both parsers ===")
    do {
        let json = try JSON.parse(stringForm)
        let moduleName: String? = {
            guard json.isObject else { return nil }
            let modJSON = json.module
            return modJSON.isObject ? String(modJSON.name) : nil
        }()
        print("  swift-json parsed; json.module.name = \(moduleName ?? "<missing>")")
    }
    do {
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = parsed as? [String: Any],
              let mod = root["module"] as? [String: Any],
              let name = mod["name"] as? String else {
            print("  Foundation parsed; module.name = <missing or wrong shape>")
            exit(1)
        }
        print("  Foundation parsed; module.name = \(name)")
    }
    print("")
    print("If both lines print the same module name, both parsers built non-trivial trees.")
    print("")

    // Now compare wall-clock with tree-traversal included.
    print("=== SANITY: parse + traverse + assertion ===")
    let countSymbolsSwiftJSON: (String) throws -> Int = { s in
        let root = try JSON.parse(s)
        guard let arr = root.symbols.array else { return -1 }
        return arr.count
    }
    let countSymbolsFoundation: (Data) throws -> Int = { d in
        let parsed = try JSONSerialization.jsonObject(with: d, options: [])
        guard let root = parsed as? [String: Any],
              let arr = root["symbols"] as? [Any] else { return -1 }
        return arr.count
    }

    do {
        let t0 = mono()
        for _ in 0..<iters {
            let n = try countSymbolsSwiftJSON(stringForm)
            if n < 0 { fatalError("swift-json: symbols not array") }
        }
        report("swift-json parse + symbols.count", mono() - t0)
    }
    do {
        let t0 = mono()
        for _ in 0..<iters {
            let n = try countSymbolsFoundation(data)
            if n < 0 { fatalError("Foundation: symbols not array") }
        }
        report("Foundation parse + symbols.count", mono() - t0)
    }

    // Confirm same count
    let nA = try countSymbolsSwiftJSON(stringForm)
    let nB = try countSymbolsFoundation(data)
    print("")
    print("symbol count: swift-json=\(nA) Foundation=\(nB) match=\(nA == nB)")
}

// EQUIV mode: deep tree equivalence check across multiple fields.
if mode == "equiv" {
    let sj = try JSON.parse(stringForm)
    let fn = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

    print("=== top-level keys ===")
    if let obj = sj.object {
        let keys = obj.map { $0.key }.sorted()
        print("  swift-json: \(keys)")
    }
    print("  Foundation: \(fn.keys.sorted())")

    print("\n=== symbols.count ===")
    let sjSymCount = sj.symbols.array?.count ?? -1
    let fnSymCount = (fn["symbols"] as? [Any])?.count ?? -1
    print("  swift-json: \(sjSymCount)")
    print("  Foundation: \(fnSymCount)")
    print("  match: \(sjSymCount == fnSymCount && sjSymCount > 0)")

    print("\n=== relationships.count ===")
    let sjRelCount = sj.relationships.array?.count ?? -1
    let fnRelCount = (fn["relationships"] as? [Any])?.count ?? -1
    print("  swift-json: \(sjRelCount)")
    print("  Foundation: \(fnRelCount)")
    print("  match: \(sjRelCount == fnRelCount && sjRelCount > 0)")

    print("\n=== module.name ===")
    let sjModName = String(sj.module.name)
    let fnModName = ((fn["module"] as? [String: Any])?["name"] as? String) ?? "?"
    print("  swift-json: \(sjModName)")
    print("  Foundation: \(fnModName)")
    print("  match: \(sjModName == fnModName && !sjModName.isEmpty)")

    print("\n=== symbols[0].kind.identifier ===")
    let s0 = sj.symbols[0]
    if let arr = fn["symbols"] as? [Any],
       let f0 = arr.first as? [String: Any],
       let f0kind = f0["kind"] as? [String: Any],
       let f0id = f0kind["identifier"] as? String {
        let sjK = String(s0.kind.identifier)
        print("  swift-json: \(sjK)")
        print("  Foundation: \(f0id)")
        print("  match: \(sjK == f0id && !sjK.isEmpty)")
    }

    print("\n=== relationships[0].kind ===")
    let r0sj = sj.relationships[0]
    if let arr = fn["relationships"] as? [Any],
       let r0fn = arr.first as? [String: Any],
       let r0kind = r0fn["kind"] as? String {
        let sjK = String(r0sj.kind)
        print("  swift-json: \(sjK)")
        print("  Foundation: \(r0kind)")
        print("  match: \(sjK == r0kind && !sjK.isEmpty)")
    }

    print("\n=== last symbol's pathComponents ===")
    let lastIdx = sjSymCount - 1
    let sN = sj.symbols[lastIdx]
    if let fNarr = fn["symbols"] as? [Any],
       let fN = fNarr[lastIdx] as? [String: Any] {
        let sjPaths = sN.pathComponents.array?.compactMap { $0.isString ? String($0) : nil } ?? []
        let fnPaths = (fN["pathComponents"] as? [Any])?.compactMap { $0 as? String } ?? []
        print("  swift-json: \(sjPaths)")
        print("  Foundation: \(fnPaths)")
        print("  match: \(sjPaths == fnPaths && !sjPaths.isEmpty)")
    }
}

// STATS mode: MIN/median/p90/mean per-iter, Foundation + swift-json bytes
// back-to-back. Apple's NewCodable methodology — MIN-of-N + warmup is
// canonical low-noise. Reports ms/iter for each parser and the ratio
// (swift-json / Foundation) at each statistic.
if mode == "stats" {
    let warmup = warmupCount(for: iters)
    print("=== STATS: per-iter Foundation vs swift-json (bytes path) ===")
    print("Methodology: MIN/median/p90/mean across \(iters) measured iters; \(warmup) warmup iters.")
    print("")

    // Foundation: warmup
    for _ in 0..<warmup {
        _ = try JSONSerialization.jsonObject(with: data, options: [])
    }
    // Foundation: measured
    var foundationSamples: [Double] = []
    foundationSamples.reserveCapacity(iters)
    for _ in 0..<iters {
        let t0 = mono()
        _ = try JSONSerialization.jsonObject(with: data, options: [])
        let t1 = mono()
        foundationSamples.append((t1 - t0) * 1000.0)
    }
    let foundationStats = computeStats(foundationSamples)

    // swift-json: warmup
    for _ in 0..<warmup {
        _ = try JSON.parse(bytesForm)
    }
    // swift-json: measured
    var sjSamples: [Double] = []
    sjSamples.reserveCapacity(iters)
    for _ in 0..<iters {
        let t0 = mono()
        _ = try JSON.parse(bytesForm)
        let t1 = mono()
        sjSamples.append((t1 - t0) * 1000.0)
    }
    let sjStats = computeStats(sjSamples)

    print("Foundation.JSONSerialization.jsonObject(with:) — ms/iter:")
    reportStat("Foundation", foundationStats, unit: "ms")
    print("")
    print("swift-json JSON.parse([UInt8]) — ms/iter:")
    reportStat("swift-json", sjStats, unit: "ms")
    print("")
    print("Ratio swift-json / Foundation:")
    print("    \(pad("min", 10)) \(String(format: "%10.2fx", sjStats.min / foundationStats.min))")
    print("    \(pad("median", 10)) \(String(format: "%10.2fx", sjStats.median / foundationStats.median))")
    print("    \(pad("p90", 10)) \(String(format: "%10.2fx", sjStats.p90 / foundationStats.p90))")
    print("    \(pad("mean", 10)) \(String(format: "%10.2fx", sjStats.mean / foundationStats.mean))")
}

// FLOAT-MICROBENCH mode: per-call comparison of the EL float parser
// (`ASCII.Decimal.Float.parse(_: borrowing Swift.Span<UInt8>)`) against
// stdlib `Double(_: String)`. Scans the input for float tokens (numbers
// containing `.`, `e`, or `E` — the production set that `lexNumberValue`
// routes through EL), verifies bit-pattern agreement, then times both
// per-call across N iters with warmup. Authoritative empirical test for
// the v1.1.0 canada-anomaly tree-shape claim.
if mode == "float-microbench" {
    let warmup = warmupCount(for: iters)
    print("=== FLOAT-MICROBENCH: per-call EL parser vs Double(_: String) ===")
    print("Source tokens: float-shaped numbers in input (containing '.', 'e', or 'E').")
    print("")

    // Scan for float tokens. State machine tracks JSON string scope so
    // we never pick up digits embedded inside string literals.
    var tokens: [(start: Int, count: Int)] = []
    tokens.reserveCapacity(150_000)
    do {
        var i = 0
        let n = bytesForm.count
        var inString = false
        var escaped = false
        while i < n {
            let b = bytesForm[i]
            if escaped { escaped = false; i &+= 1; continue }
            if inString {
                if b == 0x5C { escaped = true; i &+= 1; continue }
                if b == 0x22 { inString = false; i &+= 1; continue }
                i &+= 1; continue
            }
            if b == 0x22 { inString = true; i &+= 1; continue }
            let isMinus = b == 0x2D
            let isDigit = b >= 0x30 && b <= 0x39
            if isMinus || isDigit {
                let start = i
                var sawDot = false
                var sawExp = false
                if isMinus { i &+= 1 }
                while i < n {
                    let c = bytesForm[i]
                    let cIsDigit = c >= 0x30 && c <= 0x39
                    if cIsDigit { i &+= 1; continue }
                    if c == 0x2E { sawDot = true; i &+= 1; continue }
                    if c == 0x65 || c == 0x45 {
                        sawExp = true
                        i &+= 1
                        if i < n {
                            let s = bytesForm[i]
                            if s == 0x2D || s == 0x2B { i &+= 1 }
                        }
                        continue
                    }
                    break
                }
                let count = i &- start
                if (sawDot || sawExp) && count > 0 {
                    tokens.append((start: start, count: count))
                }
                continue
            }
            i &+= 1
        }
    }
    let tokenCount = tokens.count
    print("Float tokens collected: \(tokenCount)")
    if tokenCount == 0 {
        print("(no float tokens in input — float-microbench is meaningless)")
    } else {
        print("Mean token length: \(String(format: "%.2f", Double(tokens.reduce(0) { $0 + $1.count }) / Double(tokenCount))) bytes")
    }
    print("")

    // Bit-equivalence verification: each token's EL parse must agree
    // with `Double(_: String)` in raw bitPattern.
    var mismatches = 0
    var firstMismatchToken: String? = nil
    var firstMismatchEL: Double = 0
    var firstMismatchStdlib: Double? = nil
    do {
        let wholeSpan = bytesForm.span
        for tok in tokens {
            let tokenSpan = wholeSpan.extracting(tok.start..<(tok.start &+ tok.count))
            let dEL: Double
            do {
                dEL = try ASCII.Decimal.Float.parse(tokenSpan)
            } catch {
                mismatches &+= 1
                if firstMismatchToken == nil {
                    firstMismatchToken = String(decoding: bytesForm[tok.start..<(tok.start &+ tok.count)], as: UTF8.self)
                    firstMismatchEL = .nan
                    firstMismatchStdlib = nil
                }
                continue
            }
            let strForm = String(decoding: bytesForm[tok.start..<(tok.start &+ tok.count)], as: UTF8.self)
            let dStdlib = Double(strForm)
            if dEL.bitPattern != (dStdlib?.bitPattern ?? 0) || dStdlib == nil {
                mismatches &+= 1
                if firstMismatchToken == nil {
                    firstMismatchToken = strForm
                    firstMismatchEL = dEL
                    firstMismatchStdlib = dStdlib
                }
            }
        }
    }
    print("Bit-pattern verification: \(mismatches) mismatch\(mismatches == 1 ? "" : "es") across \(tokenCount) tokens.")
    if let tok = firstMismatchToken {
        print("  First mismatch: token=\(tok)  EL=\(firstMismatchEL)  stdlib=\(firstMismatchStdlib.map(String.init(describing:)) ?? "<nil>")")
    }
    print("")

    guard tokenCount > 0 else {
        print("Skipping timing pass (no float tokens).")
        print("")
        print("done.")
        exit(0)
    }

    // Pre-materialise String forms so the stdlib loop times only
    // `Double(_: String)`, not the String allocation. EL loop times
    // only `ASCII.Decimal.Float.parse` — the span construction
    // (extracting an `~Escapable` Span from a parent Span) is the
    // production hot path's shape, matching `lexNumberValue`'s
    // `let span = bytes.span` then call.
    let tokenStrings: [String] = tokens.map {
        String(decoding: bytesForm[$0.start..<($0.start &+ $0.count)], as: UTF8.self)
    }

    print("Timing: \(warmup) warmup iters + \(iters) measured iters; per-iter walks all \(tokenCount) tokens.")
    print("")

    // EL: warmup
    do {
        let wholeSpan = bytesForm.span
        for _ in 0..<warmup {
            var sink: UInt64 = 0
            for tok in tokens {
                let s = wholeSpan.extracting(tok.start..<(tok.start &+ tok.count))
                let d = (try? ASCII.Decimal.Float.parse(s)) ?? 0
                sink = sink &+ d.bitPattern
            }
            if sink == 0 { print("(DCE EL warmup)") }
        }
    }
    // EL: measured
    var elSamples: [Double] = []
    elSamples.reserveCapacity(iters)
    do {
        let wholeSpan = bytesForm.span
        for _ in 0..<iters {
            var sink: UInt64 = 0
            let t0 = mono()
            for tok in tokens {
                let s = wholeSpan.extracting(tok.start..<(tok.start &+ tok.count))
                let d = (try? ASCII.Decimal.Float.parse(s)) ?? 0
                sink = sink &+ d.bitPattern
            }
            let t1 = mono()
            if sink == 0 { print("(DCE EL)") }
            // ns per call = (seconds per iter * 1e9) / tokens-per-iter
            elSamples.append((t1 - t0) * 1e9 / Double(tokenCount))
        }
    }
    let elStats = computeStats(elSamples)

    // Stdlib: warmup
    for _ in 0..<warmup {
        var sink: UInt64 = 0
        for s in tokenStrings {
            let d = Double(s) ?? 0
            sink = sink &+ d.bitPattern
        }
        if sink == 0 { print("(DCE stdlib warmup)") }
    }
    // Stdlib: measured
    var stdSamples: [Double] = []
    stdSamples.reserveCapacity(iters)
    for _ in 0..<iters {
        var sink: UInt64 = 0
        let t0 = mono()
        for s in tokenStrings {
            let d = Double(s) ?? 0
            sink = sink &+ d.bitPattern
        }
        let t1 = mono()
        if sink == 0 { print("(DCE stdlib)") }
        stdSamples.append((t1 - t0) * 1e9 / Double(tokenCount))
    }
    let stdStats = computeStats(stdSamples)

    print("ASCII.Decimal.Float.parse — ns/call:")
    reportStat("EL", elStats, unit: "ns")
    print("")
    print("Double(_: String) — ns/call:")
    reportStat("stdlib", stdStats, unit: "ns")
    print("")
    print("Ratio stdlib / EL (>1 = EL faster):")
    print("    \(pad("min", 10)) \(String(format: "%10.2fx", stdStats.min / elStats.min))")
    print("    \(pad("median", 10)) \(String(format: "%10.2fx", stdStats.median / elStats.median))")
    print("    \(pad("p90", 10)) \(String(format: "%10.2fx", stdStats.p90 / elStats.p90))")
    print("    \(pad("mean", 10)) \(String(format: "%10.2fx", stdStats.mean / elStats.mean))")
    print("")
    print("Wall-clock-savings ceiling (per parse) = N × (t_stdlib − t_EL):")
    print("  min-vs-min:   \(String(format: "%8.2f ms", Double(tokenCount) * (stdStats.min - elStats.min) / 1_000_000.0))")
    print("  median-vs-median: \(String(format: "%8.2f ms", Double(tokenCount) * (stdStats.median - elStats.median) / 1_000_000.0))")
    print("  mean-vs-mean: \(String(format: "%8.2f ms", Double(tokenCount) * (stdStats.mean - elStats.mean) / 1_000_000.0))")
    print("")
    print("Phase 3 adjudication input (per parse-performance-canada-anomaly.md v1.1.0):")
    print("  t_EL ≥ 3× t_stdlib AND savings-ceiling ≪ 220 ms → VALIDATED (tree-shape dominates)")
    print("  t_EL ≲ t_stdlib OR savings-ceiling ≥ 100 ms → REFUTED (EL slow OR room for further float speedup)")
    print("  In between → MIXED")
}

// TREE-MICROBENCH mode: decompose the residual ~233 ms canada tree-emit
// cost into three components:
//
//   (1) alloc    — per-`RFC_8259.Value.number(...)` construction cost.
//                  Time the construction of `RFC_8259.Value.number(
//                  RFC_8259.Number(0.0, original: .init(span)))` per
//                  real canada Number span, no parse, no scan, no
//                  storage. Pure enum-init + Number + Original cost.
//   (2) grow     — `[RFC_8259.Value].append` cost at canada's actual
//                  array-size distribution. Walk the live tree once
//                  to harvest the per-array element counts; in the
//                  measured loop, allocate fresh `[RFC_8259.Value]`s
//                  (with the production `reserveCapacity(4)` hint per
//                  Patch 2) and append `.null` to each at its target
//                  size. Captures array-doubling + ARC traffic on
//                  fresh storage.
//   (3) teardown — `outlined destroy of RFC_8259.Value` recursive
//                  release cost. Parse canada once into a holder
//                  Optional, then per iter time the `holder = nil`
//                  assignment that triggers the full tree drop. The
//                  pre-iter re-parse rebuilds the tree for the next
//                  measurement.
//
// Each component runs under the standard 16 warmup + N measured iters
// methodology. Per-iter total reported in ms (MIN/median/p90/mean).
//
// Sanity bound: alloc + grow + teardown should approximate the canada
// parse cost minus the lex floor (~10–20 ms). If the components sum to
// <50 % of the measured parse cost, flag the missing-component
// blind spot; if >120 %, flag over-attribution (component bench costs
// inflate compared to in-context production cost).
//
// Adjudication: drives Path A (allocation-heavy) vs Path B (teardown-
// heavy) vs array-targeted fix (grow-heavy) — the next architectural
// gate per parse-performance-canada-anomaly.md v1.2.0's "Next arc must
// target tree shape".
if mode == "tree-microbench" {
    let warmup = warmupCount(for: iters)
    print("=== TREE-MICROBENCH: decompose canada tree-emit residual ===")
    print("Components: (1) per-Value alloc, (2) intermediate array growth, (3) tree teardown.")
    print("Methodology: MIN/median/p90/mean across \(iters) measured iters; \(warmup) warmup iters.")
    print("")

    // -- Harvest 1: ALL number tokens (float + integer-shaped).
    // Mirrors the float-microbench scanner without the `sawDot || sawExp`
    // filter — captures every JSON number literal in the input so the
    // alloc-cost loop runs on production-shaped spans.
    var numberTokens: [(start: Int, count: Int)] = []
    numberTokens.reserveCapacity(150_000)
    do {
        var i = 0
        let n = bytesForm.count
        var inString = false
        var escaped = false
        while i < n {
            let b = bytesForm[i]
            if escaped { escaped = false; i &+= 1; continue }
            if inString {
                if b == 0x5C { escaped = true; i &+= 1; continue }
                if b == 0x22 { inString = false; i &+= 1; continue }
                i &+= 1; continue
            }
            if b == 0x22 { inString = true; i &+= 1; continue }
            let isMinus = b == 0x2D
            let isDigit = b >= 0x30 && b <= 0x39
            if isMinus || isDigit {
                let start = i
                if isMinus { i &+= 1 }
                while i < n {
                    let c = bytesForm[i]
                    let cIsDigit = c >= 0x30 && c <= 0x39
                    if cIsDigit { i &+= 1; continue }
                    if c == 0x2E { i &+= 1; continue }
                    if c == 0x65 || c == 0x45 {
                        i &+= 1
                        if i < n {
                            let s = bytesForm[i]
                            if s == 0x2D || s == 0x2B { i &+= 1 }
                        }
                        continue
                    }
                    break
                }
                let count = i &- start
                if count > 0 {
                    numberTokens.append((start: start, count: count))
                }
                continue
            }
            i &+= 1
        }
    }
    let numberCount = numberTokens.count
    print("Number tokens collected: \(numberCount)")
    if numberCount == 0 {
        print("(no number tokens in input — tree-microbench is meaningless)")
        print("done.")
        exit(0)
    }
    let meanNumLen = Double(numberTokens.reduce(0) { $0 + $1.count }) / Double(numberCount)
    print("Mean number token length: \(String(format: "%.2f", meanNumLen)) bytes")
    print("")

    // -- Harvest 2: array-size distribution.
    // Parse canada once; walk the tree gathering the count of
    // elements per array. The grow loop replays this distribution.
    // Uses JSON.Decode.parse which surfaces RFC_8259.Value directly.
    let harvestRoot: RFC_8259.Value = try JSON.Decode.parse(bytesForm)
    var arraySizes: [Int] = []
    arraySizes.reserveCapacity(60_000)
    func collectArraySizes(_ v: RFC_8259.Value) {
        switch v {
        case .array(let a):
            arraySizes.append(a.count)
            for child in a { collectArraySizes(child) }
        case .object(let o):
            for (_, child) in o { collectArraySizes(child) }
        default:
            break
        }
    }
    collectArraySizes(harvestRoot)
    let arrayCount = arraySizes.count
    let totalAppends = arraySizes.reduce(0, +)
    print("Array nodes collected: \(arrayCount)")
    print("Total appends across all arrays: \(totalAppends)")
    if arrayCount > 0 {
        let meanSize = Double(totalAppends) / Double(arrayCount)
        print("Mean array size: \(String(format: "%.2f", meanSize)) elements")
        // Compact distribution summary.
        var hist: [Int: Int] = [:]
        for s in arraySizes { hist[s, default: 0] &+= 1 }
        let sortedSizes = hist.keys.sorted()
        let topSizes = sortedSizes.prefix(8)
        let dist = topSizes.map { "\($0)→\(hist[$0]!)" }.joined(separator: " ")
        print("Top sizes (size→count): \(dist) ...")
    }
    print("")

    // Reference: full swift-json parse cost on this machine (single
    // measurement, for sanity-bound comparison). Re-uses warmup +
    // MIN-of-N on the same iter budget.
    print("Reference: full swift-json parse cost ...")
    for _ in 0..<warmup {
        _ = try JSON.parse(bytesForm)
    }
    var parseSamples: [Double] = []
    parseSamples.reserveCapacity(iters)
    for _ in 0..<iters {
        let t0 = mono()
        _ = try JSON.parse(bytesForm)
        let t1 = mono()
        parseSamples.append((t1 - t0) * 1000.0)
    }
    let parseStats = computeStats(parseSamples)
    reportStat("parse", parseStats, unit: "ms")
    print("")

    // ------------------------------------------------------------------
    // (1) ALLOC — per-Value.number(...) construction
    //
    // Builds `RFC_8259.Value.number(RFC_8259.Number(value: 0.0,
    // original: RFC_8259.Number.Original(span)))` per real canada
    // Number span. Uses a fixed `value=0.0` to factor out the float-
    // parse cost (covered by float-microbench) — this isolates the
    // alloc + enum-construction surface.
    print("(1) ALLOC — per-Value.number(Number(value, original)) construction")
    do {
        let wholeSpan = bytesForm.span
        // Warmup
        for _ in 0..<warmup {
            var sink: UInt64 = 0
            for tok in numberTokens {
                let s = wholeSpan.extracting(tok.start..<(tok.start &+ tok.count))
                let original = RFC_8259.Number.Original(s)
                let number = RFC_8259.Number(0.0, original: original)
                let value: RFC_8259.Value = .number(number)
                // Touch a field to defeat DCE without doing extra work.
                if case .number(let n) = value { sink = sink &+ UInt64(n.original.bytes.count) }
            }
            if sink == 0 { print("(DCE alloc warmup)") }
        }
        // Measured
        var allocSamples: [Double] = []
        allocSamples.reserveCapacity(iters)
        for _ in 0..<iters {
            var sink: UInt64 = 0
            let t0 = mono()
            for tok in numberTokens {
                let s = wholeSpan.extracting(tok.start..<(tok.start &+ tok.count))
                let original = RFC_8259.Number.Original(s)
                let number = RFC_8259.Number(0.0, original: original)
                let value: RFC_8259.Value = .number(number)
                if case .number(let n) = value { sink = sink &+ UInt64(n.original.bytes.count) }
            }
            let t1 = mono()
            if sink == 0 { print("(DCE alloc)") }
            allocSamples.append((t1 - t0) * 1000.0)
        }
        let allocStats = computeStats(allocSamples)
        reportStat("alloc", allocStats, unit: "ms")
        let perValueNS = allocStats.min * 1_000_000.0 / Double(numberCount)
        print("    per-Value (min): \(String(format: "%.2f", perValueNS)) ns/Value")
        print("")

        // ----------------------------------------------------------------
        // (2) GROW — intermediate-array append at canada's size distribution.
        //
        // Mirrors production's post-Patch-2 `parseArray` hot path: for
        // each array node observed in canada, allocate a fresh
        // `[RFC_8259.Value]`, apply `reserveCapacity(4)` (the live patch
        // since 2026-05-19), then append `.null` up to the target size.
        // Captures the `Swift.Array` doubling + ARC traffic on fresh
        // storage. Doesn't include the cost of materialising the inner
        // Values (covered separately by alloc).
        print("(2) GROW — fresh-array allocation + append at canada size distribution")
        // Warmup
        for _ in 0..<warmup {
            var sink: Int = 0
            for size in arraySizes {
                var elements: [RFC_8259.Value] = []
                elements.reserveCapacity(4)
                for _ in 0..<size { elements.append(.null) }
                sink &+= elements.count
            }
            if sink == 0 { print("(DCE grow warmup)") }
        }
        // Measured
        var growSamples: [Double] = []
        growSamples.reserveCapacity(iters)
        for _ in 0..<iters {
            var sink: Int = 0
            let t0 = mono()
            for size in arraySizes {
                var elements: [RFC_8259.Value] = []
                elements.reserveCapacity(4)
                for _ in 0..<size { elements.append(.null) }
                sink &+= elements.count
            }
            let t1 = mono()
            if sink == 0 { print("(DCE grow)") }
            growSamples.append((t1 - t0) * 1000.0)
        }
        let growStats = computeStats(growSamples)
        reportStat("grow", growStats, unit: "ms")
        let perAppendNS = growStats.min * 1_000_000.0 / Double(totalAppends == 0 ? 1 : totalAppends)
        print("    per-append (min): \(String(format: "%.2f", perAppendNS)) ns/append")
        print("")

        // ----------------------------------------------------------------
        // (3) TEARDOWN — `outlined destroy of RFC_8259.Value` recursive
        // release. Per iter: rebuild the tree (cost factored OUT of the
        // measurement window), then time the holder = nil assignment
        // that triggers the recursive ARC drop.
        // The naive `var holder: Value? = parse(); t0; holder = nil; t1`
        // returns ~0 because the optimizer (a) sinks the destroy past
        // `t1` since `holder` is dead after the assignment, OR (b)
        // hoists work into the parse phase. Two defenses:
        //   1. Use `Swift.withExtendedLifetime` to bind the tree's
        //      lifetime to a closure scope and force the destroy to
        //      happen at scope exit, between t0 and t1.
        //   2. Take a `Swift.Hasher` snapshot of a tree leaf before
        //      t0 and combine into a sink AFTER t1 to defeat dead-
        //      store elimination on the parse side.
        // Pattern: bind `tree` to a local Optional, snapshot a cheap
        // observable (`isObject`) into sink BEFORE t0, set t0, drop
        // tree by reassigning to `.null` (a value-type "drop"), set
        // t1. The reassignment forces destroy of the previous tree.
        print("(3) TEARDOWN — recursive RFC_8259.Value destroy via reassignment")
        var globalSink: Int = 0
        // Warmup
        for _ in 0..<warmup {
            var tree: RFC_8259.Value = try JSON.Decode.parse(bytesForm)
            // Observe pre-drop to prevent parse hoisting.
            globalSink &+= tree.array?.count ?? 0
            // Drop by reassignment to a trivial value (destroys the previous).
            tree = .null
            // Observe post-drop to prevent tree dropping into a no-op.
            globalSink &+= (tree.isNull ? 1 : 0)
        }
        // Measured
        var teardownSamples: [Double] = []
        teardownSamples.reserveCapacity(iters)
        for _ in 0..<iters {
            // Rebuild tree (cost factored OUT of the timed window).
            var tree: RFC_8259.Value = try JSON.Decode.parse(bytesForm)
            // Pre-timing observation: forces parse to complete before t0.
            globalSink &+= tree.array?.count ?? 0
            // Time the drop via reassignment.
            let t0 = mono()
            tree = .null
            let t1 = mono()
            // Post-timing observation: prevents reassignment elision.
            globalSink &+= (tree.isNull ? 1 : 0)
            teardownSamples.append((t1 - t0) * 1000.0)
        }
        if globalSink == 0 { print("(DCE teardown)") }
        let teardownStats = computeStats(teardownSamples)
        reportStat("teardown", teardownStats, unit: "ms")
        print("")

        // ----------------------------------------------------------------
        // Decomposition summary.
        let totalComponent = allocStats.min + growStats.min + teardownStats.min
        let parseFloor = parseStats.min
        let totalRatio = totalComponent / parseFloor

        print("=== DECOMPOSITION ===")
        print("Per-iter MIN (ms):")
        print("    alloc      = \(String(format: "%8.2f", allocStats.min))    \(String(format: "%5.1f", 100.0 * allocStats.min / parseFloor))% of parse-floor")
        print("    grow       = \(String(format: "%8.2f", growStats.min))    \(String(format: "%5.1f", 100.0 * growStats.min / parseFloor))% of parse-floor")
        print("    teardown   = \(String(format: "%8.2f", teardownStats.min))    \(String(format: "%5.1f", 100.0 * teardownStats.min / parseFloor))% of parse-floor")
        print("    --")
        print("    sum        = \(String(format: "%8.2f", totalComponent))    \(String(format: "%5.1f", 100.0 * totalComponent / parseFloor))% of parse-floor")
        print("    parse min  = \(String(format: "%8.2f", parseFloor))    (reference)")
        print("    residual   = \(String(format: "%8.2f", parseFloor - totalComponent)) ms (lex + scaffolding + measurement noise)")
        print("")

        // Sanity bound: sum should be 50-120% of parse floor (typical
        // case: lex floor ~10-20 ms, components ~210-230 ms, sum ratio
        // ~0.85-0.95).
        if totalRatio < 0.50 {
            print("WARNING: components sum to \(String(format: "%.1f", totalRatio * 100))% of parse cost — < 50%.")
            print("  Suggests a MISSING-COMPONENT blind spot (e.g. RFC_8259.Object growth,")
            print("  or lex cost is larger than estimated, or one of the three components")
            print("  measured here is structurally lighter than in production context).")
        } else if totalRatio > 1.20 {
            print("NOTE: components sum to \(String(format: "%.1f", totalRatio * 100))% of parse cost — > 120%.")
            print("  Microbench likely double-counts work that production amortizes")
            print("  (cache locality, fused allocations, etc.). Per-component ratios")
            print("  remain valid for relative ranking; absolute attribution is upper-bound.")
        } else {
            print("Sanity check: components sum to \(String(format: "%.1f", totalRatio * 100))% of parse cost — within [50%, 120%].")
        }
        print("")

        // Dominant component + path recommendation.
        let components: [(name: String, ms: Double, path: String)] = [
            (name: "alloc",    ms: allocStats.min,    path: "Path A (allocation-heavy: arena / pool / inline-enum)"),
            (name: "grow",     ms: growStats.min,     path: "Array-targeted fix (size-prediction / chunked buffer / pre-reserve)"),
            (name: "teardown", ms: teardownStats.min, path: "Path B (teardown-heavy: ~Copyable Value cascade / arena drop)")
        ]
        let sortedComps = components.sorted { $0.ms > $1.ms }
        let dominant = sortedComps[0]
        let second = sortedComps[1]
        let third = sortedComps[2]
        let dominantShare = dominant.ms / totalComponent

        print("=== DOMINANT COMPONENT ===")
        print("    1. \(dominant.name): \(String(format: "%5.1f", 100.0 * dominantShare))% of component sum")
        print("    2. \(second.name): \(String(format: "%5.1f", 100.0 * second.ms / totalComponent))%")
        print("    3. \(third.name): \(String(format: "%5.1f", 100.0 * third.ms / totalComponent))%")
        print("")
        print("Recommended next architectural lever:")
        if dominantShare > 0.50 {
            print("    \(dominant.path)")
            print("    (>\(String(format: "%.0f", dominantShare * 100))% share — single-lever fix viable)")
        } else {
            print("    COMPOSITE — no single component dominates >50%.")
            print("    Top contributors:")
            print("      - \(dominant.path)")
            print("      - \(second.path)")
        }
    }
}

// LEX-MICROBENCH mode: decomposes canada parse cost's residual (the ~96%
// that tree-microbench surfaced as not-in-tree-emit) into three lex-layer
// components measured directly against the production Lexer.Scanner:
//
//   (A) scanner-walk  — `scanner.consume()` over every byte until end.
//                       Sum byte values to defeat DCE. Per-byte advance
//                       cost (cursor + position tracker + byte read)
//                       in isolation. Upper-bound for production's
//                       cumulative scanner-advance traffic.
//   (B) typed-dispatch — for every byte, `peek() as ASCII.Code` +
//                       6-case switch mirroring parseValue's leading-
//                       byte dispatch. Per-byte type-up + branch cost.
//                       Production fires this once per Value node
//                       (~333K times on canada); this measurement is
//                       an UPPER bound because it walks every byte
//                       rather than skipping inter-token bytes.
//   (C) number-tokenize — replay lexNumberValue's peek-and-consume loop
//                       on each canada Number token (harvested via the
//                       same scanner pass tree-microbench uses).
//                       Per-Number scanner overhead in isolation from
//                       ASCII.Decimal.Float.parse + Number construction.
//
// Same MIN-of-N + warmup methodology as float-microbench and
// tree-microbench. Drives the lex-layer-rework recommendation in
// parse-performance-canada-anomaly.md v1.3.0.
if mode == "lex-microbench" {
    let warmup = warmupCount(for: iters)
    let nBytes = bytesForm.count
    print("=== LEX-MICROBENCH: decompose canada lex residual ===")
    print("Components: (A) scanner advance, (B) typed-peek dispatch, (C) number-tokenize.")
    print("Methodology: MIN/median/p90/mean across \(iters) measured iters; \(warmup) warmup iters.")
    print("")
    print("Input: \(nBytes) bytes (\(String(format: "%.2f", Double(nBytes) / 1048576.0)) MB).")

    // Harvest Number token positions for component (C). Reuses the
    // float-microbench's token-scanner shape, but accepts any number
    // (integer-shaped or float-shaped) since lexNumberValue's peek-
    // and-consume loop is uniform across both.
    var numberTokens: [(start: Int, count: Int)] = []
    numberTokens.reserveCapacity(150_000)
    do {
        var i = 0
        let n = bytesForm.count
        var inString = false
        var escaped = false
        while i < n {
            let b = bytesForm[i]
            if escaped { escaped = false; i &+= 1; continue }
            if inString {
                if b == 0x5C { escaped = true; i &+= 1; continue }
                if b == 0x22 { inString = false; i &+= 1; continue }
                i &+= 1; continue
            }
            if b == 0x22 { inString = true; i &+= 1; continue }
            let isMinus = b == 0x2D
            let isDigit = b >= 0x30 && b <= 0x39
            if isMinus || isDigit {
                let start = i
                if isMinus { i &+= 1 }
                while i < n {
                    let c = bytesForm[i]
                    let cIsDigit = c >= 0x30 && c <= 0x39
                    if cIsDigit { i &+= 1; continue }
                    if c == 0x2E { i &+= 1; continue }
                    if c == 0x65 || c == 0x45 {
                        i &+= 1
                        if i < n {
                            let s = bytesForm[i]
                            if s == 0x2D || s == 0x2B { i &+= 1 }
                        }
                        continue
                    }
                    break
                }
                let count = i &- start
                if count > 0 { numberTokens.append((start: start, count: count)) }
                continue
            }
            i &+= 1
        }
    }
    let nNumbers = numberTokens.count
    print("Number tokens collected: \(nNumbers)")
    print("Mean number-token length: \(String(format: "%.2f", Double(numberTokens.reduce(0) { $0 + $1.count }) / Double(nNumbers))) bytes")
    print("")

    // (A) SCANNER-WALK
    print("(A) SCANNER-WALK — scanner.consume() over every byte")
    do {
        let span = bytesForm.span
        for _ in 0..<warmup {
            var scanner = Lexer.Scanner(span)
            var sink: UInt64 = 0
            while !scanner.isAtEnd {
                sink = sink &+ UInt64(scanner.consume().underlying)
            }
            if sink == 0 { print("(DCE A warmup)") }
        }
    }
    var advSamples: [Double] = []
    advSamples.reserveCapacity(iters)
    do {
        let span = bytesForm.span
        for _ in 0..<iters {
            var scanner = Lexer.Scanner(span)
            var sink: UInt64 = 0
            let t0 = mono()
            while !scanner.isAtEnd {
                sink = sink &+ UInt64(scanner.consume().underlying)
            }
            let t1 = mono()
            if sink == 0 { print("(DCE A)") }
            advSamples.append((t1 - t0) * 1000.0)
        }
    }
    let advStats = computeStats(advSamples)
    reportStat("advance", advStats, unit: "ms")
    print("    per-byte (min): \(String(format: "%.2f ns/byte", advStats.min * 1_000_000.0 / Double(nBytes)))")
    print("")

    // (B) TYPED-DISPATCH
    print("(B) TYPED-DISPATCH — peek() as ASCII.Code + 6-case switch per byte")
    do {
        let span = bytesForm.span
        for _ in 0..<warmup {
            var scanner = Lexer.Scanner(span)
            var sink: Int = 0
            while !scanner.isAtEnd {
                if let code: ASCII.Code = scanner.peek() {
                    switch code {
                    case .leftBrace, .leftBracket, .quotationMark, .n, .t, .f:
                        sink &+= 1
                    default:
                        break
                    }
                }
                scanner.advance()
            }
            if sink == 0 { print("(DCE B warmup)") }
        }
    }
    var dispSamples: [Double] = []
    dispSamples.reserveCapacity(iters)
    do {
        let span = bytesForm.span
        for _ in 0..<iters {
            var scanner = Lexer.Scanner(span)
            var sink: Int = 0
            let t0 = mono()
            while !scanner.isAtEnd {
                if let code: ASCII.Code = scanner.peek() {
                    switch code {
                    case .leftBrace, .leftBracket, .quotationMark, .n, .t, .f:
                        sink &+= 1
                    default:
                        break
                    }
                }
                scanner.advance()
            }
            let t1 = mono()
            if sink == 0 { print("(DCE B)") }
            dispSamples.append((t1 - t0) * 1000.0)
        }
    }
    let dispStats = computeStats(dispSamples)
    reportStat("dispatch", dispStats, unit: "ms")
    print("    per-byte (min): \(String(format: "%.2f ns/byte", dispStats.min * 1_000_000.0 / Double(nBytes)))")
    print("    (upper bound: production fires this once per Value node, ~333K times on canada)")
    print("")

    // (C) NUMBER-TOKENIZE
    print("(C) NUMBER-TOKENIZE — lexNumberValue peek-and-consume replay per Number")
    do {
        let span = bytesForm.span
        for _ in 0..<warmup {
            var sink: Int = 0
            for tok in numberTokens {
                let sub = span.extracting(tok.start..<(tok.start &+ tok.count))
                var scanner = Lexer.Scanner(sub)
                var nb = 0
                while !scanner.isAtEnd {
                    guard let code: ASCII.Code = scanner.peek() else { break }
                    if code.isDigit
                        || code == .hyphen
                        || code == .period
                        || code == .e
                        || code == .E
                        || code == .plusSign {
                        _ = scanner.consume()
                        nb &+= 1
                    } else {
                        break
                    }
                }
                sink &+= nb
            }
            if sink == 0 { print("(DCE C warmup)") }
        }
    }
    var numSamples: [Double] = []
    numSamples.reserveCapacity(iters)
    do {
        let span = bytesForm.span
        for _ in 0..<iters {
            var sink: Int = 0
            let t0 = mono()
            for tok in numberTokens {
                let sub = span.extracting(tok.start..<(tok.start &+ tok.count))
                var scanner = Lexer.Scanner(sub)
                var nb = 0
                while !scanner.isAtEnd {
                    guard let code: ASCII.Code = scanner.peek() else { break }
                    if code.isDigit
                        || code == .hyphen
                        || code == .period
                        || code == .e
                        || code == .E
                        || code == .plusSign {
                        _ = scanner.consume()
                        nb &+= 1
                    } else {
                        break
                    }
                }
                sink &+= nb
            }
            let t1 = mono()
            if sink == 0 { print("(DCE C)") }
            numSamples.append((t1 - t0) * 1000.0)
        }
    }
    let numStats = computeStats(numSamples)
    reportStat("num-tok", numStats, unit: "ms")
    print("    per-token (min): \(String(format: "%.2f ns/token", numStats.min * 1_000_000.0 / Double(nNumbers)))")
    print("")

    // Reference parse cost
    print("Reference: full swift-json parse cost (warmup + measured)")
    for _ in 0..<warmup {
        _ = try JSON.parse(bytesForm)
    }
    var parseSamples: [Double] = []
    parseSamples.reserveCapacity(iters)
    for _ in 0..<iters {
        let t0 = mono()
        _ = try JSON.parse(bytesForm)
        let t1 = mono()
        parseSamples.append((t1 - t0) * 1000.0)
    }
    let parseStats = computeStats(parseSamples)
    reportStat("parse", parseStats, unit: "ms")
    print("")

    // Decomposition
    print("=== DECOMPOSITION ===")
    print("Per-iter MIN (ms):")
    let parseMin = parseStats.min
    let advMin = advStats.min
    let dispMin = dispStats.min
    let numMin = numStats.min
    print("    advance         = \(String(format: "%8.2f", advMin))   \(String(format: "%5.1f%%", 100.0 * advMin / parseMin))  of parse")
    print("    dispatch        = \(String(format: "%8.2f", dispMin))   \(String(format: "%5.1f%%", 100.0 * dispMin / parseMin))  of parse (upper bound)")
    print("    number-tokenize = \(String(format: "%8.2f", numMin))   \(String(format: "%5.1f%%", 100.0 * numMin / parseMin))  of parse")
    print("    --")
    print("    parse min       = \(String(format: "%8.2f", parseMin))   (reference)")
    print("")
    print("Note: (A) advance vs (B) dispatch are NOT additive — both walk every byte;")
    print("production blends them. (C) is a separate per-Number axis.")
    print("")

    // Recommendation
    if advMin > 0.5 * parseMin {
        print("Recommended next architectural lever:")
        print("    SCANNER advance is \(String(format: "%.0f%%", 100.0 * advMin / parseMin)) of parse — dominant.")
        print("    Investigate: Text.Location.Tracker overhead per advance,")
        print("    bulk-byte loads, lazier position tracking on the hot path.")
    } else if dispMin > 0.5 * parseMin {
        print("Recommended next architectural lever:")
        print("    TYPED-DISPATCH is \(String(format: "%.0f%%", 100.0 * dispMin / parseMin)) of parse (upper bound).")
        print("    Investigate: skip-whitespace fastpath, table-driven classifier,")
        print("    SWAR whitespace scan.")
    } else if numMin > 0.3 * parseMin {
        print("Recommended next architectural lever:")
        print("    NUMBER-TOKENIZE is \(String(format: "%.0f%%", 100.0 * numMin / parseMin)) of parse.")
        print("    Investigate: combined lex+parse fast path for numbers,")
        print("    eliminate the Array<Byte>.Small<24> accumulator (parse directly off the input span).")
    } else {
        print("Decomposition residual: \(String(format: "%.0f%%", 100.0 * (parseMin - advMin - numMin) / parseMin)) unaccounted.")
        print("Investigate: skipWhitespace, Number value-construction overhead beyond ALLOC bench,")
        print("Object-key tokenization, scanner state setup per call.")
    }
}

print("")
print("done.")
