// UmbrellaTypealias/exports.swift
// Proposed fix: @_exported import Core PLUS a typealias that makes Array
// a first-class declaration in this module.
@_exported public import Core

/// Re-declares Array as a member of UmbrellaTypealias, giving it
/// "explicitly imported" precedence for consumers.
public typealias Array = Core.Array
