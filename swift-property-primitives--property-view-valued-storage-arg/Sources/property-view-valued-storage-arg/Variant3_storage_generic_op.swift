// MARK: - Variant 3: Q-STORAGE-GENERIC — the supervisor's ideal: ONE op extension covering
// every storage in a single `where Base == Buffer<S>.Linear` (generic S). If expressible it
// retro-simplifies the Contiguous-pinned ops too. HYPOTHESIS: REFUTED — `S` is a free type
// variable in the extension (Property.Inout.Typed's generics are <Tag, Base, Element>; there is
// no S parameter, and an extension cannot introduce one), the exact same wall as Shape A/C's free `n`.

import Property_Primitives
import Property_Inout_Primitives

#if SHAPE_E
extension Property_Primitives.Property.Inout.Typed
where Tag == Buffer<S>.Linear.Remove, Base == Buffer<S>.Linear {
    mutating func all() { base.value._removeAll() }
}
#endif
