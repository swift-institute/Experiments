// Minimal reproduction: GENERIC ~Copyable enum with trivial Optional field.
// Models Async.Channel<Element>.Bounded.State.Receive.Action exactly.

public enum Action<Element: ~Copyable>: ~Copyable {
    case returnElement(
        Element,
        resumeSender: UnsafeContinuation<Void, Never>?
    )
    case suspend
    case returnNil
}

public struct State<Element: ~Copyable>: ~Copyable {
    @usableFromInline var pending: Element?
    @usableFromInline var sender: UnsafeContinuation<Void, Never>?

    @inlinable
    public init() {
        self.pending = nil
        self.sender = nil
    }

    @inlinable
    public mutating func receive() -> Action<Element> {
        if let element = pending.take() {
            let s = sender.take()
            return .returnElement(element, resumeSender: s)
        } else {
            return .suspend
        }
    }

    @inlinable
    public mutating func store(_ element: consuming Element) {
        pending = consume element
    }
}

// @inlinable generic receive — models Channel.Bounded.Receiver.receive()
@inlinable
public func processReceive<Element: ~Copyable>(state: inout State<Element>) -> Element? {
    let action = state.receive()
    switch consume action {
    case .returnElement(let element, let resumeSender):
        resumeSender?.resume(returning: ())
        return element
    case .suspend:
        return nil
    case .returnNil:
        return nil
    }
}
