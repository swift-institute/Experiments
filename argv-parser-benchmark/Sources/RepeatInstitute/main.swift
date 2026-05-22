//
//  main.swift — institute Parser.Protocol variant
//
//  Drives the institute leaf parser with CommandLine.arguments[1...], then
//  prints the same lines RepeatApple would print, so the two executables
//  are user-visibly equivalent for the same argv.
//
//  Foundation is deliberately NOT imported here — pulling Foundation into
//  the institute target would confound the binary-size comparison. We use
//  Darwin's write(2) for stderr.
//

internal import Parser_Primitives
internal import Input_Primitives

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private func emitError(_ s: String) {
    let line = s + "\n"
    line.withCString { ptr in
        _ = write(2, ptr, strlen(ptr))
    }
}

let argv = Swift.Array(CommandLine.arguments.dropFirst())

var input = ArgvInput(argv: argv)
let parser = RepeatParser()

do {
    let result = try parser.parse(&input)
    let repeatCount = result.count
    for i in 1...repeatCount {
        if result.includeCounter {
            print("\(i): \(result.phrase)")
        } else {
            print(result.phrase)
        }
    }
} catch {
    emitError("error: \(error)")
    exit(1)
}
