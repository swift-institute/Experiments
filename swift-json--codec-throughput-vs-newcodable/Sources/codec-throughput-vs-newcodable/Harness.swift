// MARK: - Harness
//
// Apple's 256-iteration MINIMUM-interval methodology, mirrored
// verbatim from
// /Users/coen/Developer/swiftlang/swift-foundation/
//   Tests/NewCodableBenchmarks/CodableRevolutionBenchmarks.swift
//
// Why min and not mean: minimum of N is much less noisy than the
// mean for short-duration measurements — outliers from GC, OS
// preemption, or background load only ever inflate measurements,
// never deflate them, so the floor is the truest measure of the
// codec's actual cost.

import Foundation
import NewCodable

enum Harness {
    static let iterations = 256

    /// 256-iter min-interval measurement. Mirrors Apple's inline loop
    /// at CodableRevolutionBenchmarks.swift:~100.
    static func measure(_ body: () throws -> Void) rethrows -> TimeInterval {
        var minInterval: TimeInterval?
        for _ in 0..<iterations {
            let start = Date.now
            try body()
            let end = Date.now
            let interval = end.timeIntervalSince(start)
            minInterval = min(minInterval ?? interval, interval)
        }
        return minInterval!
    }

    /// MB/s throughput. Mirrors Apple's `throughput(dur:bytes:)` at
    /// CodableRevolutionBenchmarks.swift:~70 (Apple rounds to UInt64;
    /// we keep Double precision).
    static func throughput(seconds: TimeInterval, bytes: Int) -> Double {
        let microseconds = seconds * 1_000_000
        return Double(bytes) / microseconds
    }

    static func report(label: String, seconds: TimeInterval, bytes: Int) {
        let mbps = throughput(seconds: seconds, bytes: bytes)
        let ms = seconds * 1000
        print(String(format: "  %-32s %9.4f ms   %7.1f MB/s", (label as NSString).utf8String!, ms, mbps))
    }
}

@inline(never)
func blackHole<T: ~Copyable & ~Escapable>(_ value: consuming T) {}

// MARK: - Path-routing protocols
//
// NewJSONDecoder exposes BOTH `decode<T: JSONDecodable>` and
// `decode<T: CommonDecodable>` overloads. Without an explicit
// constraint, Swift can't reliably pick a single overload when a
// type conforms to both. Apple's harness routes through these
// existentials to force the path
// (CodableRevolutionBenchmarks.swift:~50-65).

protocol CommonTopLevelEncoder: ~Copyable {
    func encode(_ value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data
}
protocol JSONTopLevelEncoder: ~Copyable {
    func encode(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> Data
}
protocol CommonTopLevelDecoder: ~Copyable {
    func decode<T: CommonDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T
}
protocol JSONTopLevelDecoder: ~Copyable {
    func decode<T: JSONDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T
}

extension NewJSONEncoder: CommonTopLevelEncoder {}
extension NewJSONEncoder: JSONTopLevelEncoder {}
extension NewJSONDecoder: CommonTopLevelDecoder {}
extension NewJSONDecoder: JSONTopLevelDecoder {}
