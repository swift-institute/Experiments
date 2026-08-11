# Operator Inventory and Canonical Placement Plan

> Generated: 2026-02-04
> Scope: All packages under `/Users/coen/Developer/swift-primitives/`

---

## Part 1: Raw Inventory Table

### 1. swift-cardinal-primitives

#### Cardinal Primitives Core

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Cardinal.swift` | 86 | `+` | `Cardinal` | `Cardinal` | `Cardinal` | No | Cardinal addition |
| `Cardinal.swift` | 94 | `+=` | `inout Cardinal` | `Cardinal` | `Void` | No | Cardinal compound addition |
| `Cardinal.swift` | 102 | `==` | `Cardinal` | `Cardinal` | `Bool` | No | Cardinal equality |
| `Cardinal.swift` | 109 | `<` | `Cardinal` | `Cardinal` | `Bool` | No | Cardinal less-than |
| `Cardinal.swift` | 114 | `<=` | `Cardinal` | `Cardinal` | `Bool` | No | Cardinal less-or-equal |
| `Cardinal.swift` | 119 | `>` | `Cardinal` | `Cardinal` | `Bool` | No | Cardinal greater-than |
| `Cardinal.swift` | 124 | `>=` | `Cardinal` | `Cardinal` | `Bool` | No | Cardinal greater-or-equal |

#### Cardinal Primitives (Tagged)

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Tagged+Cardinal.swift` | 77 | `+` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Cardinal>` | No | Tagged cardinal addition |
| `Tagged+Cardinal.swift` | 83 | `+=` | `inout Tagged<Tag, Cardinal>` | `Tagged<Tag, Cardinal>` | `Void` | No | Tagged cardinal compound addition |

---

### 2. swift-ordinal-primitives

#### Ordinal Primitives Core

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Ordinal.swift` | 63 | `==` | `Ordinal` | `Ordinal` | `Bool` | No | Ordinal equality |
| `Ordinal.swift` | 70 | `<` | `Ordinal` | `Ordinal` | `Bool` | No | Ordinal less-than |
| `Ordinal.swift` | 75 | `<=` | `Ordinal` | `Ordinal` | `Bool` | No | Ordinal less-or-equal |
| `Ordinal+Cardinal.swift` | 21 | `<` | `Ordinal` | `Cardinal` | `Bool` | No | Cross-type ordinal < cardinal |
| `Ordinal+Cardinal.swift` | 27 | `<=` | `Ordinal` | `Cardinal` | `Bool` | No | Cross-type ordinal <= cardinal |
| `Ordinal+Cardinal.swift` | 33 | `>` | `Ordinal` | `Cardinal` | `Bool` | No | Cross-type ordinal > cardinal |
| `Ordinal+Cardinal.swift` | 39 | `>=` | `Ordinal` | `Cardinal` | `Bool` | No | Cross-type ordinal >= cardinal |
| `Ordinal+Cardinal.swift` | 47 | `<` | `Cardinal` | `Ordinal` | `Bool` | No | Cross-type cardinal < ordinal |
| `Ordinal+Cardinal.swift` | 53 | `<=` | `Cardinal` | `Ordinal` | `Bool` | No | Cross-type cardinal <= ordinal |
| `Ordinal+Cardinal.swift` | 59 | `>` | `Cardinal` | `Ordinal` | `Bool` | No | Cross-type cardinal > ordinal |
| `Ordinal+Cardinal.swift` | 65 | `>=` | `Cardinal` | `Ordinal` | `Bool` | No | Cross-type cardinal >= ordinal |
| `Ordinal+Cardinal.swift` | 76 | `+` | `Ordinal` | `Cardinal` | `Ordinal` | No | Ordinal + cardinal |
| `Ordinal+Cardinal.swift` | 82 | `+` | `Cardinal` | `Ordinal` | `Ordinal` | No | Cardinal + ordinal (commutative) |
| `Ordinal+Cardinal.swift` | 88 | `+=` | `inout Ordinal` | `Cardinal` | `Void` | No | Ordinal += cardinal |
| `Ordinal+Cardinal.swift` | 101 | `%` | `Ordinal` | `Cardinal` | `Ordinal` | No | Ordinal modular projection |

#### Ordinal Primitives (Tagged)

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Tagged+Ordinal.swift` | 93 | `+` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | No | Tagged ordinal + tagged cardinal |
| `Tagged+Ordinal.swift` | 99 | `+=` | `inout Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Void` | No | Tagged ordinal += tagged cardinal |
| `Tagged+Ordinal.swift` | 106 | `+` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Ordinal>` | No | Tagged cardinal + tagged ordinal (commutative) |
| `Tagged+Ordinal.swift` | 123 | `%` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | No | Tagged ordinal modular projection |
| `Tagged+Ordinal.swift` | 141 | `<` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged cross-type ordinal < cardinal |
| `Tagged+Ordinal.swift` | 150 | `<=` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged cross-type ordinal <= cardinal |
| `Tagged+Ordinal.swift` | 159 | `>` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged cross-type ordinal > cardinal |
| `Tagged+Ordinal.swift` | 168 | `>=` | `Tagged<Tag, Ordinal>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged cross-type ordinal >= cardinal |
| `Tagged+Ordinal.swift` | 183 | `<` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | `Bool` | No | Tagged cross-type cardinal < ordinal |
| `Tagged+Ordinal.swift` | 192 | `<=` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | `Bool` | No | Tagged cross-type cardinal <= ordinal |
| `Tagged+Ordinal.swift` | 201 | `>` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | `Bool` | No | Tagged cross-type cardinal > ordinal |
| `Tagged+Ordinal.swift` | 210 | `>=` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Ordinal>` | `Bool` | No | Tagged cross-type cardinal >= ordinal |

---

### 3. swift-affine-primitives

