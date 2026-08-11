// Eio.Stdenv — capability bundle carrying the three sub-capabilities. Mirrors
// OCaml Eio's `Stdenv.t` record.

extension Eio {
    public struct Stdenv: Sendable {
        public let net: Eio.Net
        public let file: Eio.File
        public let clock: Eio.Clock

        public init(net: Eio.Net, file: Eio.File, clock: Eio.Clock) {
            self.net = net
            self.file = file
            self.clock = clock
        }
    }
}
