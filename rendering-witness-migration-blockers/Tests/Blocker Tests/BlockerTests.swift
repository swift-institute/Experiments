// MARK: - Migration Blocker Validation Tests
// Purpose: Validate 4 claims that would block the witness migration if they fail.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Hypotheses:
//   V1: _render with concrete context works as protocol requirement
//   V2: Property.View with Base == Rendering.Context works
//   V3: AnyView existential opening works without generic C
//   V4: Tee transform compiles and duplicates to two targets
//
// Result: {PENDING}
// Date: 2026-03-14

import Testing
@testable import Variants

// MARK: - V1: _render as non-generic protocol requirement

@Suite
struct `V1 - Non-Generic _render` {

    @Test
    func `leaf view renders directly`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        TextLeaf._render(TextLeaf("Hello"), context: &ctx)
        #expect(state.string == "Hello")
    }

    @Test
    func `composite leaf view with push pop`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let p = Paragraph { TextLeaf("World") }
        Paragraph._render(p, context: &ctx)
        #expect(state.string == "<p>World</p>")
    }

    @Test
    func `body-based composite dispatches through default _render`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let article = Article(title: "Title", body: "Body text")
        Article._render(article, context: &ctx)
        #expect(state.string == "<p>Title</p><p>Body text</p>")
    }

    @Test
    func `_Tuple renders all children`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let tuple = Rendering._Tuple(TextLeaf("A"), TextLeaf("B"), TextLeaf("C"))
        Rendering._Tuple._render(tuple, context: &ctx)
        #expect(state.string == "ABC")
    }

    @Test
    func `Optional renders when present`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let opt: TextLeaf? = TextLeaf("Present")
        Optional._render(opt, context: &ctx)
        #expect(state.string == "Present")
    }

    @Test
    func `Optional renders nothing when nil`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let opt: TextLeaf? = nil
        Optional._render(opt, context: &ctx)
        #expect(state.string == "")
    }

    @Test
    func `Array renders all elements`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let arr = [TextLeaf("X"), TextLeaf("Y")]
        Array._render(arr, context: &ctx)
        #expect(state.string == "XY")
    }

    @Test
    func `nested composite views dispatch correctly`() {
        // Article contains two Paragraphs, each containing a TextLeaf.
        // This tests: Article (body-based default) → _Tuple → Paragraph (leaf _render) → TextLeaf
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let article = Article(title: "Heading", body: "Content")
        Article._render(article, context: &ctx)
        #expect(state.string.contains("<p>Heading</p>"))
        #expect(state.string.contains("<p>Content</p>"))
    }
}

// MARK: - V2: Property.View with Base == Rendering.Context

@Suite
struct `V2 - Property View Concrete Constraint` {

    @Test
    func `push block via Property View accessor`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        ctx.push.block(role: .heading(level: 1), style: .empty)
        ctx.text("Title")
        ctx.pop.block()
        #expect(state.string == "<h1>Title</h1>")
    }

    @Test
    func `push inline via Property View accessor`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        ctx.push.inline(role: .strong, style: .empty)
        ctx.text("Bold")
        ctx.pop.inline()
        #expect(state.string == "<strong>Bold</strong>")
    }

    @Test
    func `push list and items via Property View`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        ctx.push.list(kind: .unordered, start: nil)
        ctx.push.item()
        ctx.text("One")
        ctx.pop.item()
        ctx.push.item()
        ctx.text("Two")
        ctx.pop.item()
        ctx.pop.list()
        #expect(state.string == "<ul><li>One</li><li>Two</li></ul>")
    }

    @Test
    func `push link via Property View`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        ctx.push.link("https://example.com")
        ctx.text("Click")
        ctx.pop.link()
        #expect(state.string == "<a href=\"https://example.com\">Click</a>")
    }

    @Test
    func `push element via Property View`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        ctx.push.element(tagName: "section", block: true)
        ctx.text("Content")
        ctx.pop.element(block: true)
        #expect(state.string == "<section>Content</section>")
    }

    @Test
    func `Property View accessor used inside _render`() {
        // Paragraph._render uses ctx.push.block() and ctx.pop.block()
        // This validates the accessor works from within a _render method
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        Paragraph._render(Paragraph { TextLeaf("Inside") }, context: &ctx)
        #expect(state.string == "<p>Inside</p>")
    }
}

