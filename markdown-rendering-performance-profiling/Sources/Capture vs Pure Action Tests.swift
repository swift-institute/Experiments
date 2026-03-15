//
//  Capture vs Pure Action Tests.swift
//  markdown-rendering-performance-profiling
//
//  Purpose: Compare capture-based defaults against pure action closures
//  Hypothesis: Pure action closures eliminate _render recursion → 5-10x speedup
//  Toolchain: Swift 6.2
//  Platform: macOS 26
//  Date: 2026-03-15

@_spi(DynamicHTML) import HTML_Renderable
import Markdown_HTML_Rendering
import Rendering_Primitives
import Testing

// MARK: - Pure Action Defaults

private typealias Action = Rendering_Primitives.Rendering.Action
private typealias MR = Markdown_HTML_Rendering.Markdown.Rendering

/// Pure action paragraph: replaces capture { Paragraph { Replay } .css.lineHeight.padding.margin }
private let pureParagraph = MR.Paragraph(render: { input in
    var actions: [Action] = []
    actions.reserveCapacity(input.children.count + 8)
    actions.append(.push(.block(role: .paragraph, style: .empty)))
    actions.append(.style(register: "line-height: 1.5", atRule: nil, selector: nil, pseudo: nil))
    actions.append(.style(register: "padding: 0", atRule: nil, selector: nil, pseudo: nil))
    actions.append(.style(register: "margin: 0", atRule: nil, selector: nil, pseudo: nil))
    actions.append(contentsOf: input.children)
    actions.append(.pop(.block))
    return actions
})

/// Pure action inline code: replaces capture { Code { HTML.Text } }
private let pureInlineCode = MR.InlineCode(render: { input in
    [
        .push(.inline(role: .code, style: .empty)),
        .text(input.code),
        .pop(.inline),
    ]
})

/// Pure action list item: replaces capture { ListItem { VStack { Replay } } }
private let pureListItem = MR.ListItem(render: { input in
    var actions: [Action] = []
    actions.reserveCapacity(input.children.count + 10)
    actions.append(.push(.item))
    // VStack(spacing: 0.5rem) equivalent
    actions.append(.push(.block(role: nil, style: .empty)))
    actions.append(.style(register: "align-items: stretch", atRule: nil, selector: nil, pseudo: nil))
    actions.append(.style(register: "display: flex", atRule: nil, selector: nil, pseudo: nil))
    actions.append(.style(register: "flex-direction: column", atRule: nil, selector: nil, pseudo: nil))
    actions.append(.style(register: "row-gap: 0.5rem", atRule: nil, selector: nil, pseudo: nil))
    actions.append(contentsOf: input.children)
    actions.append(.pop(.block))
    actions.append(.pop(.item))
    return actions
})

private let captureRendering = MR.default

private let pureRendering = MR(
    paragraph: pureParagraph,
    inlineCode: pureInlineCode,
    listItem: pureListItem
)

// MARK: - Fixtures

private let bookChapter: String = generateBook(sections: 100)
private let largeBook: String = generateBook(sections: 500)

private func generateBook(sections: Int) -> String {
    var parts: [String] = ["# Chapter: The Architecture of Rendering"]
    for i in 1...sections {
        parts.append("""
            ## Section \(i): Design Considerations

            This section explores the **design considerations** for section \(i).
            We examine *performance*, `correctness`, and maintainability in depth.
            For more details, see the [documentation](https://example.com/section/\(i)).

            The key insight from this section is that rendering pipelines benefit
            from separating operation production from interpretation.

            ### Subsection \(i).1: Implementation

            ```swift
            func render(section: Int) {
                context.push.block(role: .heading(level: 2), style: .empty)
                context.text("Section \\(section)")
                context.pop.block()
            }
            ```

            ### Subsection \(i).2: Analysis

            | Metric | Value | Status |
            |--------|-------|--------|
            | Throughput | \(i * 10) ops/s | Good |
            | Latency | \(i)ms | Acceptable |

            1. The action-based pipeline scales linearly
            2. Memory usage is proportional to document size
            3. Stack depth is bounded regardless of nesting

            - First consideration for section \(i)
            - Second consideration with **bold emphasis**
            - Third consideration with `inline code`

            > **Note**: This section demonstrates rendering pipeline stability.

            ---
            """)
    }
    return parts.joined(separator: "\n\n")
}

