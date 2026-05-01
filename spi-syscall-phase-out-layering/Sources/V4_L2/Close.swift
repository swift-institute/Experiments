public enum Close {}

extension Close {
    public enum Error: Swift.Error {
        case failed(rc: Int32)
    }
}

extension Close {
    public static func close(_ fd: consuming Descriptor) throws(Error) {
        let raw = fd._rawValue
        var attempt = 0
        while attempt < 3 {
            let rc = Self.close(raw)
            if rc == 0 { return }
            attempt += 1
        }
        throw .failed(rc: -1)
    }

    /// Package-access raw form. Visible to any target within the same SPM
    /// package; not exported beyond it.
    package static func close(_ fd: Int32) -> Int32 {
        fd >= 0 ? 0 : -1
    }
}
