//
//  main.swift — BenchDriver
//
//  Times argv-parsing latency for both implementations in a single process.
//  Both parsers take the same logical input:
//      ["--count", "1000", "--include-counter", "hello"]
//
//  Runs N iterations per parser, reports mean and min in nanoseconds.
//  Warms each parser once before timing.
//

import ArgumentParser

internal import Parser_Primitives
internal import Input_Primitives
internal import Array_Dynamic_Primitives
internal import Array_Primitives_Core

// MARK: - Apple parser shape (mirrors Examples/repeat/Repeat.swift)

struct RepeatApple: ParsableCommand {
    @Option(help: "The number of times to repeat 'phrase'.")
    var count: Int? = nil

    @Flag(help: "Include a counter with each repetition.")
    var includeCounter = false

    @Argument(help: "The phrase to repeat.")
    var phrase: String

    mutating func run() throws {}
}

// MARK: - Institute parser (verbatim leaf shape from spike)

struct InstituteRepeat: Equatable, Sendable {
    let phrase: String
    let count: Int
    let includeCounter: Bool
}

enum InstituteArgvParseError: Error {
    case endOfInput
    case missingOptionValue(name: String)
    case invalidOptionValue(name: String, value: String)
    case missingPositional
    case unexpectedExtraPositional(found: String)
}

typealias InstituteArgvInput = Input.Slice<Array<String>.Indexed<String>>

extension Input.Slice where Base == Array<String>.Indexed<String> {
    init(argv: Swift.Array<String>) {
        var institute: Array<String> = []
        for element in argv {
            institute.append(element)
        }
        self.init(Array<String>.Indexed<String>(institute))
    }
}

struct InstituteRepeatParser: Parser.`Protocol` {
    typealias Input = InstituteArgvInput
    typealias Output = InstituteRepeat
    typealias Failure = InstituteArgvParseError
    typealias Body = Never

    func parse(_ input: inout Input) throws(Failure) -> InstituteRepeat {
        var phrase: String? = nil
        var count: Int = 2
        var includeCounter: Bool = false

        while !input.isEmpty {
            let checkpoint = input.checkpoint

            let element: String
            do {
                element = try input.advance()
            } catch {
                throw .endOfInput
            }

            switch element {
            case "--count":
                guard !input.isEmpty else {
                    input.restore.to(__unchecked: (), checkpoint)
                    throw .missingOptionValue(name: "--count")
                }
                let raw: String
                do {
                    raw = try input.advance()
                } catch {
                    throw .missingOptionValue(name: "--count")
                }
                guard let parsed = Int(raw) else {
                    throw .invalidOptionValue(name: "--count", value: raw)
                }
                count = parsed
            case "--include-counter":
                includeCounter = true
            default:
                if phrase == nil {
                    phrase = element
                } else {
                    throw .unexpectedExtraPositional(found: element)
                }
            }
        }

        guard let phrase else { throw .missingPositional }
        return InstituteRepeat(phrase: phrase, count: count, includeCounter: includeCounter)
    }
}

// MARK: - Timing

@inline(never)
func timeNanos(_ block: () -> Void) -> UInt64 {
    let clock = ContinuousClock()
    let start = clock.now
    block()
    let end = clock.now
    let duration = end - start
    let components = duration.components
    return UInt64(components.seconds) &* 1_000_000_000 &+ UInt64(components.attoseconds / 1_000_000_000)
}

// MARK: - Benchmark loop

let argv: [String] = ["--count", "1000", "--include-counter", "hello"]
let iterations = 100_000

// Sink to defeat dead-code elimination.
var sinkApple: Int = 0
var sinkInstitute: Int = 0

// Warm: one execution per parser.
_ = try? RepeatApple.parse(argv)
do {
    var input = InstituteArgvInput(argv: argv)
    _ = try InstituteRepeatParser().parse(&input)
}

// ---- Apple ----
var appleTotal: UInt64 = 0
var appleMin: UInt64 = .max
for _ in 0..<iterations {
    let t = timeNanos {
        if let parsed = try? RepeatApple.parse(argv) {
            sinkApple &+= parsed.count ?? 0
        }
    }
    appleTotal &+= t
    if t < appleMin { appleMin = t }
}

// ---- Institute ----
var instTotal: UInt64 = 0
var instMin: UInt64 = .max
for _ in 0..<iterations {
    let t = timeNanos {
        var input = InstituteArgvInput(argv: argv)
        if let parsed = try? InstituteRepeatParser().parse(&input) {
            sinkInstitute &+= parsed.count
        }
    }
    instTotal &+= t
    if t < instMin { instMin = t }
}

// ---- Report ----
// Manual float formatting (avoid Foundation to keep dependencies clean).
@inline(never)
func format(_ value: Double, decimals: Int) -> String {
    if value.isNaN { return "NaN" }
    var multiplier: Double = 1
    for _ in 0..<decimals { multiplier *= 10 }
    let scaled = (value * multiplier).rounded()
    let asInt = Int64(scaled)
    let sign = asInt < 0 ? "-" : ""
    let absVal = asInt < 0 ? -asInt : asInt
    let whole = absVal / Int64(multiplier)
    let frac = absVal % Int64(multiplier)
    var fracStr = String(frac)
    while fracStr.count < decimals { fracStr = "0" + fracStr }
    if decimals == 0 { return "\(sign)\(whole)" }
    return "\(sign)\(whole).\(fracStr)"
}

let appleMean = Double(appleTotal) / Double(iterations)
let instMean = Double(instTotal) / Double(iterations)

print("Iterations: \(iterations)")
print("Input: \(argv)")
print("")
print("Apple swift-argument-parser:")
print("  mean: \(format(appleMean, decimals: 1)) ns/parse")
print("  min:  \(appleMin) ns/parse")
print("")
print("Institute Parser.Protocol (leaf):")
print("  mean: \(format(instMean, decimals: 1)) ns/parse")
print("  min:  \(instMin) ns/parse")
print("")
print("Ratio (institute / apple):")
print("  mean: \(format(instMean / appleMean, decimals: 3))x")
print("  min:  \(format(Double(instMin) / Double(appleMin), decimals: 3))x")
print("")
print("(sink: \(sinkApple), \(sinkInstitute))")
