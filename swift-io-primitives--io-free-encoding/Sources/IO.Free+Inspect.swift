//
// IO.Free inspector — project the operation at the head of this
// program (if any) into the IO.Op descriptive enum and pass it to
// `visit`. Returns silently for .pure / .fail leaves. Cannot recurse
// past the head op without supplying a result for the continuation —
// for full traversal, supply an interpreter that records each op
// (typically: a recording handler).
//
// This is the property the dictionary encoding cannot offer: programs
// are *data*, so they can be inspected before execution. In practice
// this enables dry-run logging, op-count metrics, schedule analysis,
// and replay fixtures.
//

extension IO.Free {

    public func inspectHead(_ visit: (IO.Op) -> Void) {
        switch self {
        case .pure, .fail:
            return
        case .readOp(let descriptor, let buffer, _):
            visit(.read(from: descriptor, into: buffer))
        case .writeOp(let descriptor, let buffer, _):
            visit(.write(to: descriptor, from: buffer))
        case .closeOp(let descriptor, _):
            visit(.close(descriptor: descriptor))
        case .readyOp(let descriptor, let interest, _):
            visit(.ready(from: descriptor, interest: interest))
        }
    }
}
