// MARK: - ~Copyable Throwing Init Patterns
// Purpose: Which init patterns does Swift 6.2 accept for ~Copyable structs
//          with ~Copyable stored properties that need throwing initialization?
// Hypothesis: `self = try factory()` should work since self is untouched before assignment
//
// Toolchain: Swift 6.2
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 5 variants compile and run correctly.
//   V1 (throw before init): compiles — compiler accepts partial init + throw
//   V2 (self = try factory): compiles — delegation works
//   V3 (throw after full init): compiles — deinit runs cleanup
//   V4 (Optional ~Copyable): compiles — Optional<~Copyable> works
//   V5 (locals first): compiles — cleanest pattern
//   The "conditional initialization" error in Memory.Map is context-specific,
//   not a fundamental ~Copyable limitation.
// Date: 2026-03-30

// Shared types

enum SimpleError: Error { case failed }

struct Resource: ~Copyable, Sendable {
    let value: Int
    init(_ v: Int) { self.value = v }
    deinit { print("  Resource(\(value)) deinit") }
}

// ============================================================================
// MARK: - Variant 1: Direct init — throw before all properties set
// Hypothesis: Compiler rejects throw before ~Copyable stored property is initialized
// ============================================================================

struct V1: ~Copyable {
    let name: String
    let resource: Resource

    init(name: String, shouldFail: Bool) throws(SimpleError) {
        self.name = name
        if shouldFail { throw .failed }  // resource not yet initialized
        self.resource = Resource(1)
    }
}

// ============================================================================
// MARK: - Variant 2: self = try factory()
// Hypothesis: Delegating to a throwing factory via self = try ... works
// ============================================================================

struct V2: ~Copyable {
    let name: String
    let resource: Resource

    init(name: String, shouldFail: Bool) throws(SimpleError) {
        self = try Self._create(name: name, shouldFail: shouldFail)
    }

    private static func _create(name: String, shouldFail: Bool) throws(SimpleError) -> V2 {
        if shouldFail { throw .failed }
        return V2(unchecked: name, resource: Resource(2))
    }

    private init(unchecked name: String, resource: consuming Resource) {
        self.name = name
        self.resource = resource
    }
}

// ============================================================================
// MARK: - Variant 3: All properties initialized first, then throw
// Hypothesis: Throwing AFTER full initialization works (deinit handles cleanup)
// ============================================================================

struct V3: ~Copyable {
    let name: String
    let resource: Resource
    var token: Resource?

    init(name: String, shouldFail: Bool) throws(SimpleError) {
        // Phase 1: initialize all stored properties
        self.name = name
        self.resource = Resource(3)
        self.token = nil

        // Phase 2: throw after full initialization — deinit cleans up
        if shouldFail { throw .failed }
        self.token = Resource(30)
    }

    deinit {
        print("  V3 deinit (token: \(token != nil ? "set" : "nil"))")
    }
}

// ============================================================================
// MARK: - Variant 4: Optional ~Copyable stored property, throw before init
// Hypothesis: Even Optional<~Copyable> must be initialized before throwing
// ============================================================================

struct V4: ~Copyable {
    var resource: Resource?

    init(shouldFail: Bool) throws(SimpleError) {
        if shouldFail { throw .failed }  // resource? not yet initialized
        self.resource = Resource(4)
    }
}

// ============================================================================
// MARK: - Variant 5: Throwing computation into local, then assign all at once
// Hypothesis: If all throws happen before ANY stored property assignment, it works
// ============================================================================

struct V5: ~Copyable {
    let name: String
    let resource: Resource

    init(name: String, shouldFail: Bool) throws(SimpleError) {
        // All throwing code into locals first
        if shouldFail { throw .failed }
        let r = Resource(5)

        // Then assign everything (no throws between assignments)
        self.name = name
        self.resource = r
    }
}

// ============================================================================
// MARK: - Runner
// ============================================================================

func test<T: ~Copyable>(_ label: String, _ body: () throws -> T) {
    print("\(label):")
    do {
        let _ = try body()
        print("  OK")
    } catch {
        print("  threw: \(error)")
    }
}

print("=== ~Copyable Throwing Init Experiments ===\n")

test("V1 success") { try V1(name: "a", shouldFail: false) }
test("V1 failure") { try V1(name: "a", shouldFail: true) }
print()
test("V2 success") { try V2(name: "b", shouldFail: false) }
test("V2 failure") { try V2(name: "b", shouldFail: true) }
print()
test("V3 success") { try V3(name: "c", shouldFail: false) }
test("V3 failure") { try V3(name: "c", shouldFail: true) }
print()
test("V4 success") { try V4(shouldFail: false) }
test("V4 failure") { try V4(shouldFail: true) }
print()
test("V5 success") { try V5(name: "e", shouldFail: false) }
test("V5 failure") { try V5(name: "e", shouldFail: true) }

testV6()
testV7()
testV7Bisect()
testV7Fix()
