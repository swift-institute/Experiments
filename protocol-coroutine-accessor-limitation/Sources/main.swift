// MARK: - Protocol Coroutine Accessor Limitation
// Purpose: Protocol extensions fail with _read/_modify accessors + ~Copyable
// Status: CONFIRMED (2026-01-21, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — cannot infer Element through protocol with ~Copyable (2026-03-10)

protocol ContainerProtocol<Element>: ~Copyable {
    associatedtype Element: ~Copyable
    var storage: UnsafeMutablePointer<Element> { get }
    var count: Int { get }
}

// Protocol extension with coroutine accessors
extension ContainerProtocol {
    subscript(position: Int) -> Element {
        _read {
            precondition(position >= 0 && position < count)
            yield storage[position]
        }
        _modify {
            precondition(position >= 0 && position < count)
            yield &storage[position]
        }
    }
}

struct MyContainer<Element: ~Copyable>: ~Copyable, ContainerProtocol {
    var storage: UnsafeMutablePointer<Element>
    var count: Int

    init(capacity: Int) {
        storage = .allocate(capacity: capacity)
        count = 0
    }

    deinit {
        storage.deinitialize(count: count)
        storage.deallocate()
    }
}

struct Token: ~Copyable { var id: Int }
var c = MyContainer<Token>(capacity: 4)
print("Protocol coroutine accessor test: BUILD SUCCEEDED")
