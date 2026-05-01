public enum Close {}

extension Close {
    public enum Error: Swift.Error {
        case failed(rc: Int32)
    }
}

extension Close {
    /// Typed form is the entire surface at every layer.
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
}

private func simulatedSyscall(_ fd: Int32) -> Int32 {
    fd >= 0 ? 0 : -1
}
