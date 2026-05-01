// MARK: - V1 — Close namespace + typed close + @_spi(Syscall) raw close

public enum Close {}

extension Close {
    public enum Error: Swift.Error {
        case failed(rc: Int32)
    }
}

extension Close {
    /// Typed form: consumes ~Copyable Descriptor; applies retry policy.
    public static func close(_ fd: consuming Descriptor) throws(Error) {
        let raw = fd._rawValue
        var attempt = 0
        while attempt < 3 {
            let rc = simulatedSyscall(raw)
            if rc == 0 { return }
            attempt += 1
        }
        throw .failed(rc: -1)
    }

    /// Raw form: takes Int32 fd; bypasses retry policy.
    /// Visible only via `@_spi(Syscall) import V1_L2`.
    @_spi(Syscall)
    public static func close(_ fd: Int32) -> Int32 {
        simulatedSyscall(fd)
    }
}

// In production this would call libc.close(fd). Sandbox uses a deterministic
// stand-in to keep the experiment focused on access-control mechanics.
internal func simulatedSyscall(_ fd: Int32) -> Int32 {
    fd >= 0 ? 0 : -1
}
