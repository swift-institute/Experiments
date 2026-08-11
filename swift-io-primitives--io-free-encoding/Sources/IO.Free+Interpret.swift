//
// IO.Free interpreter — fold IO.Free<Value, Failure> against an
// IO.Handler<Failure>. Each operation node is discharged by the
// corresponding handler closure; the handler's typed throws propagate
// as the program's typed Failure; the result threads into the
// continuation; recursion ends at .pure (return) or .fail (throw).
//
// This fold establishes the *equivalence* between the free encoding
// (IO.Free) and the dictionary encoding (IO.Handler): a program
// written in IO.Free and run via this interpreter produces the same
// observable result and same thrown errors as if every op had been
// called directly on the handler.
//

extension IO.Free {

    public func run(
        handler: IO.Handler<Failure>
    ) async throws(Failure) -> Value {
        switch self {
        case .pure(let value):
            return value
        case .fail(let error):
            throw error
        case .readOp(let descriptor, let buffer, let continuation):
            let bytes = try await handler.read(descriptor, buffer)
            return try await continuation(bytes).run(handler: handler)
        case .writeOp(let descriptor, let buffer, let continuation):
            let bytes = try await handler.write(descriptor, buffer)
            return try await continuation(bytes).run(handler: handler)
        case .closeOp(let descriptor, let continuation):
            try await handler.close(descriptor)
            return try await continuation().run(handler: handler)
        case .readyOp(let descriptor, let interest, let continuation):
            try await handler.ready(descriptor, interest)
            return try await continuation().run(handler: handler)
        }
    }
}
