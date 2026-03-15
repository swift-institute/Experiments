// Variant: Consumer WITHOUT trait — should NOT have access to .rendered strategy
import Rendering
import Rendering_Test_Support

let text = Text("Hello")
print("Render: \(text.body)")

// This should NOT compile if traits work correctly:
// let strategy: SnapshotStrategy<Text, String> = .rendered
print("TestSnapshotPrimitives is NOT available (no trait)")