#### Affine Primitives (Bare)

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Affine.Discrete+Arithmetic.swift` | 22 | `+` | `some Ordinal.Protocol` | `Affine.Discrete.Vector` | `Ordinal` | `Ordinal.Error` | Point + vector → point |
| `Affine.Discrete+Arithmetic.swift` | 42 | `+` | `Affine.Discrete.Vector` | `some Ordinal.Protocol` | `Ordinal` | `Ordinal.Error` | Vector + point → point (commutative) |
| `Affine.Discrete+Arithmetic.swift` | 56 | `-` | `some Ordinal.Protocol` | `Affine.Discrete.Vector` | `Ordinal` | `Ordinal.Error` | Point - vector → point |
| `Affine.Discrete+Arithmetic.swift` | 81 | `-` | `some Ordinal.Protocol` | `some Ordinal.Protocol` | `Affine.Discrete.Vector` | `Vector.Error` | Point - point → vector |
| `Affine.Discrete+Arithmetic.swift` | 104 | `+` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | No | Vector + vector |
| `Affine.Discrete+Arithmetic.swift` | 113 | `-` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | No | Vector - vector |
| `Affine.Discrete+Arithmetic.swift` | 122 | `prefix -` | `Affine.Discrete.Vector` | — | `Affine.Discrete.Vector` | No | Vector negation |
| `Affine.Discrete+Arithmetic.swift` | 130 | `+=` | `inout Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Void` | No | Vector compound addition |
| `Affine.Discrete+Arithmetic.swift` | 139 | `-=` | `inout Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Void` | No | Vector compound subtraction |
| `Affine.Discrete+Arithmetic.swift` | 156 | `<` | `Affine.Discrete.Vector` | `some Cardinal.Protocol` | `Bool` | No | Vector < cardinal (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 165 | `<=` | `Affine.Discrete.Vector` | `some Cardinal.Protocol` | `Bool` | No | Vector <= cardinal (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 174 | `>` | `Affine.Discrete.Vector` | `some Cardinal.Protocol` | `Bool` | No | Vector > cardinal (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 183 | `>=` | `Affine.Discrete.Vector` | `some Cardinal.Protocol` | `Bool` | No | Vector >= cardinal (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 194 | `<` | `some Cardinal.Protocol` | `Affine.Discrete.Vector` | `Bool` | No | Cardinal < vector (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 203 | `<=` | `some Cardinal.Protocol` | `Affine.Discrete.Vector` | `Bool` | No | Cardinal <= vector (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 212 | `>` | `some Cardinal.Protocol` | `Affine.Discrete.Vector` | `Bool` | No | Cardinal > vector (disfavored) |
| `Affine.Discrete+Arithmetic.swift` | 221 | `>=` | `some Cardinal.Protocol` | `Affine.Discrete.Vector` | `Bool` | No | Cardinal >= vector (disfavored) |
| `Affine.Discrete.Vector.swift` | 54 | `==` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Bool` | No | Vector equality |
| `Affine.Discrete.Vector.swift` | 59 | `<` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Bool` | No | Vector less-than |
| `Affine.Discrete.Vector.swift` | 64 | `<=` | `Affine.Discrete.Vector` | `Affine.Discrete.Vector` | `Bool` | No | Vector less-or-equal |
| `Affine.Discrete.Ratio+Composition.swift` | 31 | `*` | `Affine.Discrete.Ratio<A,B>` | `Affine.Discrete.Ratio<B,C>` | `Affine.Discrete.Ratio<A,C>` | No | Ratio composition |

#### Affine Primitives (Tagged)

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Tagged+Affine.swift` | 139 | `+` | `O: Ordinal.Protocol` | `Tagged<Tag, Vector>` | `O` | `Ordinal.Error` | Ordinal + tagged vector → ordinal |
| `Tagged+Affine.swift` | 150 | `+` | `Tagged<Tag, Vector>` | `O: Ordinal.Protocol` | `O` | `Ordinal.Error` | Tagged vector + ordinal → ordinal (commutative) |
| `Tagged+Affine.swift` | 161 | `-` | `O: Ordinal.Protocol` | `Tagged<Tag, Vector>` | `O` | `Ordinal.Error` | Ordinal - tagged vector → ordinal |
| `Tagged+Affine.swift` | 176 | `-` | `some Ordinal.Protocol` | `some Ordinal.Protocol` | `Tagged<Tag, Vector>` | `Vector.Error` | Ordinal - ordinal → tagged vector |
| `Tagged+Affine.swift` | 188 | `+` | `Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | No | Tagged vector + tagged vector |
| `Tagged+Affine.swift` | 194 | `-` | `Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | No | Tagged vector - tagged vector |
| `Tagged+Affine.swift` | 200 | `+=` | `inout Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | `Void` | No | Tagged vector compound addition |
| `Tagged+Affine.swift` | 206 | `-=` | `inout Tagged<Tag, Vector>` | `Tagged<Tag, Vector>` | `Void` | No | Tagged vector compound subtraction |
| `Tagged+Affine.swift` | 213 | `prefix -` | `Tagged<Tag, Vector>` | — | `Tagged<Tag, Vector>` | No | Tagged vector negation |
| `Tagged+Affine.swift` | 225 | `+=` | `inout O: Ordinal.Protocol` | `Tagged<Tag, Vector>` | `Void` | `Ordinal.Error` | Ordinal += tagged vector |
| `Tagged+Affine.swift` | 236 | `-=` | `inout O: Ordinal.Protocol` | `Tagged<Tag, Vector>` | `Void` | `Ordinal.Error` | Ordinal -= tagged vector |
| `Tagged+Affine.swift` | 250 | `<` | `Tagged<Tag, Vector>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged vector < tagged cardinal |
| `Tagged+Affine.swift` | 258 | `<=` | `Tagged<Tag, Vector>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged vector <= tagged cardinal |
| `Tagged+Affine.swift` | 266 | `>` | `Tagged<Tag, Vector>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged vector > tagged cardinal |
| `Tagged+Affine.swift` | 274 | `>=` | `Tagged<Tag, Vector>` | `Tagged<Tag, Cardinal>` | `Bool` | No | Tagged vector >= tagged cardinal |
| `Tagged+Affine.swift` | 284 | `<` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Vector>` | `Bool` | No | Tagged cardinal < tagged vector |
| `Tagged+Affine.swift` | 292 | `<=` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Vector>` | `Bool` | No | Tagged cardinal <= tagged vector |
| `Tagged+Affine.swift` | 300 | `>` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Vector>` | `Bool` | No | Tagged cardinal > tagged vector |
| `Tagged+Affine.swift` | 308 | `>=` | `Tagged<Tag, Cardinal>` | `Tagged<Tag, Vector>` | `Bool` | No | Tagged cardinal >= tagged vector |
| `Tagged+Affine.swift` | 324 | `*` | `Tagged<From, Cardinal>` | `Ratio<From, To>` | `Tagged<To, Cardinal>` | No | Tagged cardinal domain scaling |
| `Tagged+Affine.swift` | 335 | `*` | `Ratio<From, To>` | `Tagged<From, Cardinal>` | `Tagged<To, Cardinal>` | No | Ratio * tagged cardinal (commutative) |
| `Tagged+Affine.swift` | 349 | `*` | `Tagged<From, Vector>` | `Ratio<From, To>` | `Tagged<To, Vector>` | No | Tagged vector domain scaling |
| `Tagged+Affine.swift` | 358 | `*` | `Ratio<From, To>` | `Tagged<From, Vector>` | `Tagged<To, Vector>` | No | Ratio * tagged vector (commutative) |

---

### 4. swift-index-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Index+UnsafePointer.swift` | 19 | `+` | `UnsafePointer<Pointee>` | `Index<Pointee>.Count` | `UnsafePointer<Pointee>` | No | Pointer + tagged count |
| `Index+UnsafePointer.swift` | 28 | `+` | `Index<Pointee>.Count` | `UnsafePointer<Pointee>` | `UnsafePointer<Pointee>` | No | Tagged count + pointer (commutative) |
| `Index+UnsafePointer.swift` | 37 | `-` | `UnsafePointer<Pointee>` | `Index<Pointee>.Count` | `UnsafePointer<Pointee>` | No | Pointer - tagged count |
| `Index+UnsafePointer.swift` | 46 | `-` | `UnsafePointer<Pointee>` | `UnsafePointer<Pointee>` | `Index<Pointee>.Offset` | No | Pointer - pointer → tagged offset |
| `Index+UnsafeMutablePointer.swift` | 19 | `+` | `UnsafeMutablePointer<Pointee>` | `Index<Pointee>.Count` | `UnsafeMutablePointer<Pointee>` | No | Mutable pointer + tagged count |
| `Index+UnsafeMutablePointer.swift` | 28 | `+` | `Index<Pointee>.Count` | `UnsafeMutablePointer<Pointee>` | `UnsafeMutablePointer<Pointee>` | No | Tagged count + mutable pointer (commutative) |
| `Index+UnsafeMutablePointer.swift` | 37 | `-` | `UnsafeMutablePointer<Pointee>` | `Index<Pointee>.Count` | `UnsafeMutablePointer<Pointee>` | No | Mutable pointer - tagged count |
| `Index+UnsafeMutablePointer.swift` | 46 | `-` | `UnsafeMutablePointer<Pointee>` | `UnsafeMutablePointer<Pointee>` | `Index<Pointee>.Offset` | No | Mutable pointer - pointer → tagged offset |

