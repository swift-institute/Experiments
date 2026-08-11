//
// IO error domain. Describes failure, not recovery, per [API-ERR-003].
//

extension IO {
    public enum Error: Swift.Error {
        case failed
    }
}
