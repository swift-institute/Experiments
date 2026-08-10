// ============================================================================
// V7: Custom Sequence.Iterator.Protocol supporting ~Copyable iterators
// ============================================================================
//
// Hypothesis: We can create our own iterator protocol that allows ~Copyable
//             and ~Escapable iterators, enabling Span-based iteration.
//
// Finding: Swift currently does NOT support ~Copyable associated types.
//          Error: "cannot suppress 'Copyable' requirement of an associated type"
//          This is noted as a future direction in SE-0427.
//
// Finding 2: ~Escapable iterators have strict lifetime constraints that make
//            the traditional iterator pattern difficult. The Span can't be
//            stored in an iterator that outlives the property access scope.
//
// Solution: Use closure-based withSpan pattern for ~Escapable access.
//
// ============================================================================

import Index_Primitives

// MARK: - V7: Closure-based Span iteration

/// ~Copyable container with closure-based Span access.
/// This is the correct pattern for ~Escapable types.
@safe
struct SpanContainer<Element: Copyable>: ~Copyable {
    private let storage: UnsafeMutablePointer<Element>
    let count: Index<Element>.Count

    init(_ elements: [Element]) throws {
        let c = try Index<Element>.Count(elements.count)
        self.count = c
        unsafe self.storage = UnsafeMutablePointer<Element>.allocate(capacity: elements.count)
        for (i, e) in elements.enumerated() {
            unsafe (storage + i).initialize(to: e)
        }
    }

    deinit {
        for i in 0..<count.rawValue {
            unsafe (storage + i).deinitialize(count: 1)
        }
        unsafe storage.deallocate()
    }

    /// Closure-based Span access - the ~Escapable Span cannot escape the closure.
    @_lifetime(borrow self)
    borrowing func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
        let span = unsafe Span(_unsafeStart: UnsafePointer(storage), count: count.rawValue)
        return body(span)
    }

    /// forEach using closure-based Span access with index iteration.
    /// This is the safe pattern for ~Escapable types.
    borrowing func forEach(_ body: (Element) -> Void) {
        withSpan { span in
            var position = 0
            while position < span.count {
                body(span[position])
                position += 1
            }
        }
    }

    /// forEach with typed Index.
    borrowing func forEachIndexed(_ body: (Index<Element>, Element) -> Void) {
        withSpan { span in
            var position: Index<Element> = .zero
            let end = Index<Element>.Count(__unchecked: span.count)
            while position < end {
                body(position, span[position.position.rawValue])
                position = (position + 1)!
            }
        }
    }
}

// MARK: - V7 Test

func testV7() {
    do {
        let container = try SpanContainer([1, 2, 3, 4, 5])

        var sum = 0
        container.forEach { value in
            sum += value
        }

        if sum == 15 {
            print("V7 PASS: Closure-based Span iteration")
            print("         Container: ~Copyable, Span: ~Escapable (closure-scoped)")
            print("         Pattern: withSpan { } ensures Span cannot escape")
        } else {
            print("V7 FAIL: Expected sum 15, got \(sum)")
        }

        // Test indexed iteration
        var indices: [Int] = []
        container.forEachIndexed { index, value in
            indices.append(index.position.rawValue)
        }
        print("         Indexed positions: \(indices)")

    } catch {
        print("V7 FAIL: \(error)")
    }
}
