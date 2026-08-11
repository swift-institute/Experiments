// Namespace: Socket
// Holds socket-related operation records and demo entry points.

public enum Socket {}

extension Socket {
    // Simplified demo consumer specialized to IO<Socket.Ops>.
    // Demonstrates the virality: the signature explicitly names IO<Socket.Ops>.
    public static func echo(
        listener: borrowing Kernel.Descriptor,
        io: sending IO<Socket.Ops>
    ) async throws(IO<Socket.Ops>.Error) {
        _ = try await io.ops.accept(listener)
        // ... in reality, loop + echo ...
    }
}
