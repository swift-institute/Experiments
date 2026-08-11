// Step 3: Creation only — no property access
import Input_Primitives
import Array_Primitives

print("Creating Array.Dynamic...")
var dynArray = Array<UInt8>.Dynamic()
dynArray.append(0xFF)
print("  OK")

print("Creating Input.Slice (no property access)...")
let slice = Input.Slice(dynArray)
print("  OK — no crash")

print("MemoryLayout...")
print("  size=\(MemoryLayout<Input.Slice<Array<UInt8>.Dynamic>>.size)")

print("PASSED")
