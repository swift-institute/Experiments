// ===----------------------------------------------------------------------===//
//
// Syntax Showcase — Snapshot & Performance Testing
//
// Demonstrates the intended call-site syntax for swift-testing's
// snapshot assertions and performance traits.
//
// ===----------------------------------------------------------------------===//

import Testing
import Showcase

// MARK: - Test Scaffolding via #Tests Macro

// The #Tests macro generates a standardized test structure:
//
//   @Suite enum Test {
//       @Suite(.exclusive(group: "Showcase.User")) struct Unit {}
//       @Suite(.exclusive(group: "Showcase.User")) struct EdgeCase {}
//       @Suite(.exclusive(group: "Showcase.User")) struct Integration {}
//       @Suite(.exclusive, .serialized) struct Performance {}
//       @Suite(.serialized, .snapshots(configuration: ...)) struct Snapshot {}
//   }

extension Showcase.User {
    #Tests(snapshots: .init(recording: .missing))
}

// MARK: - Unit Tests

extension Showcase.User.Test.Unit {
    @Test
    func creates_with_default_role() {
        let user = Showcase.User(name: "Alice", email: "alice@example.com")

        #expect(user.role == .member)
    }

    @Test
    func creates_with_explicit_role() {
        let user = Showcase.User(name: "Bob", email: "bob@example.com", role: .admin)

        #expect(user.role == .admin)
        #expect(user.name == "Bob")
    }
}

// MARK: - Edge Case Tests

extension Showcase.User.Test.EdgeCase {
    @Test
    func handles_empty_name() {
        let user = Showcase.User(name: "", email: "anon@example.com")

        #expect(user.name.isEmpty)
    }
}

// MARK: - Performance Tests (via .timed trait)

extension Showcase.User.Test.Performance {

    // Basic: measure with defaults (10 iterations, median metric)
    @Test(.timed())
    func creates_users_quickly() {
        for _ in 0..<1_000 {
            _ = Showcase.User(name: "Alice", email: "alice@example.com")
        }
    }

    // With warmup: 5 warmup runs are excluded from measurement
    @Test(.timed(iterations: 50, warmup: 5))
    func description_generation_throughput() {
        let user = Showcase.User(name: "Alice", email: "alice@example.com", role: .admin)
        for _ in 0..<10_000 {
            _ = user.description
        }
    }

    // With threshold: fail if median exceeds budget
    @Test(.timed(iterations: 20, threshold: .milliseconds(100), metric: .median))
    func stays_within_budget() {
        for _ in 0..<10_000 {
            _ = Showcase.User(name: "Test", email: "test@example.com").description
        }
    }

    // Combined with tags for CI filtering
    @Test(.timed(iterations: 100, warmup: 10), .tag("benchmark"))
    func high_fidelity_measurement() {
        for _ in 0..<50_000 {
            _ = Showcase.User(name: "Bench", email: "bench@example.com")
        }
    }
}

// MARK: - Snapshot Tests (via #snapshot macro)

extension Showcase.User.Test.Snapshot {

    // Basic: snapshot a string value using line-by-line diffing
    @Test
    func user_description_format() {
        let user = Showcase.User(name: "Alice", email: "alice@example.com", role: .admin)

        snapshot(user.description, as: .lines)
    }

    // Named snapshots: multiple assertions in one test
    @Test
    func role_descriptions() {
        let admin = Showcase.User(name: "Alice", email: "a@example.com", role: .admin)
        let member = Showcase.User(name: "Bob", email: "b@example.com", role: .member)
        let guest = Showcase.User(name: "Carol", email: "c@example.com", role: .guest)

        snapshot(admin.description, as: .lines, named: "admin")
        snapshot(member.description, as: .lines, named: "member")
        snapshot(guest.description, as: .lines, named: "guest")
    }

    // Inline snapshots: expected value embedded directly in source
    // Uses Point-Free-compatible assertInlineSnapshot(of:, as:) syntax
    @Test
    func user_inline_description() {
        let user = Showcase.User(name: "Alice", email: "alice@example.com", role: .admin)

        assertInlineSnapshot(of: user.description, as: .lines) {
            """
            User: Alice
            Email: alice@example.com
            Role: admin
            """
        }
    }

    // Custom strategy via pullback: snapshot a User directly
    @Test
    func user_profile_card() {
        let strategy = Test.Snapshot.Strategy<String, String>.lines
            .pullback { (user: Showcase.User) in
                """
                ┌─────────────────────────────┐
                │ \(user.name.padding(toLength: 27, withPad: " ", startingAt: 0)) │
                │ \(user.email.padding(toLength: 27, withPad: " ", startingAt: 0)) │
                │ Role: \(user.role.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)) │
                └─────────────────────────────┘
                """
            }

        let user = Showcase.User(name: "Alice", email: "alice@example.com", role: .admin)
        snapshot(user, as: strategy)
    }
}
