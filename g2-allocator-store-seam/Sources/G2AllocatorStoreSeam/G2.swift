// ===----------------------------------------------------------------------===//
//
// g2-allocator-store-seam — namespace root
//
// ===----------------------------------------------------------------------===//

/// Namespace for the G2 allocator/store-seam design experiment.
///
/// The "G2 seam" is the boundary between an *allocator discipline* (how raw
/// bytes are handed out and reclaimed) and the typed `Buffer<Storage<…>>` tower
/// (which addresses *initialized typed slots* through `Store.`Protocol``). This
/// experiment probes whether two allocator disciplines can present themselves as
/// a typed `Store.`Protocol`` directly, or whether they must remain raw
/// `Memory.Allocator.`Protocol`` (vending addresses) with typing composed at the
/// call site.
public enum G2 {}
