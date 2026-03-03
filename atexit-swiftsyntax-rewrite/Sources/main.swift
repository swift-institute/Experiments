// MARK: - atexit + SwiftSyntax Rewrite Validation
// Purpose: Verify that SwiftSyntax parsing and source file rewriting work
//          correctly inside an atexit handler.
// Hypothesis: SwiftSyntax heap-allocated types survive until atexit fires;
//             file I/O and syntax tree manipulation work in atexit context.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 4 variants pass. SwiftSyntax parse, rewrite, and
//         atomic file write all work correctly inside atexit handlers.
//         LIFO ordering confirmed (V3 → V2 → V1).
// Date: 2026-03-03

import Foundation  // FileManager for temp directory and file ops
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Setup

/// Create a temporary Swift source file that we'll rewrite from the atexit handler.
let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("atexit-swiftsyntax-test-\(ProcessInfo.processInfo.processIdentifier)")
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let sourceFile = tempDir.appendingPathComponent("target.swift")
let markerFile = tempDir.appendingPathComponent("marker.txt")

let originalSource = """
func greet() -> String {
    return "hello"
}
"""

try originalSource.write(to: sourceFile, atomically: true, encoding: .utf8)
print("Temp directory: \(tempDir.path)")
print("Source file written: \(sourceFile.path)")

// MARK: - Variant 1: atexit with simple file write (baseline)
// Hypothesis: Basic file I/O works in atexit context
// Result: CONFIRMED — "[V1] PASS — marker file written from atexit"

atexit {
    do {
        try "atexit-fired".write(
            toFile: markerFile.path,
            atomically: true,
            encoding: .utf8
        )
        print("[V1] PASS — marker file written from atexit")
    } catch {
        print("[V1] FAIL — file write error: \(error)")
    }
}

// MARK: - Variant 2: atexit with SwiftSyntax parse
// Hypothesis: SwiftSyntax can parse source code inside atexit handler
// Result: CONFIRMED — "[V2] PASS — SwiftSyntax parsed source, found function decl"

atexit {
    do {
        let source = try String(contentsOfFile: sourceFile.path, encoding: .utf8)
        let parsed = Parser.parse(source: source)
        let hasFunction = parsed.statements.contains { stmt in
            stmt.item.is(FunctionDeclSyntax.self)
        }
        if hasFunction {
            print("[V2] PASS — SwiftSyntax parsed source, found function decl")
        } else {
            print("[V2] FAIL — parsed but no function decl found")
        }
    } catch {
        print("[V2] FAIL — parse error: \(error)")
    }
}

// MARK: - Variant 3: atexit with SwiftSyntax rewrite
// Hypothesis: SwiftSyntax SyntaxRewriter can modify source and write back in atexit
// Result: CONFIRMED — "[V3] PASS — SwiftSyntax rewrote source in atexit: \"hello\" → \"goodbye\""

/// A minimal rewriter that changes the string literal "hello" to "goodbye".
final class StringRewriter: SyntaxRewriter {
    override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
        // Find string segments containing "hello" and replace with "goodbye"
        let newSegments = node.segments.map { segment -> StringLiteralSegmentListSyntax.Element in
            if case .stringSegment(let seg) = segment,
               seg.content.text == "hello" {
                return .stringSegment(
                    seg.with(\.content, .stringSegment("goodbye"))
                )
            }
            return segment
        }
        let newNode = node.with(\.segments, StringLiteralSegmentListSyntax(newSegments))
        return ExprSyntax(newNode)
    }
}

atexit {
    do {
        let source = try String(contentsOfFile: sourceFile.path, encoding: .utf8)
        let parsed = Parser.parse(source: source)
        let rewriter = StringRewriter()
        let rewritten = rewriter.rewrite(parsed)
        let newSource = rewritten.description

        try newSource.write(toFile: sourceFile.path, atomically: true, encoding: .utf8)

        // Verify
        let verification = try String(contentsOfFile: sourceFile.path, encoding: .utf8)
        if verification.contains("goodbye") && !verification.contains("hello") {
            print("[V3] PASS — SwiftSyntax rewrote source in atexit: \"hello\" → \"goodbye\"")
            print("[V3] Rewritten content:")
            print(verification)
        } else {
            print("[V3] FAIL — rewrite did not produce expected content:")
            print(verification)
        }
    } catch {
        print("[V3] FAIL — rewrite error: \(error)")
    }
}

// MARK: - Variant 4: atexit ordering (LIFO verification)
// Hypothesis: atexit handlers fire in LIFO order (V3 before V2 before V1)
// Result: CONFIRMED — output order: V3, V2, V1 (LIFO verified)

// Note: atexit handlers registered above will fire in reverse order:
// V3 (last registered) → V2 → V1 (first registered)
// V3 rewrites "hello" → "goodbye"
// V2 parses (will see the rewritten file if V3 ran first... but they read independently)
// V1 writes marker
// Actually: V2 reads source BEFORE V3 rewrites it (each reads fresh), so V2 sees original.
// The LIFO ordering means V3 fires first, rewrites file, then V2 fires and re-reads.
// So V2 may see the rewritten content. This tests ordering.

print("Setup complete. Exiting to trigger atexit handlers...")
print("Expected atexit order: V3 → V2 → V1 (LIFO)")

// MARK: - Results Summary
// V1: CONFIRMED  — atexit + file write
// V2: CONFIRMED  — atexit + SwiftSyntax parse
// V3: CONFIRMED  — atexit + SwiftSyntax rewrite ("hello" → "goodbye")
// V4: CONFIRMED  — atexit LIFO ordering (V3 → V2 → V1)