---

### 5. swift-memory-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Memory.Alignment.swift` | 187 | `<` | `Memory.Alignment` | `Memory.Alignment` | `Bool` | No | Alignment comparison |
| `Memory.Shift.swift` | 165 | `<` | `Memory.Shift` | `Memory.Shift` | `Bool` | No | Shift comparison |
| `Memory.Shift.swift` | 177 | `+` | `Memory.Shift` | `Memory.Shift` | `Memory.Shift` | No | Shift addition |
| `Memory.Shift.swift` | 189 | `-` | `Memory.Shift` | `Memory.Shift` | `Memory.Shift` | No | Shift subtraction |
| `Memory.Buffer.swift` | 259 | `==` | `Memory.Buffer` | `Memory.Buffer` | `Bool` | No | Buffer equality |
| `Memory.Buffer.Mutable.swift` | 351 | `==` | `Memory.Buffer.Mutable` | `Memory.Buffer.Mutable` | `Bool` | No | Mutable buffer equality |

---

### 6. swift-binary-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Binary.Optionator.swift` | 14 | `prefix -?` | `T: FixedWidthInteger` | — | `T?` | No | Optional negation |
| `Binary.Optionator.swift` | 22 | `+?` | `T: FixedWidthInteger` | `T` | `T?` | No | Optional addition |
| `Binary.Optionator.swift` | 29 | `-?` | `T: FixedWidthInteger` | `T` | `T?` | No | Optional subtraction |
| `Binary.Optionator.swift` | 36 | `*?` | `T: FixedWidthInteger` | `T` | `T?` | No | Optional multiplication |
| `Binary.Optionator.swift` | 43 | `/?` | `T: FixedWidthInteger` | `T` | `T?` | No | Optional division |
| `Binary.Optionator.swift` | 50 | `%?` | `T: FixedWidthInteger` | `T` | `T?` | No | Optional modulo |
| `Binary.Optionator.swift` | 55 | `+?=` | `inout T?` | `T` | `Void` | No | Optional compound addition |
| `Binary.Optionator.swift` | 58 | `-?=` | `inout T?` | `T` | `Void` | No | Optional compound subtraction |
| `Binary.Optionator.swift` | 61 | `*?=` | `inout T?` | `T` | `Void` | No | Optional compound multiplication |
| `Binary.Optionator.swift` | 64 | `/?=` | `inout T?` | `T` | `Void` | No | Optional compound division |
| `Binary.Optionator.swift` | 67 | `%?=` | `inout T?` | `T` | `Void` | No | Optional compound modulo |
| `Binary.Optionator.swift` | 76 | `..<? ` | `T: Comparable` | `T` | `Range<T>?` | No | Optional range formation |
| `Binary.Optionator.swift` | 83 | `...?` | `T: Comparable` | `T` | `ClosedRange<T>?` | No | Optional closed range formation |

---

### 7. swift-equation-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Equation.Protocol.swift` | 49 | `==` | `borrowing Self` | `borrowing Self` | `Bool` | No | Equation protocol requirement |
| `Equation.Protocol.swift` | 66 | `!=` | `borrowing Self` | `borrowing Self` | `Bool` | No | Equation protocol default impl |
| `Equation.Protocol+Identity.Tagged.swift` | 16 | `==` | `Tagged` | `Tagged` | `Bool` | No | Tagged identity equality |
| Various stdlib integration files | — | `==` | stdlib types | stdlib types | `Bool` | No | ~17 stdlib Equation conformances |

---

### 8. swift-comparison-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Comparison.Protocol.swift` | 51 | `<` | `borrowing Self` | `borrowing Self` | `Bool` | No | Comparison protocol requirement |
| `Comparison.Protocol.swift` | 64 | `<=` | `borrowing Self` | `borrowing Self` | `Bool` | No | Comparison protocol default impl |
| `Comparison.Protocol.swift` | 74 | `>` | `borrowing Self` | `borrowing Self` | `Bool` | No | Comparison protocol default impl |
| `Comparison.Protocol.swift` | 84 | `>=` | `borrowing Self` | `borrowing Self` | `Bool` | No | Comparison protocol default impl |
| `Comparison.Protocol+Identity.Tagged.swift` | 16 | `<` | `Tagged` | `Tagged` | `Bool` | No | Tagged identity comparison |
| Various stdlib integration files | — | `<` | stdlib types | stdlib types | `Bool` | No | ~15 stdlib Comparison conformances |

---

### 9. swift-tagged-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Tagged.swift` | 85 | `<` | `Tagged` | `Tagged` | `Bool` | No | Tagged identity comparison |

---

### 10. swift-algebra-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Algebra.Z+Arithmetic.swift` | 27 | `+` | `Self` (Algebra.Z) | `Self` | `Self` | No | Integer algebra addition |
| `Algebra.Z+Arithmetic.swift` | 36 | `+=` | `inout Self` | `Self` | `Void` | No | Integer algebra compound addition |
| `Algebra.Z+Arithmetic.swift` | 45 | `-` | `Self` | `Self` | `Self` | No | Integer algebra subtraction |
| `Algebra.Z+Arithmetic.swift` | 53 | `-=` | `inout Self` | `Self` | `Void` | No | Integer algebra compound subtraction |
| `Algebra.Z+Arithmetic.swift` | 62 | `prefix -` | `Self` | — | `Self` | No | Integer algebra negation |
| `Algebra.Z+Arithmetic.swift` | 71 | `*` | `Self` | `Self` | `Self` | `Error` | Integer algebra multiplication (typed throws) |
| `Algebra.Z+Arithmetic.swift` | 80 | `*=` | `inout Self` | `Self` | `Void` | `Error` | Integer algebra compound multiplication |
| `Sign.swift` | 49 | `prefix -` | `Sign` | — | `Sign` | No | Sign negation |
| `Ternary.swift` | 49 | `prefix -` | `Ternary` | — | `Ternary` | No | Ternary negation |
| `Product.swift` | 50 | `==` | `Product` | `Product` | `Bool` | No | Product equality |
| `Bool+XOR.swift` | 26 | `^` | `Bool` | `Bool` | `Bool` | No | Bool XOR |

---

