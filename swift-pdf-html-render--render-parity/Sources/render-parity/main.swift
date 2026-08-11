// MARK: - render-parity
// Purpose: Reproduce both failure classes of the institute swift-pdf chain
//          documented in HANDOFF-swift-pdf-render-parity.md against the
//          reference coenttb-html-to-pdf chain it replaced.
// Hypothesis (1, encoding): Swift String containing `€` (U+20AC) and `ë` (U+00EB)
//          produces a PDF whose `/ActualText` marked-content property contains
//          raw UTF-8 bytes (`E2 82 AC`, `C3 AB`) inside literal-string `(...)`
//          syntax, which PDF readers decode as PDFDocEncoding → mojibake
//          (`â‚¬`, `Ã«`) on text extraction. Per ISO 32000-2 §7.9.2.2, text
//          strings MUST be PDFDocEncoding or UTF-16BE with `<FEFF…>` BOM.
// Hypothesis (2, CSS fidelity): The institute pipeline emits per-word `Tj`
//          operators with `0 -13.8 Td` line-break displacements between EVERY
//          whitespace-separated token because CSS `border: none` /
//          `display: flex` / `min-width` / `white-space: normal` modifiers are
//          stubbed (`apply(to:configuration:)` bodies are empty TODOs).
//
// Toolchain: Swift 6.3.1 (default Xcode)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — bytes-on-disk evidence is documented in
//          `swift-foundations/swift-pdf-html-render/Research/pdf-text-encoding-trace.md`
//          (encoding) and `swift-foundations/swift-pdf-html-render/Research/css-fidelity-gap-inventory.md`
//          (CSS). This program produces the same defects on a minimal ≤50-LOC
//          HTML fixture independent of the timekeeping invoice templates.
// Date: 2026-05-11
//
// Usage:
//   cd Experiments/render-parity
//   swift run render-parity         # writes Outputs/render-parity.pdf
//   strings Outputs/render-parity.pdf | head    # see content-stream form
//
// Then inspect with the Python helper documented in
// `pdf-text-encoding-trace.md` to dump the literal-string bytes for `/ActualText`.

import PDF
import Foundation

// MARK: - Minimal HTML fixture

// Two failure classes in ≤50 lines of HTML:
//   1. Currency + diacritic   → encoding bug on /ActualText
//   2. Two-column flex header + inline label/value pairs + bordered table
//                              → CSS fidelity bug
let doc = PDF.Document(
    info: .init(title: "Render parity reproducer"),
    configuration: .init(paperSize: .a4, margins: .init(all: 36)),
    generateOutline: false
) {
    div {
        h1 { "Parity Reproducer" }

        // Two-column flex header (display: flex stubbed → collapses to block)
        div {
            div { strong { "Cliëntnummer: " }; "29IOVCDMKT" }
            div { strong { "Datum: " }; "2026-05-11" }
        }
        .css.display(.flex)

        // Inline label/value pair (white-space stubbed → labels glue to values)
        p {
            span { "tel" }
            " "
            span { "+31 6 43 90 14 29" }
        }

        // Currency value (encoding bug on /ActualText for `€`)
        p { "Totaal: € 150,12" }

        // Bordered table (CSS border stubbed → default heavy border applied)
        table {
            thead {
                tr { th { "Item" }; th { "Bedrag" } }
            }
            tbody {
                tr { td { "Consult" }; td { "€ 150,12" } }
                tr { td { "Reiskosten" }; td { "€ 25,00" } }
            }
        }
        .css.border(width: .px(0), style: .none, color: .gray300)  // intended: no border
    }
}

// MARK: - Materialize and write

let bytes = [UInt8](doc)

let outDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Outputs", isDirectory: true)

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let outURL = outDir.appendingPathComponent("render-parity.pdf")
try Data(bytes).write(to: outURL)

print("Wrote \(bytes.count) bytes to \(outURL.path)")
print("")
print("Inspect with:")
print("  python3 -c \"import re; data = open('\(outURL.path)','rb').read();\\")
print("    [print(repr(m.group(1)[:48])) for m in re.finditer(rb'/ActualText\\\\s*\\\\(((?:\\\\\\\\.|[^\\\\\\\\()])*)\\\\)', data, re.DOTALL)\\")
print("     if any(b > 0x7F for b in m.group(1))]\"")
print("")
print("Expect: bytes starting `E2 82 AC` (UTF-8 €) and `C3 AB` (UTF-8 ë) inside `/ActualText (...)`.")
print("Per ISO 32000-2 §7.9.2.2 these literal strings should be PDFDocEncoding or `<FEFF…>` hex UTF-16BE.")
