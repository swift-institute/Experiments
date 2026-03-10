// MARK: - Throws Overloading Limitation
// Purpose: throws modifier cannot be used for overloading
// Status: CONFIRMED -> SE-PITCH (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — ambiguous use of 'parse' (2026-03-10)

enum ParseError: Error { case invalid }

struct Parser {
    // MARK: - Variant 1: Attempt throws-based overloading
    // Can we have both throwing and non-throwing versions?

    func parse(_ input: String) -> Int? {
        Int(input)
    }

    // This should be a different overload based on throws, but Swift
    // may not allow it or may not resolve correctly
    func parse(_ input: String) throws(ParseError) -> Int {
        guard let value = Int(input) else { throw .invalid }
        return value
    }
}

let p = Parser()

// Non-throwing path
if let value = p.parse("42") {
    print("Non-throwing: \(value)")
}

// Throwing path
do {
    let value = try p.parse("42")
    print("Throwing: \(value)")
} catch {
    print("Error: \(error)")
}

// Ambiguity test — which overload does the compiler pick?
// let ambiguous = p.parse("42")  // May be ambiguous

print("Throws overloading test: BUILD SUCCEEDED")
