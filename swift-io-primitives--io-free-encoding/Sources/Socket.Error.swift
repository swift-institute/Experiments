//
// Socket.Error — higher-layer error type wrapping IO.Error plus
// socket-specific cases. Used to demonstrate `IO.Free.mapError`.
//

extension Socket {

    public enum Error: Swift.Error, Sendable {
        case io(IO.Error)
        case refused
        case timeout
    }
}