// MARK: - V3: AnyView existential opening

@Suite
struct `V3 - AnyView Without Generic C` {

    @Test
    func `AnyView wraps and renders leaf view`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let view = AnyRenderingView(TextLeaf("Erased"))
        AnyRenderingView._render(view, context: &ctx)
        #expect(state.string == "Erased")
    }

    @Test
    func `AnyView wraps and renders composite view`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let view = AnyRenderingView(Paragraph { TextLeaf("Wrapped") })
        AnyRenderingView._render(view, context: &ctx)
        #expect(state.string == "<p>Wrapped</p>")
    }

    @Test
    func `AnyView wraps AnyView without double wrapping`() {
        let inner = AnyRenderingView(TextLeaf("Deep"))
        let outer = AnyRenderingView(inner)
        // Should not double-wrap
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        AnyRenderingView._render(outer, context: &ctx)
        #expect(state.string == "Deep")
    }

    @Test
    func `Array of AnyView renders all elements`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let views: [AnyRenderingView] = [
            AnyRenderingView(TextLeaf("A")),
            AnyRenderingView(Paragraph { TextLeaf("B") }),
            AnyRenderingView(TextLeaf("C")),
        ]
        for view in views {
            AnyRenderingView._render(view, context: &ctx)
        }
        #expect(state.string == "A<p>B</p>C")
    }

    @Test
    func `body-based view through AnyView`() {
        let state = HTMLState()
        var ctx = Rendering.Context.html(state: state)
        let article = Article(title: "T", body: "B")
        let view = AnyRenderingView(article)
        AnyRenderingView._render(view, context: &ctx)
        #expect(state.string == "<p>T</p><p>B</p>")
    }
}

// MARK: - V4: Tee transform

@Suite
struct `V4 - Tee Transform` {

    @Test
    func `tee duplicates text to both targets`() {
        let stateA = HTMLState()
        let stateB = HTMLState()

        var ctx = Rendering.Context.tee(
            .html(state: stateA),
            .html(state: stateB)
        )

        ctx.text("Hello")
        #expect(stateA.string == "Hello")
        #expect(stateB.string == "Hello")
    }

    @Test
    func `tee duplicates push pop structure`() {
        let stateA = HTMLState()
        let stateB = HTMLState()

        var ctx = Rendering.Context.tee(
            .html(state: stateA),
            .html(state: stateB)
        )

        ctx.push.block(role: .heading(level: 1), style: .empty)
        ctx.text("Title")
        ctx.pop.block()

        #expect(stateA.string == "<h1>Title</h1>")
        #expect(stateB.string == "<h1>Title</h1>")
    }

    @Test
    func `tee works with _render dispatch`() {
        let stateA = HTMLState()
        let stateB = HTMLState()

        var ctx = Rendering.Context.tee(
            .html(state: stateA),
            .html(state: stateB)
        )

        let article = Article(title: "Same", body: "Output")
        Article._render(article, context: &ctx)

        #expect(stateA.string == stateB.string)
        #expect(stateA.string == "<p>Same</p><p>Output</p>")
    }

    @Test
    func `tee with independent state per target`() {
        let stateA = HTMLState()
        let stateB = HTMLState()

        var ctx = Rendering.Context.tee(
            .html(state: stateA),
            .html(state: stateB)
        )

        ctx.push.list(kind: .unordered, start: nil)
        ctx.push.item()
        ctx.text("Item")
        ctx.pop.item()
        ctx.pop.list()

        // Both produce identical output independently
        #expect(stateA.string == "<ul><li>Item</li></ul>")
        #expect(stateB.string == "<ul><li>Item</li></ul>")
    }

    @Test
    func `tee with AnyView through _render`() {
        let stateA = HTMLState()
        let stateB = HTMLState()

        var ctx = Rendering.Context.tee(
            .html(state: stateA),
            .html(state: stateB)
        )

        let view = AnyRenderingView(Paragraph { TextLeaf("Teed") })
        AnyRenderingView._render(view, context: &ctx)

        #expect(stateA.string == "<p>Teed</p>")
        #expect(stateB.string == "<p>Teed</p>")
    }
}
