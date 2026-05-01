public enum Close {}

extension Close {
    public enum Error: Swift.Error {
        case failed(rc: Int32)
    }
}

extension Close {
    /// Typed form: the only public-or-SPI surface. Internally uses the
    /// file-private FFI helper.
    public static func close(_ fd: consuming Descriptor) throws(Error) {
        let raw = fd._rawValue
        var attempt = 0
        while attempt < 3 {
            let rc = privateRawClose(raw)
            if rc == 0 { return }
            attempt += 1
        }
        throw .failed(rc: -1)
    }
}

// Private (file-scope) FFI helper — invisible to other files in the same
// module, to V2_L3, to V2_Consumer. The raw call site is contained.
private func privateRawClose(_ fd: Int32) -> Int32 {
    fd >= 0 ? 0 : -1
}