// MARK: - Suite

@Suite(.serialized)
struct `Capture vs Pure Action` {

    // MARK: - Full Pipeline Comparison (100 sections)

    @Test(.timed(iterations: 20, warmup: 2))
    func `full pipeline - all capture - 100 sections`() {
        let state = Ownership.Mutable(HTML.Context())
        var context = Rendering.Context.html(state: state)
        let view = Markdown_HTML_Rendering.Markdown(rendering: captureRendering) { bookChapter }
        Markdown_HTML_Rendering.Markdown._render(view, context: &context)
    }

    @Test(.timed(iterations: 20, warmup: 2))
    func `full pipeline - 3 pure + 15 capture - 100 sections`() {
        let state = Ownership.Mutable(HTML.Context())
        var context = Rendering.Context.html(state: state)
        let view = Markdown_HTML_Rendering.Markdown(rendering: pureRendering) { bookChapter }
        Markdown_HTML_Rendering.Markdown._render(view, context: &context)
    }

    // MARK: - Full Pipeline Comparison (500 sections)

    @Test(.timed(iterations: 5, warmup: 1))
    func `full pipeline - all capture - 500 sections`() {
        let state = Ownership.Mutable(HTML.Context())
        var context = Rendering.Context.html(state: state)
        let view = Markdown_HTML_Rendering.Markdown(rendering: captureRendering) { largeBook }
        Markdown_HTML_Rendering.Markdown._render(view, context: &context)
    }

    @Test(.timed(iterations: 5, warmup: 1))
    func `full pipeline - 3 pure + 15 capture - 500 sections`() {
        let state = Ownership.Mutable(HTML.Context())
        var context = Rendering.Context.html(state: state)
        let view = Markdown_HTML_Rendering.Markdown(rendering: pureRendering) { largeBook }
        Markdown_HTML_Rendering.Markdown._render(view, context: &context)
    }

    // MARK: - Per-Element Isolation: Paragraph

    @Test(.timed(iterations: 1000, warmup: 50))
    func `paragraph - capture`() {
        let _ = MR.Paragraph.default.render(sampleParagraphInput)
    }

    @Test(.timed(iterations: 1000, warmup: 50))
    func `paragraph - pure action`() {
        let _ = pureParagraph.render(sampleParagraphInput)
    }

    // MARK: - Per-Element Isolation: InlineCode

    @Test(.timed(iterations: 1000, warmup: 50))
    func `inlineCode - capture`() {
        let _ = MR.InlineCode.default.render(sampleInlineCodeInput)
    }

    @Test(.timed(iterations: 1000, warmup: 50))
    func `inlineCode - pure action`() {
        let _ = pureInlineCode.render(sampleInlineCodeInput)
    }

    // MARK: - Per-Element Isolation: ListItem

    @Test(.timed(iterations: 1000, warmup: 50))
    func `listItem - capture`() {
        let _ = MR.ListItem.default.render(sampleListItemInput)
    }

    @Test(.timed(iterations: 1000, warmup: 50))
    func `listItem - pure action`() {
        let _ = pureListItem.render(sampleListItemInput)
    }

    // MARK: - Baselines

    @Test(.timed(iterations: 1000, warmup: 50))
    func `emphasis - capture baseline`() {
        let _ = MR.Emphasis.default.render(sampleEmphasisInput)
    }

    @Test(.timed(iterations: 1000, warmup: 50))
    func `text - already pure baseline`() {
        let _ = MR.Text.default.render(sampleTextInput)
    }
}

// MARK: - Sample Inputs

private let sampleChildren: [Action] = [
    .text("Hello world with "),
    .push(.inline(role: .strong, style: .empty)),
    .text("bold"),
    .pop(.inline),
    .text(" text."),
]

private let sampleParagraphInput = MR.Paragraph.Input(children: sampleChildren)

private let sampleInlineCodeInput = MR.InlineCode.Input(code: "let x = 42")

private let sampleListItemInput = MR.ListItem.Input(
    children: [
        .push(.block(role: .paragraph, style: .empty)),
        .text("Item content"),
        .pop(.block),
    ]
)

private let sampleEmphasisInput = MR.Emphasis.Input(children: sampleChildren)

private let sampleTextInput = MR.Text.Input(text: "Hello world")
