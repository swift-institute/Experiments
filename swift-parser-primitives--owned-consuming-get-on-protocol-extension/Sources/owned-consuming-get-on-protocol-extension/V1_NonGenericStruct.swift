//
// V1 — Non-generic struct with @_owned consuming get
//
// Shape: struct NC: ~Copyable with @_owned var x: NC { consuming get { NC() } }
// Purpose: baseline replication of prior research's working case
//   (`resilient_consuming_getter_nonescapable.swift:12-20` shape).
// Expected (per prior research): PASS on Swift 6.4-dev.
//

public struct V1_NC: ~Copyable {
    public let payload: Int

    public init(_ payload: Int) {
        self.payload = payload
    }

    @_owned
    public var extracted: V1_NC {
        consuming get {
            V1_NC(payload + 1)
        }
    }
}

@inlinable
public func runV1() -> Int {
    let n = V1_NC(41)
    let m = n.extracted
    return m.payload // 42
}
