// MARK: - Rendering Context Algebra Composition Tests
// Purpose: Validate the context transformer pattern compiles and produces correct results
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Hypotheses:
//   H1: ~Copyable witness struct with closures compiles
//   H2: consuming transformer produces correct output
//   H3: Ref<T> capture works without unsafe pointers
//   H4: Transformers compose (chain multiple transformers)
//   H5: Observing transformer logs actions correctly
//   H6: State is accessible after rendering (via Ref<T>)
//   H7: Action interpreter produces same output as direct calls
//
// Result: {PENDING}
// Date: 2026-03-14

import Testing
@testable import Variants

// MARK: - V1a: Pointer-based HTML context

@Suite
struct `V1a - Pointer HTML Context` {

    @Test
    func `produces correct HTML bytes`() {
        var html = HTMLContext()
        withUnsafeMutablePointer(to: &html) { ptr in
            var ctx = Rendering.Context.html(pointer: ptr)
            ctx.pushBlock(.paragraph, .empty)
            ctx.text("Hello, world!")
            ctx.popBlock()
        }
        let output = String(validating: html.bytes, as: UTF8.self)!
        #expect(output == "<p>Hello, world!</p>")
    }

    @Test
    func `heading renders correctly`() {
        var html = HTMLContext()
        withUnsafeMutablePointer(to: &html) { ptr in
            var ctx = Rendering.Context.html(pointer: ptr)
            ctx.pushBlock(.heading(level: 1), .empty)
            ctx.text("Title")
            ctx.popBlock()
        }
        let output = String(validating: html.bytes, as: UTF8.self)!
        #expect(output == "<h1>Title</h1>")
    }

    @Test
    func `nested elements`() {
        var html = HTMLContext()
        withUnsafeMutablePointer(to: &html) { ptr in
            var ctx = Rendering.Context.html(pointer: ptr)
            ctx.pushBlock(.paragraph, .empty)
            ctx.text("Hello ")
            ctx.pushInline(.strong, .empty)
            ctx.text("world")
            ctx.popInline()
            ctx.popBlock()
        }
        let output = String(validating: html.bytes, as: UTF8.self)!
        #expect(output == "<p>Hello <strong>world</strong></p>")
    }

    @Test
    func `list rendering`() {
        var html = HTMLContext()
        withUnsafeMutablePointer(to: &html) { ptr in
            var ctx = Rendering.Context.html(pointer: ptr)
            ctx.pushList(.unordered, nil)
            ctx.pushItem()
            ctx.text("Item 1")
            ctx.popItem()
            ctx.pushItem()
            ctx.text("Item 2")
            ctx.popItem()
            ctx.popList()
        }
        let output = String(validating: html.bytes, as: UTF8.self)!
        #expect(output == "<ul><li>Item 1</li><li>Item 2</li></ul>")
    }
}

// MARK: - V1b: Ref-based HTML context (pointer-free)

@Suite
struct `V1b - Ref HTML Context` {

    @Test
    func `produces same output as pointer variant`() {
        let html = Ref(HTMLContext())
        var ctx = Rendering.Context.html(ref: html)
        ctx.pushBlock(.paragraph, .empty)
        ctx.text("Hello, world!")
        ctx.popBlock()
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<p>Hello, world!</p>")
    }

    @Test
    func `state accessible after rendering`() {
        let html = Ref(HTMLContext())
        var ctx = Rendering.Context.html(ref: html)
        _ = ctx.registerStyle("color: red")
        _ = ctx.registerStyle("margin: 0")
        #expect(html.value.styles.count == 2)
        #expect(html.value.styles["c0"] == "color: red")
        #expect(html.value.styles["c1"] == "margin: 0")
    }

    @Test
    func `no unsafe code in call site`() {
        // This test validates that the Ref pattern requires zero unsafe keywords
        let html = Ref(HTMLContext())
        var ctx = Rendering.Context.html(ref: html)
        ctx.pushBlock(.heading(level: 2), .empty)
        ctx.text("Safe")
        ctx.popBlock()
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h2>Safe</h2>")
    }
}

// MARK: - V2: Transformer (algebra endomorphism)

@Suite
struct `V2 - Transformer Composition` {

    @Test
    func `html transformer tracks headings via Ref`() {
        let html = Ref(HTMLContext())
        let htmlState = Ref(HTMLTransformState())

        var ctx = Rendering.Context.html(ref: html)
            .html(state: htmlState)

        ctx.pushBlock(.heading(level: 1), .empty)
        ctx.text("Introduction")
        ctx.popBlock()

        ctx.pushBlock(.paragraph, .empty)
        ctx.text("Some text.")
        ctx.popBlock()

        ctx.pushBlock(.heading(level: 2), .empty)
        ctx.text("Details")
        ctx.popBlock()

        // Verify headings were tracked by the transformer
        #expect(htmlState.value.headings.count == 2)
        #expect(htmlState.value.headings[0].level == 1)
        #expect(htmlState.value.headings[0].text == "Introduction")
        #expect(htmlState.value.headings[1].level == 2)
        #expect(htmlState.value.headings[1].text == "Details")

        // Verify HTML output is still correct (base context wasn't broken)
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h1>Introduction</h1><p>Some text.</p><h2>Details</h2>")
    }

    @Test
    func `transformer tracks element depth`() {
        let html = Ref(HTMLContext())
        let htmlState = Ref(HTMLTransformState())

        var ctx = Rendering.Context.html(ref: html)
            .html(state: htmlState)

        #expect(htmlState.value.elementDepth == 0)
        ctx.pushElement("div", true)
        #expect(htmlState.value.elementDepth == 1)
        ctx.pushElement("p", true)
        #expect(htmlState.value.elementDepth == 2)
        ctx.popElement(true)
        #expect(htmlState.value.elementDepth == 1)
        ctx.popElement(true)
        #expect(htmlState.value.elementDepth == 0)
    }

