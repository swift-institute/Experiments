/// A self-describing storage slot: `.empty` or `.occupied(Element)`.
///
/// The crux of the slot-backed sparse-inline design. Because `InlineArray`
/// recursively deinitializes each element on drop, an `.occupied` slot tears down
/// its payload automatically and an `.empty` slot is a no-op — so the enclosing
/// buffer needs **no custom `deinit`**, sidestepping **Wall 1** (SE-0427
/// `copyable_illegal_deinit`: a conditionally-`Copyable` value type may not declare
/// a `deinit`) entirely. `~Copyable` payloads are supported; `Copyable` is inherited
/// conditionally so the whole tower stays conditionally-`Copyable`.
public enum Slot<Element: ~Copyable>: ~Copyable {
    case empty
    case occupied(Element)
}

extension Slot: Copyable where Element: Copyable {}
