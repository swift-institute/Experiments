// MARK: - For-loop buildArray stack overflow reproduction
// Purpose: Find the nesting depth threshold that causes runtime stack overflow
//          when for-loop iterates over deeply nested view types.
// Hypothesis: There is a nesting depth N where rendering crashes.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Date: 2026-03-17

import RenderingPrimitives
import HTMLRenderable

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Helper: row builder that produces Table>TableBody>TableRow>2xTableDataCell
// Each call adds ~5 levels of generic nesting
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@HTML.Builder
func tableRow(_ label: String, _ value: String) -> some HTML.View {
    Table {
        TableBody {
            TableRow {
                TableDataCell { Strong { Text(value: label) } }
                TableDataCell { Text(value: value) }
            }
        }
    }.css("break-inside:avoid")
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Variant A: 20 rows in a single _Tuple (each is a full table)
// _Tuple<CSSModified<Table<...>>, CSSModified<Table<...>>, ...x20>
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct WideView: HTML.View {
    let n: String
    var body: some HTML.View {
        Section {
            tableRow("A1", n)
            tableRow("A2", n)
            tableRow("A3", n)
            tableRow("A4", n)
            tableRow("A5", n)
            tableRow("A6", n)
            tableRow("A7", n)
            tableRow("A8", n)
            tableRow("A9", n)
            tableRow("A10", n)
            tableRow("A11", n)
            tableRow("A12", n)
            tableRow("A13", n)
            tableRow("A14", n)
            tableRow("A15", n)
            tableRow("A16", n)
            tableRow("A17", n)
            tableRow("A18", n)
            tableRow("A19", n)
            tableRow("A20", n)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Variant B: Multiple sections, each with tables, conditionals, CSS modifiers
// Matches Aandeelhouder structure: personal + registration + 3x mutation
// Each section is a separate @HTML.Builder property returning some HTML.View
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct DeepSectioned: HTML.View {
    let naam: String
    let showExtra: Bool

    var body: some HTML.View {
        Section {
            H3 { Text(value: "TITLE") }.css("text-align:center")
            Paragraph { Text(value: "") }
            sectionA
            sectionB
            sectionC
            sectionD
            sectionE
        }.css("break-before:page")
    }

    @HTML.Builder
    private var sectionA: some HTML.View {
        H3 { Text(value: "Section A") }
        Table {
            TableBody {
                TableRow { TableDataCell { Strong { Text(value: "Name:") } }; TableDataCell { Text(value: naam) } }
                TableRow { TableDataCell { Strong { Text(value: "Addr:") } }; TableDataCell { Text(value: "Street") } }
                TableRow { TableDataCell { Strong { Text(value: "City:") } }; TableDataCell { Text(value: "Amsterdam") } }
                TableRow { TableDataCell { Strong { Text(value: "Zip:") } }; TableDataCell { Text(value: "1000AA") } }
                if showExtra {
                    TableRow { TableDataCell { Strong { Text(value: "Birth:") } }; TableDataCell { Text(value: "City") } }
                }
                if showExtra {
                    TableRow { TableDataCell { Strong { Text(value: "DOB:") } }; TableDataCell { Text(value: "1990") } }
                }
            }
        }.css("break-inside:avoid")
        Paragraph { Text(value: "") }
    }

    @HTML.Builder
    private var sectionB: some HTML.View {
        H3 { Text(value: "Section B") }
        Table {
            TableBody {
                TableRow { TableDataCell { Strong { Text(value: "Act:") } }; TableDataCell { Text(value: "Incorp") } }
                TableRow { TableDataCell { Strong { Text(value: "Notary:") } }; TableDataCell { Text(value: "mr. X") } }
                TableRow { TableDataCell { Strong { Text(value: "Place:") } }; TableDataCell { Text(value: "Utrecht") } }
                TableRow { TableDataCell { Strong { Text(value: "Date:") } }; TableDataCell { Text(value: "2024") } }
                TableRow { TableDataCell { Strong { Text(value: "Ack:") } }; TableDataCell { Text(value: "2024") } }
                TableRow { TableDataCell { Strong { Text(value: "Type:") } }; TableDataCell { Text(value: "common") } }
                TableRow { TableDataCell { Strong { Text(value: "Count:") } }; TableDataCell { Text(value: "128030") } }
                TableRow { TableDataCell { Strong { Text(value: "Nums:") } }; TableDataCell { Text(value: "1-128030") } }
                TableRow { TableDataCell { Strong { Text(value: "Nom/s:") } }; TableDataCell { Text(value: "0.01") } }
                TableRow { TableDataCell { Strong { Text(value: "Nom tot:") } }; TableDataCell { Text(value: "1280") } }
                TableRow { TableDataCell { Strong { Text(value: "Paid/s:") } }; TableDataCell { Text(value: "0.00") } }
                TableRow { TableDataCell { Strong { Text(value: "Paid tot:") } }; TableDataCell { Text(value: "0.00") } }
                if showExtra {
                    TableRow { TableDataCell { Strong { Text(value: "Unpaid:") } }; TableDataCell { Text(value: "Yes") } }
                }
            }
        }.css("break-inside:avoid")
        Paragraph { Text(value: "") }
    }

    @HTML.Builder
    private var sectionC: some HTML.View {
        H3 { Text(value: "Mutations") }
        mutBlock
        mutBlock
        mutBlock
    }

    @HTML.Builder
    private var sectionD: some HTML.View {
        H3 { Text(value: "Signatures") }
        Table {
            TableBody {
                TableRow { TableDataCell { Text(value: "Director:") }; TableDataCell { Text(value: "___________") } }
                TableRow { TableDataCell { Text(value: "Date:") }; TableDataCell { Text(value: "___________") } }
            }
        }.css("break-inside:avoid")
    }

    @HTML.Builder
    private var sectionE: some HTML.View {
        Paragraph { Text(value: "Notes:") }
        Table {
            TableBody {
                TableRow { TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") } }
                TableRow { TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") } }
                TableRow { TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") }; TableDataCell { Text(value: ".") } }
            }
        }
    }

    @HTML.Builder
    private var mutBlock: some HTML.View {
        Table {
            TableBody {
                TableRow {
                    TableDataCell { Strong { Text(value: "Change:") } }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "Date:") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "Act:") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "Notary:") }
                    TableDataCell { Text(value: "") }
                }
            }
        }.css("break-inside:avoid")

        Paragraph { Text(value: "") }

        Table {
            TableBody {
                TableRow {
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "") }
                }
                TableRow {
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "...") }
                    TableDataCell { Text(value: "") }
                }
            }
        }.css("break-inside:avoid")

        Paragraph { Text(value: "Total ..........") }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Test execution
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func testWide() {
    print("Wide (20 table-rows, for-loop x6)...")
    struct C: HTML.View {
        var body: some HTML.View {
            for i in 0..<6 { WideView(n: "\(i)") }
        }
    }
    let r = render(C())
    print("  \(r.count) bytes — OK")
}

func testDeep() {
    print("Deep sectioned (5 sections + 3 mut blocks, for-loop x6)...")
    struct C: HTML.View {
        var body: some HTML.View {
            for i in 0..<6 {
                DeepSectioned(naam: "H\(i)", showExtra: i % 2 == 0)
            }
        }
    }
    let r = render(C())
    print("  \(r.count) bytes — OK")
}

func testDeepMany() {
    print("Deep sectioned (for-loop x20)...")
    struct C: HTML.View {
        var body: some HTML.View {
            for i in 0..<20 {
                DeepSectioned(naam: "H\(i)", showExtra: i % 2 == 0)
            }
        }
    }
    let r = render(C())
    print("  \(r.count) bytes — OK")
}

testWide()
testDeep()
testDeepMany()
print("\nAll passed — could not reproduce stack overflow at this depth.")
print("The real crash likely requires WHATWG element types + CSS modifier chains")
print("which add more generic wrapper layers per element than this simulation.")
