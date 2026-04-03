# noncopyable-constraint-behavior

Consolidated experiment package covering constraint poisoning from Sequence conformance and cross-module propagation of ~Copyable constraints.

Consolidation: [EXP-018]

## Variants

| Variant | Origin | Status |
|---------|--------|--------|
| V01_SequenceProtocol | noncopyable-sequence-protocol-test | CONFIRMED — same-file Sequence conformance poisons ~Copyable usage |
| V02_MultifilePoisoning | noncopyable-multifile-poisoning | CONFIRMED — file separation within module does NOT prevent poisoning |
| V03_StoragePoisoning | noncopyable-storage-poisoning | BUG REPRODUCED — conditional conformance poisons stored property access |
| V04_PointerPropagation | noncopyable-pointer-propagation | BUG REPRODUCED — Sequence conformance poisons UnsafeMutablePointer storage |
| V05_PointerPropagationMultifile | noncopyable-pointer-propagation-multifile | BUG REPRODUCED — file-level separation does not prevent poisoning |
| V06_SequenceEmitModuleBug | noncopyable-sequence-emit-module-bug | BUG FILED #86669 — module emission failure with ~Copyable + Sequence |
| V07_ProtocolWorkarounds | noncopyable-protocol-workarounds | RESOLVED — SuppressedAssociatedTypes enables `associatedtype Element: ~Copyable` |
| V08_CrossModulePropagation | noncopyable-cross-module-propagation | FIXED — cross-module ~Copyable constraint propagation works in Swift 6.2.4 |

## Theme

Constraint poisoning from Sequence conformance, cross-module propagation of ~Copyable constraints.

## Commented-out code

V01 through V06 contain commented-out Sequence conformance extensions. These are the bug reproductions — uncommenting them triggers the constraint poisoning bugs that each variant documents. The comments are annotated with `// COMPILE ERROR (expected):` explaining why they must remain commented out for the package to build.

## Multi-module structure

V08 uses a separate `CrossModuleLib` target (in `Sources/CrossModuleLib/`) to test cross-module ~Copyable propagation. The main target depends on it.