    @Test
    func `consuming semantics - base context is moved not copied`() {
        let html = Ref(HTMLContext())
        var ctx = Rendering.Context.html(ref: html)

        // The base context is consumed by the transformer.
        // After this line, `ctx` is the old binding — the new context
        // is the transformed one. The compiler enforces this because
        // Rendering.Context is ~Copyable.
        let htmlState = Ref(HTMLTransformState())
        ctx = ctx.html(state: htmlState)

        ctx.pushBlock(.heading(level: 1), .empty)
        ctx.text("Works")
        ctx.popBlock()

        #expect(htmlState.value.headings.count == 1)
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h1>Works</h1>")
    }
}

// MARK: - V3: Observing transformer (middleware)

@Suite
struct `V3 - Observing Transformer` {

    @Test
    func `logs all actions`() {
        let html = Ref(HTMLContext())
        let log = Ref<[Rendering.Action]>([])

        var ctx = Rendering.Context.html(ref: html)
            .observing(log: log)

        ctx.pushBlock(.paragraph, .empty)
        ctx.text("Hello")
        ctx.popBlock()

        #expect(log.value.count == 3)
        // Verify action types
        if case .push(.block(role: .paragraph, style: _)) = log.value[0] {
            // correct
        } else {
            Issue.record("Expected .push(.block(.paragraph))")
        }
        if case .text("Hello") = log.value[1] {
            // correct
        } else {
            Issue.record("Expected .text(\"Hello\")")
        }
        if case .pop(.block) = log.value[2] {
            // correct
        } else {
            Issue.record("Expected .pop(.block)")
        }

        // HTML output is still correct
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<p>Hello</p>")
    }

    @Test
    func `composes with html transformer - triple composition`() {
        let html = Ref(HTMLContext())
        let htmlState = Ref(HTMLTransformState())
        let log = Ref<[Rendering.Action]>([])

        // Triple composition: html base → html transformer → observer
        // Reads as: "an HTML context, with HTML semantic understanding, observed"
        var ctx = Rendering.Context.html(ref: html)
            .html(state: htmlState)
            .observing(log: log)

        ctx.pushBlock(.heading(level: 1), .empty)
        ctx.text("Title")
        ctx.popBlock()

        // All three layers work:
        // 1. HTML bytes produced
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h1>Title</h1>")

        // 2. Heading tracked
        #expect(htmlState.value.headings.count == 1)
        #expect(htmlState.value.headings[0].text == "Title")

        // 3. Actions logged
        #expect(log.value.count == 3)
    }
}

// MARK: - V4: Action interpreter

@Suite
struct `V4 - Action Interpreter` {

    @Test
    func `interpreter produces same output as direct calls`() {
        // Direct calls
        let htmlDirect = Ref(HTMLContext())
        var ctxDirect = Rendering.Context.html(ref: htmlDirect)
        ctxDirect.pushBlock(.heading(level: 1), .empty)
        ctxDirect.text("Hello")
        ctxDirect.popBlock()

        // Via action interpreter
        let htmlInterpreted = Ref(HTMLContext())
        var ctxInterpreted = Rendering.Context.html(ref: htmlInterpreted)
        let actions: [Rendering.Action] = [
            .push(.block(role: .heading(level: 1), style: .empty)),
            .text("Hello"),
            .pop(.block),
        ]
        ctxInterpreted.interpret(actions)

        // Same output
        #expect(htmlDirect.value.bytes == htmlInterpreted.value.bytes)
    }

    @Test
    func `interpreter works with transformed context`() {
        let html = Ref(HTMLContext())
        let htmlState = Ref(HTMLTransformState())

        var ctx = Rendering.Context.html(ref: html)
            .html(state: htmlState)

        let actions: [Rendering.Action] = [
            .push(.block(role: .heading(level: 2), style: .empty)),
            .text("Interpreted Heading"),
            .pop(.block),
        ]
        ctx.interpret(actions)

        // HTML output correct
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h2>Interpreted Heading</h2>")

        // Heading tracked by transformer
        #expect(htmlState.value.headings.count == 1)
        #expect(htmlState.value.headings[0].text == "Interpreted Heading")
    }
}

// MARK: - V5: Ergonomics

@Suite
struct `V5 - Call Site Ergonomics` {

    @Test
    func `rendering entry point reads as intent`() {
        // This test validates the ergonomics of the full rendering pipeline.
        // The call site should read as: "create an HTML context, add HTML semantics, render"

        let html = Ref(HTMLContext())
        let headings = Ref(HTMLTransformState())

        var context = Rendering.Context.html(ref: html)
            .html(state: headings)

        // Simulate what a Markdown converter would do
        context.pushBlock(.heading(level: 1), .empty)
        context.text("Welcome")
        context.popBlock()

        context.pushBlock(.paragraph, .empty)
        context.text("This is a ")
        context.pushInline(.strong, .empty)
        context.text("bold")
        context.popInline()
        context.text(" paragraph.")
        context.popBlock()

        context.pushList(.unordered, nil)
        context.pushItem()
        context.text("First")
        context.popItem()
        context.pushItem()
        context.text("Second")
        context.popItem()
        context.popList()

        // Verify complete output
        let output = String(validating: html.value.bytes, as: UTF8.self)!
        #expect(output == "<h1>Welcome</h1><p>This is a <strong>bold</strong> paragraph.</p><ul><li>First</li><li>Second</li></ul>")

        // Verify table of contents extracted
        #expect(headings.value.headings.count == 1)
        #expect(headings.value.headings[0].text == "Welcome")
    }
}
