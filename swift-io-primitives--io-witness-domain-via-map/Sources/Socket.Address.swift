//
//  Socket.Address — peer address returned from accept or passed to connect.
//

extension Socket {
    public struct Address: Sendable {
        public let ipv4: UInt32
        public let port: UInt16

        public init(ipv4: UInt32, port: UInt16) {
            self.ipv4 = ipv4
            self.port = port
        }
    }
}
