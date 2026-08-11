// CaseIterable.swift
// Retroactive CaseIterable conformances for concrete Enumerable types.
//
// This mirrors what finite-collection-primitives would provide:
// each Finite.Enumerable type gets CaseIterable via the integration package,
// not via protocol inheritance.

import CoreFinite

// MARK: - Retroactive CaseIterable

// Note: @retroactive is needed in production (separate packages), not here (same package).
extension CoreFinite.Bound: CaseIterable {}
extension CoreFinite.Ternary: CaseIterable {}