### 11. swift-algebra-linear-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Linear+Arithmatic.swift` | 14 | `*` | `Linear.Vector` | `Scale<1>` | `Linear.Vector` | No | Vector uniform scaling |
| `Linear+Arithmatic.swift` | 24 | `*` | `Scale<1>` | `Linear.Vector` | `Linear.Vector` | No | Scale * vector (commutative) |
| `Linear+Arithmatic.swift` | 34 | `/` | `Linear.Vector` | `Scale<1>` | `Linear.Vector` | No | Vector uniform division |
| `Linear+Arithmatic.swift` | 56 | `*` | `Linear.Matrix` | `Linear.Vector` | `Linear.Vector` | No | Matrix-vector multiplication |
| `Linear+Arithmatic.swift` | 93 | `*` | `Linear.Matrix<R,C>` | `Linear.Matrix<C,P>` | `Linear.Matrix<R,P>` | No | Matrix-matrix multiplication |
| `Linear+Arithmatic.swift` | 126 | `*` | `Linear.Matrix<2,2>` | `Linear.Vector<2>` | `Linear.Vector<2>` | No | 2x2 matrix * typed vector |
| `Linear+Arithmatic.swift` | 141 | `*` (internal) | `Linear.Vector` | `Scalar` | `Linear.Vector` | No | Vector scalar multiplication |
| `Linear+Arithmatic.swift` | 151 | `/` (internal) | `Linear.Vector` | `Scalar` | `Linear.Vector` | No | Vector scalar division |
| `Linear+Arithmatic.swift` | 165 | `prefix -` | `Linear.Matrix` | — | `Linear.Matrix` | No | Matrix negation |
| `Linear+Arithmatic.swift` | 181 | `+` | `Linear.Matrix` | `Linear.Matrix` | `Linear.Matrix` | No | Matrix addition |
| `Linear+Arithmatic.swift` | 193 | `-` | `Linear.Matrix` | `Linear.Matrix` | `Linear.Matrix` | No | Matrix subtraction |
| `Linear+Arithmatic.swift` | 210 | `prefix -` | `Linear.Vector` | — | `Linear.Vector` | No | Vector negation |
| `Linear+Arithmatic.swift` | 225 | `+` | `Linear.Vector` | `Linear.Vector` | `Linear.Vector` | No | Vector addition |
| `Linear+Arithmatic.swift` | 236 | `-` | `Linear.Vector` | `Linear.Vector` | `Linear.Vector` | No | Vector subtraction |
| `Linear.Matrix.swift` | 55 | `==` | `Linear.Matrix` | `Linear.Matrix` | `Bool` | No | Matrix equality |
| `Linear.Vector.swift` | 48 | `==` | `Linear.Vector` | `Linear.Vector` | `Bool` | No | Vector equality |

---

