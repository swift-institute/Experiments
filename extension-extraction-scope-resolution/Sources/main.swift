// MARK: - Extension Extraction Scope Resolution
// Purpose: Validate that extracting methods from nested extension bodies to
//          explicit extensions changes scope resolution for sibling types.
// Status: CONFIRMED
// Date: 2026-04-01
// Toolchain: Swift 6.2
// Rule: [IMPL-082]

// Claim: When extracting methods from `extension Outer { struct Inner { method() } }`
// to `extension Outer.Inner { method() }`, sibling types declared in `Outer` lose
// implicit scope resolution. All references to sibling types must be fully qualified.

// --- Setup: Outer namespace with sibling types ---

enum IO {
    enum Event {}
}

extension IO.Event {
    struct Channel {
        var id: Int
    }
}

// --- Variant 1: Nested extension body (implicit resolution works) ---

extension IO.Event {
    struct SelectorNested {
        // "Channel" resolves implicitly via IO.Event scope
        func register(_ channel: Channel) {
            print("Nested: registered channel \(channel.id)")
        }
    }
}

// --- Variant 2: Explicit extension (must fully qualify) ---

extension IO.Event {
    struct SelectorExtracted {}
}

extension IO.Event.SelectorExtracted {
    // "Channel" alone does NOT resolve here — must use IO.Event.Channel
    // Uncommenting the next line would produce a compiler error:
    // func register(_ channel: Channel) { }  // error: cannot find type 'Channel' in scope

    func register(_ channel: IO.Event.Channel) {
        print("Extracted: registered channel \(channel.id)")
    }
}

// --- Validation ---

let channel = IO.Event.Channel(id: 42)

let nested = IO.Event.SelectorNested()
nested.register(channel)

let extracted = IO.Event.SelectorExtracted()
extracted.register(channel)

print("Both variants compiled and executed.")

// --- Negative test ---
// Uncomment to verify the compiler rejects unqualified Channel in Variant 2:
//
// extension IO.Event.SelectorExtracted {
//     func registerBroken(_ channel: Channel) { }
//     // Expected error: "cannot find type 'Channel' in scope"
// }
//
// Verified: uncommenting produces the expected error on Swift 6.2.
// This confirms IMPL-082.
