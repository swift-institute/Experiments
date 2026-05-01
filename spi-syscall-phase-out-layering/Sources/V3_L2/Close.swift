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
            let rc = internalRawClose(raw)
            if rc == 0 { return }
            attempt += 1
        }
        throw .failed(rc: -1)
    }
}

/// Internal-access raw helper. Visible to:
///   - other files in V3_L2 module (default Swift visibility)
///   - sibling targets that use `@testable import V3_L2` AND have
///     V3_L2 compiled with `-enable-testing`
/// Invisible to ordinary `import V3_L2` consumers.
internal func internalRawClose(_ fd: Int32) -> Int32 {
    fd >= 0 ? 0 : -1
}