### 12. swift-time-primitives

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Instant.swift` | 87 | `<` | `Instant` | `Instant` | `Bool` | No | Instant comparison |
| `Instant.swift` | 109 | `+` | `Instant` | `Duration` | `Instant` | No | Instant + duration (affine) |
| `Instant.swift` | 150 | `-` | `Instant` | `Duration` | `Instant` | No | Instant - duration (affine) |
| `Instant.swift` | 189 | `-` | `Instant` | `Instant` | `Duration` | No | Instant - instant → duration (affine) |
| Various time unit files | — | `<` | `Time.X` | `Time.X` | `Bool` | No | ~14 time unit comparisons (Second, Year, Month.Day, etc.) |
| `Time.Month.Day.swift` | 71, 76 | `==` | `Time.Month.Day` / `Int` | `Int` / `Time.Month.Day` | `Bool` | No | Cross-type month-day equality |
| `Time.Month.swift` | 78, 83 | `==` | `Time.Month` / `Int` | `Int` / `Time.Month` | `Bool` | No | Cross-type month equality |

---

### 13. swift-dimension-primitives

#### Bare types

| File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category |
|------|------|----------|----------|----------|-------------|--------|-------------------|
| `Degree.swift` | 251–286 | `+`, `-`, `*`, `/`, `prefix -` | `Degree` | `Degree`/`RawValue` | `Degree` | No | Degree arithmetic (6 operators) |
| `Radian.swift` | 117–152 | `+`, `-`, `*`, `/`, `prefix -` | `Radian` | `Radian`/`RawValue` | `Radian` | No | Radian arithmetic (6 operators) |
| `Interval.Unit.swift` | 117–221 | `==`, `<`, `*`, `*=` | `Interval.Unit` | `Interval.Unit` | varies | No | Interval unit ops (4 operators) |
| `Scale.swift` | 34–57 | `==`, `<` | `Scale` | `Scale` | `Bool` | No | Scale comparison (2 operators) |
| `Dimension+Arithmatic.swift` | 8 | `prefix -` | `Scale<N>` | — | `Scale<N>` | No | N-dim scale negation |

#### Tagged types (~200 operators in `Tagged+Arithmatic.swift`)

| Category | Approximate Count | Lines | Description |
|----------|-------------------|-------|-------------|
| Tagged prefix negation | 1 | ~56 | `prefix - (Tagged where RawValue: SignedNumeric)` |
| Angle * Scale, / Scale | 6 | 89–138 | Radian/Degree angle scaling by `Scale<1>` |
| Displacement ± (same axis) | 6 | 145–195 | X/Y/Z displacement same-type add/sub |
| Magnitude ± | 6 | 200–233 | Magnitude add/sub + compound assignment |
| Extent ± (same axis) | 12 | 239–343 | X/Y/Z extent add/sub + compound assignment |
| Cross-axis extent comparisons | 10 | 352–418 | Width < Height, Height > Width, etc. |
| Angle same-type ± | 4 | 424–456 | Radian/degree addition/subtraction |
| Displacement * Displacement → Area | 9 | 466–543 | All axis combinations producing Area |
| Extent * Extent → Area | 9 | 553–630 | All axis combinations producing Area |
| Measure * Measure (length*area=volume) | 3 | 636–659 | Dimensional measure multiplication |
| Area ± | 2 | 665–679 | Area addition/subtraction |
| Measure * Scale, / Scale | 3 | 685–708 | Measure scaled by `Scale<1>` |
| Area / Magnitude = Magnitude | 1 | 714–719 | Area divided by magnitude |
| Area / Area = Scale | 1 | 724–729 | Area ratio |
| Displacement / Displacement = Scale | 3 | 735–757 | Displacement ratio (X, Y, Z) |
| Coordinate ± Displacement | 36 | 770–997 | Affine: Coord+Disp=Coord, Coord-Coord=Disp |
| Magnitude + Coordinate | 24 | 1008–1174 | Magnitude added/subtracted from coordinates |
| Extent + Coordinate | 24 | 1185–1351 | Extent added/subtracted from coordinates |
| Displacement * Scale, / Scale | 18 | 1364–1534 | Displacement uniform scaling (X/Y/Z, ±quantization) |
| Extent * Scale, / Scale | 18 | 1541–1711 | Extent uniform scaling (X/Y/Z, ±quantization) |
| Magnitude * Scale, / Scale | 6 | 1718–1770 | Magnitude uniform scaling |
| Scale arithmetic | 4 | 1778–1810 | Scale +, -, *, / |
| Scale prefix negation | 1 | 1828 | `prefix - <Scalar>(Scale<1, Scalar>)` |

| `Tagged+Quantized.swift` | 62, 68 | `==`, `!=` | Tagged quantized | Tagged quantized | `Bool` | No | Quantized tagged equality |

---

### 14. swift-geometry-primitives

| File | Lines | Operators | Description |
|------|-------|-----------|-------------|
| `Geometry+Arithmatic.swift` | 16–84 | `*`, `/` (6 ops) | Size scaling by Scale |
| `Geometry+Arithmatic.swift` | 91–93 | `prefix -` | Depth negation |
| `Geometry+Arithmatic.swift` | 99–115 | `+`, `-`, `<` | Depth arithmetic + comparison |
| `Geometry+Arithmatic.swift` | 124–159 | `+`, `-`, `prefix -` | EdgeInsets arithmetic |
| `Geometry+Arithmatic.swift` | 166–198 | `+`, `-`, `prefix -` | Size arithmetic |
| `Geometry+Arithmatic.swift` | 209–240 | `/` (3 ops) | Height/Width/Magnitude ratio → Scale |
| `Geometry+Arithmatic.swift` | 247–400 | `+`, `-`, `*` variants | Height/Width add/sub and scaling (~20 ops) |
| `Geometry.swift` | 158 | `<` | Geometry comparison |
| `Geometry.Size.swift` | 41 | `==` | Size equality |
| `Geometry.Ngon.swift` | 50, 178 | `==` (2) | Polygon equality |

---

### 15. swift-complex-primitives

| File | Operators | Count | Description |
|------|-----------|-------|-------------|
| `Complex.Real+Arithmetic.swift` | `+`, `-`, `*`, `/`, `+=`, `-=`, `*=`, `/=`, `prefix -` | 9 | Real part full arithmetic |
| `Complex.Imaginary+Arithmetic.swift` | `+`, `-`, `prefix -`, `+=`, `-=`, `*`, `/` | 7 | Imaginary part arithmetic |
| `Complex+Arithmetic.swift` | Full suite with Self, Real, Imaginary | ~20 | Complex number arithmetic |
| `Complex+Equatable.swift` | `==` | 1 | Complex equality |
| `Complex.Modulus.swift` | `+`, `-`, `*`, `/` | 4 | Modulus arithmetic |
| `Complex.Real+Imaginary.swift` | 16 cross-type ops | 16 | Real-Imaginary cross arithmetic |
| `Complex.Real.swift` | `<` | 1 | Real comparison |

---

### 16. swift-logic-primitives

| File | Line | Operator | Semantic Category |
|------|------|----------|-------------------|
| `Logic.Ternary.swift` | 115 | `&&` | Ternary logic AND |
| `Logic.Ternary.swift` | 165 | `\|\|` | Ternary logic OR |
| `Logic.Ternary.swift` | 211 | `prefix !` | Ternary logic NOT |
| `Logic.Ternary.swift` | 248 | `^` | Ternary logic XOR |
| `Logic.Ternary.swift` | 295 | `!&&` (custom) | Ternary logic NAND |
| `Logic.Ternary.swift` | 350 | `!\|\|` (custom) | Ternary logic NOR |
| `Logic.Ternary.swift` | 398 | `!^` (custom) | Ternary logic XNOR |

---

### 17. swift-predicate-primitives

| File | Operators | Count | Description |
|------|-----------|-------|-------------|
| `Predicate.swift` | `&&`, `\|\|`, `^` | 3 | Predicate boolean algebra |
| `(T) to Bool.swift` | `&&`, `\|\|`, `^`, `prefix !` + mixed overloads | 7 | Predicate-closure composition |

---

### 18. swift-bit-primitives

| File | Line | Operator | Semantic Category |
|------|------|----------|-------------------|
| `Bitwise Operators.swift` | 11 | `^` | Bit XOR |
| `Bitwise Operators.swift` | 17 | `&` | Bit AND |
| `Bitwise Operators.swift` | 23 | `\|` | Bit OR |
| `Bit+Comparable.swift` | 8 | `<` | Bit comparison |
| `Bit+Normalizing.swift` | 18 | `^` (Bit, UInt8) | Bit XOR with UInt8 |

---

### 19. swift-optic-primitives

| File | Lines | Operators | Description |
|------|-------|-----------|-------------|
| `Optic.Operators.swift` | 41–193 | `>>>` (16 overloads) | Iso/Lens/Prism/Affine composition |
| `Optic.Prism.swift` | 225 | `~=` | Pattern matching |

---

### 20. swift-kernel-primitives

| Category | Count | Description |
|----------|-------|-------------|
| `Block` arithmetic | 2 | `+`, `-` on `Kernel.File.System.Block` |
| `File.Offset` arithmetic | 4 | `+`, `+=`, `-`, `-=` for `Offset + Size` |
| Permission bitwise | 3 | `\|`, `\|=`, `&` on `Kernel.File.Permissions` |
| Memory map flags | 3 | `\|` on Map.Flags, Protection, Sync.Flags |
| Event flags | 1 | `\|` on Event.Descriptor.Flags |
| Comparisons | 2 | `<` on Deadline, Counter |
| Error equality | 8 | `==` on various error types |

---

### 21. swift-darwin-primitives

| File | Operator | Description |
|------|----------|-------------|
| `Darwin.Kernel.Kqueue.Filter.Flags.swift` | `\|` | Kqueue filter flags OR |
| `Darwin.Kernel.Kqueue.Flags.swift` | `\|` | Kqueue flags OR |
| `Darwin.Loader.Image.Header.swift` | `==` | Image header equality |

---

### 22. swift-cyclic-primitives

| File | Operators | Description |
|------|-----------|-------------|
| `Cyclic.Group.Static+Arithmetic.swift` | `+`, `-`, `+=`, `-=` | Cyclic group arithmetic |
| `Cyclic.Group.Static.swift` | `==`, `<`, `<=`, `>`, `>=` | Cyclic group comparison |
| `Cyclic.Group.Element.swift` | `==`, `<` | Cyclic element comparison |

---

### 23. swift-decimal-primitives

| File | Operators | Description |
|------|-----------|-------------|
| `Decimal.Exponent.swift` | `<`, `+`, `-`, `+(Int)`, `-(Int)`, `prefix -` | Exponent arithmetic (6 ops) |
| `Decimal.Precision.swift` | `<`, `+`, `-`, `+(Int)`, `-(Int)` | Precision arithmetic (5 ops) |

---

### 24. swift-range-primitives

| File | Operator | Description |
|------|----------|-------------|
| `Index.Count+Range.Lazy.swift` | `..<` | `Index<Tag> ..< Index<Tag>.Count → Range.Lazy<Index<Tag>>` |

---

### 25. Collection data structure packages

These packages implement `==` and `<` for their data structures. No duplication with the cardinal/ordinal/affine system.

| Package | Operators | Types |
|---------|-----------|-------|
| swift-queue-primitives | `==` (3), `<` (4 Checkpoint) | Queue, Queue.Linked, Queue.DoubleEnded, Checkpoint |
| swift-set-primitives | `==` (5) | Set.Ordered, Set.Bit.Vector variants |
| swift-deque-primitives | `==` (1), `<` (2 Checkpoint) | Deque, Checkpoint |
| swift-heap-primitives | `==` (2) | Heap, Heap.MinMax |
| swift-list-primitives | `==` (2) | List.Linked, List.Linked.Bounded |
| swift-dictionary-primitives | `==` (2) | Dictionary.Ordered |
| swift-array-primitives | `==` (3) | Array.Bit.Vector variants |
| swift-vector-primitives | `==` (2) | Vector, Vector.Inline |
| swift-infinite-primitives | `==` (2) | Infinite.Repeat, Infinite.Cycle |

---

### 26. Other packages

| Package | Operators | Description |
|---------|-----------|-------------|
| swift-clock-primitives | `<` (6), `==` (1) | Clock instant comparison |
| swift-x86-primitives | `<` (3) | Register, Leaf, Subleaf comparison |
| swift-arm-primitives | `<` (1) | ARM counter comparison |
| swift-cpu-primitives | `<` (1) | Checksum comparison |
| swift-linux-primitives | `<` (1) | IO priority comparison |
| swift-parser-primitives | `==`, `<` | Parser type comparison |
| swift-loader-primitives | `==` (3) | Library.Handle, Section.Name, Symbol.Scope |
| swift-symmetry-primitives | `==` (2) | Rotation, Shear |
| swift-standard-library-extensions | `==`, `<` | String subtype comparison |
| swift-test-primitives | `+`, `+=`, `<` (3) | Test.Text concat + comparisons |

---

### Grand Totals

| Category | Approximate Count |
|----------|-------------------|
| Arithmetic (`+`, `-`, `*`, `/`, `%`) | ~210 |
| Comparison (`==`, `!=`, `<`, `<=`, `>`, `>=`) | ~125 |
| Compound assignment (`+=`, `-=`, `*=`, `/=`, `%=`) | ~35 |
| Prefix negation (`prefix -`) | ~21 |
| Bitwise (`&`, `\|`, `^`, `&=`, `\|=`, `^=`) | ~30 |
| Logical (`&&`, `\|\|`, `!`, `^`, `!&&`, `!\|\|`, `!^`) | ~15 |
| Custom operators (`+?`, `-?`, `*?`, `/?`, `%?`, `..<`, `..<? `, `...?`, `>>>`, `~=`) | ~35 |
| **TOTAL** | **~470** |

---

## Part 2: Duplication Analysis

The following groups contain semantic duplicates — pairs where one operates on bare types and the other on `Tagged<_, _>` wrappers, with structurally identical implementations (just wrapping/unwrapping).

### Group A: Cardinal Addition

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| A1 | `Cardinal.swift:86` | `Cardinal + Cardinal → Cardinal` | Bare |
| A2 | `Tagged+Cardinal.swift:77` | `Tagged<Tag, Cardinal> + Tagged<Tag, Cardinal> → Tagged<Tag, Cardinal>` | Tagged |

**Pattern**: A2 delegates to A1 via `Self(lhs.rawValue + rhs.rawValue)`. The `+` on rawValue calls A1.

**Can unify?** Yes, via `Cardinal.Protocol`. A single generic operator `func + <C: Cardinal.Protocol>(lhs: C, rhs: C) -> C` could replace both, using `C(cardinal: Cardinal(lhs.cardinal.rawValue + rhs.cardinal.rawValue))`. However, the bare version currently uses `addingReportingOverflow` with a precondition, so the generic version would need to preserve that.

**Corresponding compound assignment:**

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| A3 | `Cardinal.swift:94` | `Cardinal += Cardinal` | Bare |
| A4 | `Tagged+Cardinal.swift:83` | `Tagged<Tag, Cardinal> += Tagged<Tag, Cardinal>` | Tagged |

---

### Group B: Ordinal + Cardinal → Ordinal

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| B1 | `Ordinal+Cardinal.swift:76` | `Ordinal + Cardinal → Ordinal` | Bare |
| B2 | `Tagged+Ordinal.swift:93` | `Tagged<Tag, Ordinal> + Tagged<Tag, Cardinal> → Tagged<Tag, Ordinal>` | Tagged |
| B3 | `Ordinal+Cardinal.swift:82` | `Cardinal + Ordinal → Ordinal` (commutative) | Bare |
| B4 | `Tagged+Ordinal.swift:106` | `Tagged<Tag, Cardinal> + Tagged<Tag, Ordinal> → Tagged<Tag, Ordinal>` (commutative) | Tagged |

**Pattern**: B2 delegates: `Self(__unchecked: (), lhs.rawValue + rhs.rawValue)`, which calls B1. B4 calls `rhs + lhs` which calls B2.

**Can unify?** Partially — but the return type changes with tagging (bare returns `Ordinal`, tagged returns `Tagged<Tag, Ordinal>`). A fully generic version would need both `Ordinal.Protocol` and `Cardinal.Protocol`, returning `O` where `O: Ordinal.Protocol`. This is already partially done in `Affine.Discrete+Arithmetic.swift` where `some Ordinal.Protocol` is used.

**Corresponding compound assignment and modular projection:**

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| B5 | `Ordinal+Cardinal.swift:88` | `Ordinal += Cardinal` | Bare |
| B6 | `Tagged+Ordinal.swift:99` | `Tagged<Tag, Ordinal> += Tagged<Tag, Cardinal>` | Tagged |
| B7 | `Ordinal+Cardinal.swift:101` | `Ordinal % Cardinal → Ordinal` | Bare |
| B8 | `Tagged+Ordinal.swift:123` | `Tagged<Tag, Ordinal> % Tagged<Tag, Cardinal> → Tagged<Tag, Ordinal>` | Tagged |

---

### Group C: Ordinal ↔ Cardinal Cross-Type Comparisons

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| C1–C8 | `Ordinal+Cardinal.swift:21–65` | `Ordinal </>/<=/>=` Cardinal (8 ops, both directions) | Bare |
| C9–C16 | `Tagged+Ordinal.swift:141–214` | `Tagged<Tag, Ordinal> </>/<=/>=` Tagged<Tag, Cardinal> (8 ops, both directions) | Tagged |

**Pattern**: C9–C16 delegate directly: `lhs.rawValue < rhs.rawValue`, which invokes C1–C8.

**Can unify?** Yes, via `Ordinal.Protocol` and `Cardinal.Protocol`. A single set of 8 generic operators:
```
func < <O: Ordinal.Protocol, C: Cardinal.Protocol>(lhs: O, rhs: C) -> Bool
```
would replace all 16 operators (bare + tagged).

---

### Group D: Affine Point ± Vector Operations

The affine operators in `Affine.Discrete+Arithmetic.swift` already use `some Ordinal.Protocol` on the bare vector type. The tagged versions in `Tagged+Affine.swift` re-dispatch through `Tagged<Tag, Vector>`.

| # | Bare Location | Tagged Location | Semantic |
|---|---------------|-----------------|----------|
| D1/D2 | `Affine.Discrete+Arithmetic.swift:22` | `Tagged+Affine.swift:139` | `Ordinal.Protocol + Vector → Ordinal` / `Ordinal.Protocol + Tagged<Tag, Vector> → O` |
| D3/D4 | `Affine.Discrete+Arithmetic.swift:42` | `Tagged+Affine.swift:150` | Commutative variant |
| D5/D6 | `Affine.Discrete+Arithmetic.swift:56` | `Tagged+Affine.swift:161` | `Ordinal.Protocol - Vector → Ordinal` / `O - Tagged<Tag, Vector> → O` |
| D7/D8 | `Affine.Discrete+Arithmetic.swift:81` | `Tagged+Affine.swift:176` | `Ordinal.Protocol - Ordinal.Protocol → Vector` / `→ Tagged<Tag, Vector>` |

**Pattern**: The tagged versions delegate to the bare versions: `O(try lhs.ordinal + rhs.rawValue)`. The structure is wrap → delegate to bare → re-wrap.

**Can unify?** Only if `Affine.Discrete.Vector.Protocol` existed. With a protocol abstracting over `Vector` and `Tagged<_, Vector>`, a single generic `func + <O: Ordinal.Protocol, V: Vector.Protocol>` could replace both. **This is the key motivation for creating `Affine.Discrete.Vector.Protocol`.**

---

### Group E: Vector ± Vector

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| E1 | `Affine.Discrete+Arithmetic.swift:104` | `Vector + Vector → Vector` | Bare |
| E2 | `Tagged+Affine.swift:188` | `Tagged<Tag, Vector> + Tagged<Tag, Vector> → Tagged<Tag, Vector>` | Tagged |
| E3 | `Affine.Discrete+Arithmetic.swift:113` | `Vector - Vector → Vector` | Bare |
| E4 | `Tagged+Affine.swift:194` | `Tagged<Tag, Vector> - Tagged<Tag, Vector> → Tagged<Tag, Vector>` | Tagged |
| E5 | `Affine.Discrete+Arithmetic.swift:122` | `prefix - Vector` | Bare |
| E6 | `Tagged+Affine.swift:213` | `prefix - Tagged<Tag, Vector>` | Tagged |
| E7 | `Affine.Discrete+Arithmetic.swift:130` | `Vector += Vector` | Bare |
| E8 | `Tagged+Affine.swift:200` | `Tagged<Tag, Vector> += Tagged<Tag, Vector>` | Tagged |
| E9 | `Affine.Discrete+Arithmetic.swift:139` | `Vector -= Vector` | Bare |
| E10 | `Tagged+Affine.swift:206` | `Tagged<Tag, Vector> -= Tagged<Tag, Vector>` | Tagged |

**Can unify?** Yes, via `Affine.Discrete.Vector.Protocol`. Each tagged version wraps/unwraps and delegates to the bare operation.

---

### Group F: Vector ↔ Cardinal Cross-Type Comparisons

| # | Location | Signature | Type Domain |
|---|----------|-----------|-------------|
| F1–F8 | `Affine.Discrete+Arithmetic.swift:156–225` | `Vector </>/<=/>=` `some Cardinal.Protocol` (8 ops) | Bare (already generic over `Cardinal.Protocol`) |
| F9–F16 | `Tagged+Affine.swift:250–312` | `Tagged<Tag, Vector> </>/<=/>=` `Tagged<Tag, Cardinal>` (8 ops) | Tagged |

**Pattern**: F9–F16 delegate: `lhs.rawValue < rhs.rawValue`, which invokes F1–F8.

**Can unify?** Yes, via `Affine.Discrete.Vector.Protocol`. Since the bare versions already take `some Cardinal.Protocol`, adding `some Vector.Protocol` on the other side would unify all 16 into 8 generic operators.

---

### Summary of Duplicated Groups

| Group | Semantic | Bare Count | Tagged Count | Total | Can Unify Via |
|-------|----------|------------|--------------|-------|---------------|
| A | Cardinal + Cardinal | 2 | 2 | 4 | `Cardinal.Protocol` |
| B | Ordinal + Cardinal | 4 | 4 | 8 | `Ordinal.Protocol` + `Cardinal.Protocol` |
| C | Ordinal ↔ Cardinal comparisons | 8 | 8 | 16 | `Ordinal.Protocol` + `Cardinal.Protocol` |
| D | Point ± Vector (affine) | 4 | 4 | 8 | `Ordinal.Protocol` + `Vector.Protocol` |
| E | Vector ± Vector | 5 | 5 | 10 | `Vector.Protocol` |
| F | Vector ↔ Cardinal comparisons | 8 | 8 | 16 | `Vector.Protocol` + `Cardinal.Protocol` |
| **Total** | | **31** | **31** | **62** | |

After unification: **31 operators** instead of 62.

---

## Part 3: Canonical Placement Plan

### 3.1. `Affine.Discrete.Vector.Protocol` — Needs to be Created

**Status**: NOT YET CREATED (as noted in the experiment prompt).

**Definition location**: `swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete.Vector.Protocol.swift`

**Signature** (following the pattern of `Cardinal.Protocol` and `Ordinal.Protocol`):

```swift
extension Affine.Discrete.Vector {
    public protocol `Protocol` {
        var vector: Affine.Discrete.Vector { get }
        init(_ vector: Affine.Discrete.Vector)
    }
}
```

**Conformances**:

1. `Affine.Discrete.Vector: Affine.Discrete.Vector.Protocol` — identity self-conformance
2. `Tagged: Affine.Discrete.Vector.Protocol where RawValue == Affine.Discrete.Vector, Tag: ~Copyable` — phantom-typed conformance

**File**: One type per file → `Affine.Discrete.Vector.Protocol.swift`

---

### 3.2. Group A: Cardinal Addition → Unify via `Cardinal.Protocol`

**Canonical definition** (in `swift-cardinal-primitives`):
```swift
extension Cardinal.Protocol {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs.cardinal + rhs.cardinal)  // delegates to Cardinal + Cardinal
    }
    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
}
```

**Where it should live**: `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol+Arithmetic.swift`

**Note**: The existing bare `Cardinal.+` uses `addingReportingOverflow` with a precondition. The protocol extension should delegate to the bare `+` (which already does this), not reimplement it.

**What gets deleted**:
- `Tagged+Cardinal.swift:77–85` — The `+` and `+=` operators on `Tagged where RawValue == Cardinal`

---

### 3.3. Group B: Ordinal + Cardinal → Already Partially Unified

The existing `Ordinal+Cardinal.swift:76` operators use concrete types (`Ordinal`, `Cardinal`). The tagged versions in `Tagged+Ordinal.swift:93–110` use concrete tagged types.

**Canonical approach**: Make the bare versions generic over `Ordinal.Protocol` and `Cardinal.Protocol`:
```swift
func + <O: Ordinal.Protocol, C: Cardinal.Protocol>(lhs: O, rhs: C) -> O {
    O(lhs.ordinal + rhs.cardinal)
}
```

**Where it should live**: `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift` (same file, generalized signatures)

**What gets deleted**:
- `Tagged+Ordinal.swift:93–110` — The `+`, `+=`, and commutative `+` on tagged types
- `Tagged+Ordinal.swift:123–125` — The `%` on tagged types

---

### 3.4. Group C: Ordinal ↔ Cardinal Cross-Type Comparisons → Unify

**Canonical definition**:
```swift
@_disfavoredOverload
func < <O: Ordinal.Protocol, C: Cardinal.Protocol>(lhs: O, rhs: C) -> Bool {
    lhs.ordinal.rawValue < rhs.cardinal.rawValue
}
// ... and 7 more (<=, >, >=, plus reverse direction)
```

**Where it should live**: `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift` (same file, generalized)

**What gets deleted**:
- `Tagged+Ordinal.swift:141–214` — All 8 tagged cross-type comparison operators

---

### 3.5. Group D: Point ± Vector → Unify via `Vector.Protocol`

**Canonical definition** (requires `Affine.Discrete.Vector.Protocol`):
```swift
func + <O: Ordinal.Protocol, V: Affine.Discrete.Vector.Protocol>(
    lhs: O, rhs: V
) throws(Ordinal.Error) -> O {
    // same implementation as today, using lhs.ordinal and rhs.vector
}
```

**Where it should live**: `swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete+Arithmetic.swift` (same file, generalized)

**What gets deleted**:
- `Tagged+Affine.swift:139–165` — `Ordinal.Protocol + Tagged<Tag, Vector>`, commutative, and subtraction
- `Tagged+Affine.swift:176–181` — `Ordinal.Protocol - Ordinal.Protocol → Tagged<Tag, Vector>` (this one is trickier — see note)

**Note on D7/D8**: The bare `Ordinal - Ordinal → Vector` returns `Affine.Discrete.Vector`, while the tagged version returns `Tagged<Tag, Vector>`. These cannot be unified with the same return type — the tagged version explicitly constructs `Tagged<Tag, _>`. The bare version could return `some Vector.Protocol`, but that would be an opaque return type which prevents concrete usage. **This pair likely stays separate.** The protocol can still be used for the other operators.

---

### 3.6. Group E: Vector ± Vector → Unify via `Vector.Protocol`

**Canonical definition**:
```swift
extension Affine.Discrete.Vector.Protocol {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs.vector + rhs.vector)
    }
    static func - (lhs: Self, rhs: Self) -> Self {
        Self(lhs.vector - rhs.vector)
    }
    static func += (lhs: inout Self, rhs: Self) { lhs = lhs + rhs }
    static func -= (lhs: inout Self, rhs: Self) { lhs = lhs - rhs }
}

