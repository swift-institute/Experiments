// IO<Ops>: generic over the operation-set record.
// Ops is a struct of closures (e.g., Socket.Ops, File.Ops).

public struct IO<Ops> {
    public let ops: Ops

    public init(ops: Ops) {
        self.ops = ops
    }
}
