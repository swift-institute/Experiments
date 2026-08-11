// ===----------------------------------------------------------------------===//
//
// Syntax Showcase — Document Snapshot & Performance Tests
//
// Demonstrates richer snapshot patterns: text strategies, named
// snapshots for state transitions, and performance thresholds.
//
// ===----------------------------------------------------------------------===//

import Testing
import Showcase

// Generate test scaffolding with snapshot recording in "all" mode
// (always record/overwrite — useful during active development)

extension Showcase.Document {
    #Tests(snapshots: .init(recording: .all))
}

// MARK: - Unit Tests

extension Showcase.Document.Test.Unit {
    @Test
    func renders_title() {
        let doc = Showcase.Document(title: "Hello")

        #expect(doc.render().hasPrefix("# Hello"))
    }

    @Test
    func renders_sections_in_order() {
        let doc = Showcase.Document(
            title: "Guide",
            sections: [
                .init(heading: "First", body: "One"),
                .init(heading: "Second", body: "Two"),
            ]
        )
        let rendered = doc.render()

        #expect(rendered.contains("## First"))
        #expect(rendered.contains("## Second"))
    }

    @Test
    func empty_document_renders_title_only() {
        let doc = Showcase.Document(title: "Empty")

        #expect(doc.render() == "# Empty\n")
    }
}

// MARK: - Performance Tests

extension Showcase.Document.Test.Performance {

    // Measure rendering throughput with a threshold
    @Test(.timed(iterations: 30, warmup: 3, threshold: .milliseconds(50)))
    func renders_large_document_within_budget() {
        let sections = (0..<100).map { i in
            Showcase.Document.Section(heading: "Section \(i)", body: "Content for section \(i).")
        }
        let doc = Showcase.Document(title: "Large", sections: sections)

        for _ in 0..<100 {
            _ = doc.render()
        }
    }

    // Simple timing without threshold — just measure
    @Test(.timed(iterations: 10))
    func example_document_creation() {
        for _ in 0..<10_000 {
            _ = Showcase.Document.example
        }
    }
}

// MARK: - Snapshot Tests

extension Showcase.Document.Test.Snapshot {

    // Snapshot the full rendered output
    @Test
    func example_document_rendering() {
        let doc = Showcase.Document.example

        snapshot(doc.render(), as: .lines)
    }

    // Full text comparison (not line-by-line)
    @Test
    func example_document_text() {
        let doc = Showcase.Document.example

        snapshot(doc.render(), as: .text)
    }

    // Named snapshots to track a document through mutations
    @Test
    func document_evolution() {
        var doc = Showcase.Document(title: "Draft")

        snapshot(doc.render(), as: .lines, named: "empty")

        doc.sections.append(.init(heading: "Introduction", body: "Hello, world."))
        snapshot(doc.render(), as: .lines, named: "with_intro")

        doc.sections.append(.init(heading: "Conclusion", body: "Goodbye."))
        snapshot(doc.render(), as: .lines, named: "with_conclusion")
    }

    // Inline snapshot: expected value embedded in source
    // Uses Point-Free-compatible assertInlineSnapshot(of:, as:) syntax
    @Test
    func example_document_inline() {
        let doc = Showcase.Document.example

        assertInlineSnapshot(of: doc.render(), as: .lines) {
            """
            # Getting Started

            ## Installation
            Add the package dependency.

            ## Usage
            Import the module and call the API.

            """
        }
    }

    // Pullback: snapshot a Document directly as rendered markdown
    @Test
    func rendered_via_pullback() {
        let strategy = Test.Snapshot.Strategy<String, String>.lines
            .pullback { (doc: Showcase.Document) in doc.render() }

        snapshot(Showcase.Document.example, as: strategy)
    }
}
