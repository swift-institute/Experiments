//
// IO.Op — descriptive value-type for inspection callbacks. Mirrors the
// operation cases of `IO.Free` (one per Σ_IO operation) but carries no
// continuation, so it's safe to hand to inspection callbacks without
// forcing them to be generic in the program's value type.
//
// Note: this enum is *not* what the program is built from. The program
// is `IO.Free<Value, Failure>` directly — each Free case carries its
// op arguments + a typed continuation. IO.Op is the projection of
// "what op is here?" for inspectors that don't care about the
// continuation.
//

extension IO {

    public enum Op: Sendable {
        case read(from: Kernel.Descriptor, into: Memory.Buffer.Mutable)
        case write(to: Kernel.Descriptor, from: Memory.Buffer)
        case close(descriptor: Kernel.Descriptor)
        case ready(from: Kernel.Descriptor, interest: Kernel.Event.Interest)
    }
}
