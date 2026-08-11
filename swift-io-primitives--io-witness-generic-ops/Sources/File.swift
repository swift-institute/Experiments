// Namespace: File
// Holds file-related operation records and demo entry points.

public enum File {}

extension File {
    // Simplified demo consumer specialized to IO<File.Ops>.
    // Demonstrates the virality: the signature explicitly names IO<File.Ops>.
    public static func compact(
        fd: borrowing Kernel.Descriptor,
        io: sending IO<File.Ops>
    ) async throws(IO<File.Ops>.Error) {
        try await io.ops.fsync(fd)
    }
}