prefix func - <V: Affine.Discrete.Vector.Protocol>(v: V) -> V {
    V(-v.vector)
}
```

**Where it should live**: `swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete.Vector.Protocol+Arithmetic.swift` (new file)

**What gets deleted**:
- `Affine.Discrete+Arithmetic.swift:104–143` — Bare vector +, -, prefix -, +=, -=
- `Tagged+Affine.swift:188–216` — Tagged vector +, -, prefix -, +=, -=

---

### 3.7. Group F: Vector ↔ Cardinal Cross-Type Comparisons → Unify

**Canonical definition** (requires `Vector.Protocol`):
```swift
@_disfavoredOverload
func < <V: Affine.Discrete.Vector.Protocol, C: Cardinal.Protocol>(lhs: V, rhs: C) -> Bool {
    lhs.vector.rawValue < Int(rhs.cardinal.rawValue)
}
// ... and 7 more
```

**Where it should live**: `swift-affine-primitives/Sources/Affine Primitives/Affine.Discrete+Arithmetic.swift` (same file, generalized)

**What gets deleted**:
- `Tagged+Affine.swift:250–312` — All 8 tagged vector ↔ cardinal comparison operators

---

### 3.8. Tier Layering Validation

```
identity (T1) → equation (T2) → comparison (T3) → cardinal (T4) → ordinal (T5) → affine (T6) → index (T7) → memory (T8) → buffer (T9)
```

| Change | Package | Dependencies Required | Tier OK? |
|--------|---------|----------------------|----------|
| `Cardinal.Protocol` arithmetic | swift-cardinal-primitives | Identity (for Tagged) | Yes (T4 → T1) |
| Ordinal + Cardinal generics | swift-ordinal-primitives | Cardinal, Identity | Yes (T5 → T4, T1) |
| `Vector.Protocol` definition | swift-affine-primitives | Identity (for Tagged) | Yes (T6 → T1) |
| Vector arithmetic generics | swift-affine-primitives | Cardinal, Ordinal, Identity | Yes (T6 → T5, T4, T1) |
| Index pointer operators | swift-index-primitives | Affine, Cardinal, Identity | Yes (T7 → T6, T4, T1) |

All changes respect downward-only dependencies.

---

## Part 4: Non-Duplicated Operators (No Changes Needed)

The following operators are NOT duplicated and are already in their canonical locations. No refactoring needed.

### Domain-Specific Arithmetic

| Package | Operators | Canonical? |
|---------|-----------|------------|
| swift-algebra-primitives | `Algebra.Z` arithmetic (7 ops), `Sign`/`Ternary` negation, `Product` equality, `Bool` XOR | Yes |
| swift-algebra-linear-primitives | All `Linear.Vector`/`Linear.Matrix` operators (~16 ops) | Yes |
| swift-complex-primitives | All complex number arithmetic (~58 ops) | Yes |
| swift-cyclic-primitives | `Cyclic.Group` arithmetic and comparison (11 ops) | Yes |
| swift-decimal-primitives | `Decimal.Exponent`/`Precision` arithmetic (11 ops) | Yes |
| swift-time-primitives | `Instant` affine ops (4), time unit comparisons (~16), cross-type equality (4) | Yes |

### Dimension/Geometry Tagged System

| Package | Operators | Note |
|---------|-----------|------|
| swift-dimension-primitives | ~200 ops in `Tagged+Arithmatic.swift` | Unique to the dimension/geometry phantom type system; not bare/tagged duplication of cardinal/ordinal/affine operators |
| swift-dimension-primitives | Bare `Degree`, `Radian`, `Scale`, `Interval.Unit` ops (~17) | Domain-specific, no tagged duplicates |
| swift-geometry-primitives | Size/Depth/EdgeInsets/Height/Width ops (~40) | Domain-specific geometry |

### Protocol Default Implementations

| Package | Operators | Note |
|---------|-----------|------|
| swift-equation-primitives | `==` protocol req + `!=` default | Canonical protocol definition |
| swift-comparison-primitives | `<` protocol req + `<=`/`>`/`>=` defaults | Canonical protocol definition |

### Bitwise and Logical

| Package | Operators | Note |
|---------|-----------|------|
| swift-bit-primitives | `^`, `&`, `\|`, `<` on `Bit` | Unique to Bit type |
| swift-logic-primitives | `&&`, `\|\|`, `!`, `^`, `!&&`, `!\|\|`, `!^` | Ternary logic, unique |
| swift-predicate-primitives | `&&`, `\|\|`, `^`, `!` + closure overloads | Predicate algebra, unique |

### Infrastructure

| Package | Operators | Note |
|---------|-----------|------|
| swift-binary-primitives | All optional operators (`+?`, `-?`, etc. — 13 ops) | Custom operator symbols, unique |
| swift-optic-primitives | `>>>` (16 overloads) + `~=` | Optic composition, unique |
| swift-kernel-primitives | Block, File, Permissions, Memory map ops (~23) | Kernel-specific, unique |
| swift-darwin-primitives | Kqueue flags, image header (~3) | Darwin-specific, unique |
| swift-range-primitives | `..<` for tagged lazy range | Unique range formation |

### Data Structures

All `==` and `<` operators on collection types (Queue, Set, Deque, Heap, List, Dictionary, Array, Vector, Infinite) are unique type-specific implementations with no bare/tagged duplication.

### Leaf Packages

All `==` and `<` on clock, CPU, loader, parser, symmetry, test, and standard-library-extension types are unique with no duplication.

---

## Summary

| Metric | Count |
|--------|-------|
| Total operators inventoried | ~470 |
| Duplicated (bare + tagged pair) | 62 (31 pairs) |
| Eliminable after unification | 31 |
| Remaining after refactoring | ~439 |
| New types required | 1 (`Affine.Discrete.Vector.Protocol`) |
| New files required | 2 (`Vector.Protocol.swift`, `Vector.Protocol+Arithmetic.swift`) |
| Files modified | 4 (`Ordinal+Cardinal.swift`, `Affine.Discrete+Arithmetic.swift`, `Tagged+Cardinal.swift`, `Tagged+Ordinal.swift`, `Tagged+Affine.swift`) |
| Files with deletions only | 3 (`Tagged+Cardinal.swift`, `Tagged+Ordinal.swift`, `Tagged+Affine.swift`) |
