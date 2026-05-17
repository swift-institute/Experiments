/// Draft `Cursor` namespace under test for BENCH-011 probe.
///
/// Mirrors the proposed Phase 1 shape of `swift-cursor-primitives`. Used
/// only to validate `[BENCH-011]` integration probe: generic specialization
/// of `~Copyable & ~Escapable` cursor parameterized over
/// `Tagged<DomainTag, Ordinal>` position must not regress relative to the
/// production per-domain `Binary.Bytes.Input.View` (raw `Int` position)
/// and `Lexer.Scanner` (`Text.Position` position).
public enum Cursor {}
