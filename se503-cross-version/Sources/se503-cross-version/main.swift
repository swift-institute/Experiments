// MARK: - SE-503 Cross-Version Probe (uses module — cross-module per [EXP-017])
// Production-candidate solution: gate the SE-503 restatement behind
// `#if compiler(>=6.4)`, with the current bare form on the #else branch.
// Question: does this single source compile on Swift 6.3.2 AND 6.5-dev, with
// each toolchain taking the intended branch?
//
// Status: CONFIRMED — `#if compiler(>=6.5)` gate builds + runs on 6.3.2 AND 6.5-dev
//   (debug+release, cross-module). Un-gated restatement REFUTED (6.3.2 rejects it).
//   Full results + threshold caveat in Defs.swift header.

import SE503Defs

#if compiler(>=6.5)
#warning("BRANCH WITNESS: compiler>=6.5 → SE-503 restatement branch")

// V1: extension restating suppressed PRIMARY assoc
extension Mailbox where Items: ~Copyable { public func v1() {} }
// V2: generic function
public func v2<T>(_ t: borrowing T) where T: Mailbox, T.Items: ~Copyable {}
// V3: generic struct
public struct V3<M: Mailbox> where M.Items: ~Copyable {}
// V4: inherited re-exposed primary
extension Stream where Element: ~Copyable { public func v4() {} }
public func v4f<S>(_ s: borrowing S) where S: Stream, S.Element: ~Copyable {}
// V5: defaulted non-primary inherited assoc (Fixture+describe shape)
public func v5<C>(_ c: borrowing C) where C: Quantity, C.Domain: ~Copyable {}

#else
#warning("BRANCH WITNESS: compiler<6.5 → prototype bare branch")

// V1..V5 in the CURRENT (prototype, pre-migration) bare form — no restatement.
extension Mailbox { public func v1() {} }
public func v2<T>(_ t: borrowing T) where T: Mailbox {}
public struct V3<M: Mailbox> {}
extension Stream { public func v4() {} }
public func v4f<S>(_ s: borrowing S) where S: Stream {}
public func v5<C>(_ c: borrowing C) where C: Quantity {}

#endif

print("se503-cross-version built")
