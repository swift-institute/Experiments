// MARK: - Literal vs Throwing Init Disambiguation
// Purpose: Verify whether `try` disambiguates between ExpressibleByStringLiteral
//          and a throwing init(_ string:) on the same type
// Hypothesis: `try Type("literal")` should select the throwing init, but Swift
//             may select the literal conformance instead — even under `try`
//
// Toolchain: swift-6.2-RELEASE
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — `try` does NOT disambiguate. Swift unconditionally selects
//         ExpressibleByStringLiteral over throwing init(_ string:) for string
//         literals, even inside `try` expressions. @_disfavoredOverload has no
//         effect. The compiler emits "no calls to throwing functions occur within
//         'try' expression" — overload resolution completes before try-context
//         is considered. Only labeled inits (init(validating:)) disambiguate.
// Date: 2026-03-19

// MARK: - Shared Error

enum ValidationError: Error, CustomStringConvertible {
    case empty
    case invalid(String)
    var description: String {
        switch self {
        case .empty: "empty string"
        case .invalid(let s): "invalid: \(s)"
        }
    }
}

// MARK: - Variant 1: Both init(_ string:) throws AND ExpressibleByStringLiteral
// Hypothesis: `try V1("valid")` selects the literal init, NOT the throwing init
// Result: CONFIRMED — all four call sites select "literal". `try V1("")` does NOT
//         throw; it silently succeeds via the literal init. Compiler warns:
//         "no calls to throwing functions occur within 'try' expression"

struct V1: ExpressibleByStringLiteral {
    let value: String
    let source: String

    init(_ string: String) throws(ValidationError) {
        if string.isEmpty { throw .empty }
        self.value = string
        self.source = "throwing"
    }

    init(stringLiteral value: String) {
        self.value = value
        self.source = "literal"
    }
}

// MARK: - Variant 2: @_disfavoredOverload on literal conformance
// Hypothesis: @_disfavoredOverload on stringLiteral might make `try` select throwing init
// Result: CONFIRMED (disfavor has no effect) — all four call sites still select "literal".
//         @_disfavoredOverload does not change protocol conformance resolution for literals.

struct V2: ExpressibleByStringLiteral {
    let value: String
    let source: String

    init(_ string: String) throws(ValidationError) {
        if string.isEmpty { throw .empty }
        self.value = string
        self.source = "throwing"
    }

    @_disfavoredOverload
    init(stringLiteral value: String) {
        self.value = value
        self.source = "literal"
    }
}

// MARK: - Variant 3: Renamed to init(validating:) — no ambiguity expected
// Hypothesis: `try V3(validating: "str")` selects throwing; `V3("str")` selects literal
// Result: CONFIRMED — label fully disambiguates. `try V3(validating: "hello")` → "throwing",
//         `try V3(validating: "")` → THREW. `V3("hello")` → "literal".

struct V3: ExpressibleByStringLiteral {
    let value: String
    let source: String

    init(validating string: String) throws(ValidationError) {
        if string.isEmpty { throw .empty }
        self.value = string
        self.source = "throwing"
    }

    init(stringLiteral value: String) {
        self.value = value
        self.source = "literal"
    }
}

// MARK: - Variant 4: No literal conformance, only throwing init
// Hypothesis: `try V4("str")` always selects the throwing init (baseline)
// Result: CONFIRMED — `try V4("hello")` → "throwing", `try V4("")` → THREW.

struct V4 {
    let value: String
    let source: String

    init(_ string: String) throws(ValidationError) {
        if string.isEmpty { throw .empty }
        self.value = string
        self.source = "throwing"
    }
}

// MARK: - Variant 5: Type annotation context — does `let x: V1 = "str"` use literal?
// Hypothesis: Type-annotated assignment always uses literal conformance
// Result: CONFIRMED — `let v1: V1 = "hello"` → "literal" (tested in V1 section above)

// MARK: - Variant 6: try with empty string — does it throw or crash?
// Hypothesis: `try V1("")` will use literal init (no crash, no throw — just succeeds)
//             because literal init doesn't validate
// Result: CONFIRMED — `try V1("")` selects literal init, returns "literal" source.
//         The throwing init's empty-string validation is completely bypassed.

// MARK: - Execution

func test(_ label: String, _ body: () throws -> String) {
    do {
        let result = try body()
        print("  \(label): \(result)")
    } catch {
        print("  \(label): THREW \(error)")
    }
}

print("=== Variant 1: Both init(_:) throws AND ExpressibleByStringLiteral ===")
test("try V1(\"hello\")") { try V1("hello").source }
test("try V1(\"\")     ") { try V1("").source }
test("V1(\"hello\") no try") { V1("hello").source }          // non-try context
let v1assigned: V1 = "hello"
print("  let v1: V1 = \"hello\" → source: \(v1assigned.source)")

print()
print("=== Variant 2: @_disfavoredOverload on stringLiteral ===")
test("try V2(\"hello\")") { try V2("hello").source }
test("try V2(\"\")     ") { try V2("").source }
test("V2(\"hello\") no try") { V2("hello").source }
let v2assigned: V2 = "hello"
print("  let v2: V2 = \"hello\" → source: \(v2assigned.source)")

print()
print("=== Variant 3: Renamed to init(validating:) ===")
test("try V3(validating: \"hello\")") { try V3(validating: "hello").source }
test("try V3(validating: \"\")     ") { try V3(validating: "").source }
test("V3(\"hello\") literal        ") { V3("hello").source }
let v3assigned: V3 = "hello"
print("  let v3: V3 = \"hello\" → source: \(v3assigned.source)")

print()
print("=== Variant 4: No literal conformance (baseline) ===")
test("try V4(\"hello\")") { try V4("hello").source }
test("try V4(\"\")     ") { try V4("").source }

print()
print("=== Summary ===")
print("Key question: does `try` disambiguate in favor of throwing init?")
print("If V1/V2 show 'throwing' for try-context, try disambiguates.")
print("If V1/V2 show 'literal' for try-context, try does NOT disambiguate.")
