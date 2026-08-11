// MARK: - Pure-Swift Transcendentals — Performance & Accuracy Characterization
//
// Purpose: Inform the path A vs path B decision for audit item 22
// (swift-institute/Audits/swift-primitives-platform-code-inventory.md).
// numeric-primitives currently ships a `_Shims` C module wrapping libm
// transcendentals. User direction 2026-04-26: be stricter in L1 (no
// platform code or shims). Path A = pure-Swift implementations at L1.
// Path B = coordinated L1 → L3 reshape of complex/dimension/numeric.
// This experiment measures pure-Swift performance + accuracy against
// libm-direct baseline; results decide whether path A is viable.
//
// Hypothesis: Naive pure-Swift implementations of representative
// transcendentals (sqrt, exp, log, sin, atan) achieve ≤ 2× libm latency
// in release mode with ≤ 1 ULP accuracy across a sampled domain.
// Acceptance thresholds (path A is viable if ALL hold):
//   - Latency: pure-Swift release-mode ≤ 2× libm release-mode (median)
//   - Accuracy: max ULP error ≤ 1.0 over sampled domain
//   - Binary size: experiment release binary ≤ 50KB beyond a no-op control
//   - No infinity/NaN regressions on sampled extremes
//
// Implementation note: the "pure Swift" implementations below are honest
// textbook approximations — Taylor series, simple range reduction, no
// minimax polynomial generation. They represent the FLOOR of pure-Swift
// performance, not the ceiling. Apple's upstream swift-numerics uses
// optimized minimax polynomials and would be faster + more accurate. If
// even the naive impls hit the thresholds, optimization can only improve;
// if they fail, the question is whether minimax is enough or whether path
// B is required.
//
// Toolchain: swift-6.3.1-RELEASE (macOS arm64)
// Platform: macOS 15.x (arm64)
// Status: V1 REFUTED on accuracy (2026-04-26) — naive textbook impls do not
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   meet the 1-ULP accuracy threshold; the latency picture is mixed but
//   secondary because accuracy fails first.
// Date: 2026-04-26
//
// Result V1 (naive Taylor + crude range reduction, release mode, M-series
// arm64, 1M calls per measurement, median of 5 samples):
//
//   Function | PureSwift ns | libm ns | Ratio | Max ULP
//   ---------|--------------|---------|-------|--------
//   sqrt[D]  |    1.393     |  1.178  | 1.18× |    0.0   ✓ both thresholds
//   exp[D]   |    6.807     |  0.941  | 7.23× | 580,813  ✗ accuracy + latency
//   log[D]   |    5.167     |  0.775  | 6.66× | 25M      ✗ accuracy + latency
//   sin[D]   |    0.762     |  0.725  | 1.05× | >1e10    ✗ accuracy (latency
//                                                          number unreliable —
//                                                          DCE-suspect; impl
//                                                          breaks on sin(100.0)
//                                                          due to crude range
//                                                          reduction)
//   atan[D]  |    0.735     |  3.402  | 0.21× | >1e10    ✗ accuracy (faster
//                                                          than libm only
//                                                          because the impl
//                                                          is wrong)
//   sqrt[F]  |    0.813     |  0.813  | 1.00× |    0.0   ✓ both thresholds
//   exp[F]   |    3.461     |  1.687  | 2.05× |    8.0   ✗ marginal latency,
//                                                          fails accuracy
//   log[F]   |    5.037     |  1.935  | 2.60× |    8.0   ✗ both
//   sin[F]   |    5.272     |  2.477  | 2.12× | 27M      ✗ both
//   atan[F]  |    2.222     |  2.460  | 0.90× | 596,202  ✗ accuracy
//
// Refuted thresholds (any one of these fails):
//   - 8 of 10 functions exceed 1 ULP error.
//   - 4 of 10 functions exceed 2× libm latency.
//   - sqrt is the only function passing both thresholds (and only because
//     it lowers to a hardware sqrt instruction in both pure-Swift via
//     `Double.squareRoot()` and libm — the implementations are effectively
//     identical at the ISA level).
//
// What this REFUTED tells us about path A viability:
//
// 1. Naive textbook implementations (Taylor series + simple range
//    reduction) are NOT a viable path for L1 transcendentals. Even at
//    7-iteration polynomials, exp/log accuracy is off by 5+ orders of
//    magnitude vs libm; sin/atan break catastrophically on moderately
//    large arguments due to range-reduction precision loss.
//
// 2. The latency picture is more nuanced — Float versions of exp/log
//    land within 2-3× of libm with naive impls, suggesting that with
//    PROPER minimax polynomials and precise range reduction, latency
//    would tighten further. Apple's upstream swift-numerics achieves
//    ~1-1.5× libm in published benchmarks. The latency floor is
//    plausibly acceptable; the question is whether the work to reach
//    Apple-quality is in scope.
//
// 3. sqrt is essentially "free" in pure Swift — `Double.squareRoot()`
//    is the hardware sqrt instruction. Any function that lowers to a
//    single hardware instruction (sqrt, fma, neg, abs) is a guaranteed
//    pure-Swift win. The transcendentals that DON'T have hardware
//    instructions (exp, log, sin/cos, etc.) are where the implementation
//    work concentrates.
//
// 4. The DCE-suspect numbers for sin[D] and atan[D] (where pure-Swift
//    appears AS FAST OR FASTER than libm) reveal that the accumulator-
//    based DCE-prevention works for accuracy-correct paths but breaks
//    when the function returns garbage that the compiler can specialize
//    away. The latency thresholds in this experiment are reliable for
//    the *correct* paths (sqrt, the Float versions which are within ULP
//    bounds at least for some inputs); the broken paths' latency
//    measurements should be treated as unreliable.
//
// V2 hypothesis (NOT yet tested — per [EXP-011a] First Clean Signal Is
// The Result, V2 must test a DIFFERENT hypothesis): "Apple-quality
// minimax polynomials + Payne-Hanek-style range reduction (vendored or
// adapted from Apple's swift-numerics) achieve ≤ 2× libm latency and
// ≤ 1 ULP accuracy for the same function set." If V2 CONFIRMED, path A
// becomes viable but expensive (vendoring + adapting + maintaining a
// transcendental library at L1). If V2 REFUTED, path A is dead and
// path B (coordinated L1 → L3 reshape) is the only architecturally
// clean answer.
//
// Recommendation back to audit item 22: path A's feasibility hinges on
// whether the swift-numerics-quality implementations can be vendored
// into swift-numeric-primitives without dragging in upstream's
// dependencies, build complications, or licensing concerns. That's a
// scoping investigation, not a performance experiment — defer V2 until
// the scoping question is answered. In the meantime, item 22 stays
// DEFERRED with V1's evidence captured here as a data point.
//
// Build & run protocol per [EXP-005]:
//   swift package clean
//   swift build -c release 2>&1 | tee Outputs/build-release.txt
//   swift run -c release 2>&1 | tee Outputs/run-release.txt
//   swift build 2>&1 | tee Outputs/build.txt
//   swift run 2>&1 | tee Outputs/run.txt
//
// Per [EXP-017 release-mode + cross-module clause]: this experiment's
// CONFIRMED verdict would admit production adoption (path A go-ahead).
// Both release-mode pass and cross-module pass receipts MUST land before
// promoting to CONFIRMED. Cross-module receipt is N/A for this single-
// target experiment shape but would be added if path A proceeds to
// numeric-primitives integration phase.

import Darwin

// MARK: - Pure-Swift implementations (textbook approximations; not minimax)

/// Pure-Swift sqrt — uses Swift stdlib's `squareRoot()` (hardware sqrt
/// instruction on most ISAs via LLVM intrinsic; no libm call).
@inline(never)
func pureSwiftSqrtD(_ x: Double) -> Double {
    return x.squareRoot()
}

@inline(never)
func pureSwiftSqrtF(_ x: Float) -> Float {
    return x.squareRoot()
}

/// Pure-Swift exp via range reduction + Taylor series.
/// x = N*ln2 + r, |r| <= ln2/2; exp(x) = 2^N * exp(r).
/// Taylor series for exp(r) on |r| <= ln2/2 ≈ 0.347, 8 terms.
@inline(never)
func pureSwiftExpD(_ x: Double) -> Double {
    if x.isNaN { return x }
    if x > 709.7822 { return .infinity }
    if x < -708.3964 { return 0.0 }

    let LOG2E: Double = 1.4426950408889634
    let LN2_HI: Double = 0.6931471805599453
    let LN2_LO: Double = 2.3190468138462996e-17

    let n = (x * LOG2E).rounded()
    let nInt = Int32(n)
    let r = (x - n * LN2_HI) - n * LN2_LO  // Cody-Waite extended-precision r

    // Horner-form Taylor: 1 + r*(1 + r/2*(1 + r/3*(1 + r/4*(1 + r/5*(1 + r/6*(1 + r/7*(1 + r/8)))))))
    let p = 1.0 + r * (1.0 + r * (1.0 / 2.0 + r * (1.0 / 6.0 + r * (1.0 / 24.0 + r * (1.0 / 120.0 + r * (1.0 / 720.0 + r * (1.0 / 5040.0 + r * (1.0 / 40320.0))))))))

    return Double(sign: .plus, exponent: Int(nInt), significand: p)
}

@inline(never)
func pureSwiftExpF(_ x: Float) -> Float {
    if x.isNaN { return x }
    if x > 88.7 { return .infinity }
    if x < -87.3 { return 0.0 }

    let LOG2E: Float = 1.442695
    let LN2: Float = 0.6931472

    let n = (x * LOG2E).rounded()
    let nInt = Int32(n)
    let r = x - n * LN2

    // Horner Taylor, 6 terms (Float doesn't need as many)
    let p = 1.0 + r * (1.0 + r * (0.5 + r * (1.0 / 6.0 + r * (1.0 / 24.0 + r * (1.0 / 120.0 + r * (1.0 / 720.0))))))

    return Float(sign: .plus, exponent: Int(nInt), significand: p)
}

/// Pure-Swift log via x = 2^n * (1+f), |f| < 1; log(x) = n*ln2 + log(1+f).
/// Polynomial approximation of log(1+f) via series log((1+u)/(1-u)) =
/// 2*(u + u^3/3 + u^5/5 + ...) where u = f/(2+f). Faster convergence
/// than direct Taylor of log(1+f).
@inline(never)
func pureSwiftLogD(_ x: Double) -> Double {
    if x.isNaN { return x }
    if x < 0 { return .nan }
    if x == 0 { return -.infinity }
    if x.isInfinite { return x }

    let LN2: Double = 0.6931471805599453

    let n = x.exponent
    let f = x.significand - 1.0  // significand is in [1, 2), so f is in [0, 1)
    let u = f / (2.0 + f)
    let u2 = u * u

    // 2*(u + u^3/3 + u^5/5 + u^7/7 + u^9/9 + u^11/11)
    let p = 2.0 * u * (1.0 + u2 * (1.0 / 3.0 + u2 * (1.0 / 5.0 + u2 * (1.0 / 7.0 + u2 * (1.0 / 9.0 + u2 * (1.0 / 11.0))))))

    return Double(n) * LN2 + p
}

@inline(never)
func pureSwiftLogF(_ x: Float) -> Float {
    if x.isNaN { return x }
    if x < 0 { return .nan }
    if x == 0 { return -.infinity }
    if x.isInfinite { return x }

    let LN2: Float = 0.6931472

    let n = x.exponent
    let f = x.significand - 1.0
    let u = f / (2.0 + f)
    let u2 = u * u

    let p = 2.0 * u * (1.0 + u2 * (1.0 / 3.0 + u2 * (1.0 / 5.0 + u2 * (1.0 / 7.0))))

    return Float(n) * LN2 + p
}

/// Pure-Swift sin via range reduction to [-π/4, π/4] then Taylor series.
/// Naive range reduction (no Payne-Hanek for huge args; accuracy degrades
/// for |x| > ~10^7). For path-A viability assessment, this is acceptable
/// — production impls would use better range reduction.
@inline(never)
func pureSwiftSinD(_ x: Double) -> Double {
    if x.isNaN || x.isInfinite { return .nan }

    let PI: Double = 3.141592653589793
    let PI_2: Double = 1.5707963267948966
    let PI_4: Double = 0.7853981633974483

    // Reduce to [-π, π]
    var y = x.truncatingRemainder(dividingBy: 2.0 * PI)
    if y > PI { y -= 2.0 * PI } else if y < -PI { y += 2.0 * PI }

    // Reduce further to [-π/4, π/4] via identities
    var sign: Double = 1.0
    var useCos = false
    if y > PI_2 {
        y = PI - y
    } else if y < -PI_2 {
        y = -PI - y
        sign = -1.0
    }
    if y > PI_4 {
        y = PI_2 - y
        useCos = true
    } else if y < -PI_4 {
        y = -PI_2 - y
        useCos = true
        sign = -sign
    }

    let y2 = y * y
    let result: Double
    if useCos {
        // cos(y) Taylor on |y| <= π/4
        result = 1.0 - y2 * (0.5 - y2 * (1.0 / 24.0 - y2 * (1.0 / 720.0 - y2 * (1.0 / 40320.0 - y2 * (1.0 / 3628800.0)))))
    } else {
        // sin(y) Taylor on |y| <= π/4
        result = y * (1.0 - y2 * (1.0 / 6.0 - y2 * (1.0 / 120.0 - y2 * (1.0 / 5040.0 - y2 * (1.0 / 362880.0)))))
    }
    return sign * result
}

@inline(never)
func pureSwiftSinF(_ x: Float) -> Float {
    if x.isNaN || x.isInfinite { return .nan }

    let PI: Float = 3.1415927
    let PI_2: Float = 1.5707964
    let PI_4: Float = 0.7853982

    var y = x.truncatingRemainder(dividingBy: 2.0 * PI)
    if y > PI { y -= 2.0 * PI } else if y < -PI { y += 2.0 * PI }

    var sign: Float = 1.0
    var useCos = false
    if y > PI_2 {
        y = PI - y
    } else if y < -PI_2 {
        y = -PI - y
        sign = -1.0
    }
    if y > PI_4 {
        y = PI_2 - y
        useCos = true
    } else if y < -PI_4 {
        y = -PI_2 - y
        useCos = true
        sign = -sign
    }

    let y2 = y * y
    let result: Float
    if useCos {
        result = 1.0 - y2 * (0.5 - y2 * (1.0 / 24.0 - y2 * (1.0 / 720.0 - y2 * (1.0 / 40320.0))))
    } else {
        result = y * (1.0 - y2 * (1.0 / 6.0 - y2 * (1.0 / 120.0 - y2 * (1.0 / 5040.0))))
    }
    return sign * result
}

/// Pure-Swift atan via reduction + Taylor series.
/// |x| > 1: atan(x) = π/2 - atan(1/x); negative: atan(x) = -atan(-x).
/// Polynomial: atan(y) = y - y^3/3 + y^5/5 - ...; converges on |y| <= 1.
@inline(never)
func pureSwiftAtanD(_ x: Double) -> Double {
    if x.isNaN { return x }
    if x.isInfinite { return x > 0 ? 1.5707963267948966 : -1.5707963267948966 }

    let PI_2: Double = 1.5707963267948966

    let absX = abs(x)
    let sign: Double = x < 0 ? -1.0 : 1.0
    var reduced = absX
    var useReciprocal = false
    if absX > 1.0 {
        reduced = 1.0 / absX
        useReciprocal = true
    }

    // atan Taylor: y - y^3/3 + y^5/5 - y^7/7 + ... (slow convergence near y=1)
    let y2 = reduced * reduced
    let p = reduced * (1.0 - y2 * (1.0 / 3.0 - y2 * (1.0 / 5.0 - y2 * (1.0 / 7.0 - y2 * (1.0 / 9.0 - y2 * (1.0 / 11.0 - y2 * (1.0 / 13.0 - y2 * (1.0 / 15.0 - y2 * (1.0 / 17.0 - y2 / 19.0)))))))))

    let result = useReciprocal ? PI_2 - p : p
    return sign * result
}

@inline(never)
func pureSwiftAtanF(_ x: Float) -> Float {
    if x.isNaN { return x }
    if x.isInfinite { return x > 0 ? 1.5707964 : -1.5707964 }

    let PI_2: Float = 1.5707964

    let absX = abs(x)
    let sign: Float = x < 0 ? -1.0 : 1.0
    var reduced = absX
    var useReciprocal = false
    if absX > 1.0 {
        reduced = 1.0 / absX
        useReciprocal = true
    }

    let y2 = reduced * reduced
    let p = reduced * (1.0 - y2 * (1.0 / 3.0 - y2 * (1.0 / 5.0 - y2 * (1.0 / 7.0 - y2 * (1.0 / 9.0 - y2 * (1.0 / 11.0 - y2 / 13.0))))))

    let result = useReciprocal ? PI_2 - p : p
    return sign * result
}

// MARK: - libm direct baselines (via Darwin)

@inline(never) func libmSqrtD(_ x: Double) -> Double { Darwin.sqrt(x) }
@inline(never) func libmSqrtF(_ x: Float) -> Float { Darwin.sqrtf(x) }
@inline(never) func libmExpD(_ x: Double) -> Double { Darwin.exp(x) }
@inline(never) func libmExpF(_ x: Float) -> Float { Darwin.expf(x) }
@inline(never) func libmLogD(_ x: Double) -> Double { Darwin.log(x) }
@inline(never) func libmLogF(_ x: Float) -> Float { Darwin.logf(x) }
@inline(never) func libmSinD(_ x: Double) -> Double { Darwin.sin(x) }
@inline(never) func libmSinF(_ x: Float) -> Float { Darwin.sinf(x) }
@inline(never) func libmAtanD(_ x: Double) -> Double { Darwin.atan(x) }
@inline(never) func libmAtanF(_ x: Float) -> Float { Darwin.atanf(x) }

// MARK: - Sinks (prevent dead-code elimination)

nonisolated(unsafe) var sinkD: Double = 0
nonisolated(unsafe) var sinkF: Float = 0

// MARK: - Benchmark harness

/// Returns nanoseconds per call (median of 5 runs).
func benchmarkD(_ name: String, _ fn: (Double) -> Double, inputs: [Double], iterations: Int) -> Double {
    var samples: [Double] = []
    // Warmup
    for _ in 0..<3 {
        for x in inputs { sinkD = fn(x) }
    }
    for _ in 0..<5 {
        let clock = ContinuousClock()
        let start = clock.now
        var acc: Double = 0
        for _ in 0..<iterations {
            for x in inputs {
                acc += fn(x)
            }
        }
        let elapsed = clock.now - start
        sinkD = acc
        let totalCalls = Double(iterations * inputs.count)
        let secs = Double(elapsed.components.seconds)
        let attos = Double(elapsed.components.attoseconds)
        let ns = secs * 1e9 + attos * 1e-9
        samples.append(ns / totalCalls)
    }
    samples.sort()
    return samples[2]  // median of 5
}

func benchmarkF(_ name: String, _ fn: (Float) -> Float, inputs: [Float], iterations: Int) -> Double {
    var samples: [Double] = []
    for _ in 0..<3 {
        for x in inputs { sinkF = fn(x) }
    }
    for _ in 0..<5 {
        let clock = ContinuousClock()
        let start = clock.now
        var acc: Float = 0
        for _ in 0..<iterations {
            for x in inputs {
                acc += fn(x)
            }
        }
        let elapsed = clock.now - start
        sinkF = acc
        let totalCalls = Double(iterations * inputs.count)
        let ns = Double(elapsed.components.attoseconds / 1_000_000_000) + Double(elapsed.components.seconds) * 1e9
        samples.append(ns / totalCalls)
    }
    samples.sort()
    return samples[2]
}

// MARK: - ULP error

/// Returns max ULP error of `pure(x)` vs `reference(x)` over inputs.
func maxULPErrorD(_ pure: (Double) -> Double, _ reference: (Double) -> Double, inputs: [Double]) -> Double {
    var maxULP = 0.0
    for x in inputs {
        let p = pure(x)
        let r = reference(x)
        if p.isNaN && r.isNaN { continue }
        if p.isInfinite && r.isInfinite && (p.sign == r.sign) { continue }
        let diff = abs(p - r)
        let ulp = r.ulp
        if ulp > 0 {
            let ulpErr = diff / ulp
            if ulpErr > maxULP { maxULP = ulpErr }
        }
    }
    return maxULP
}

func maxULPErrorF(_ pure: (Float) -> Float, _ reference: (Float) -> Float, inputs: [Float]) -> Double {
    var maxULP = 0.0
    for x in inputs {
        let p = pure(x)
        let r = reference(x)
        if p.isNaN && r.isNaN { continue }
        if p.isInfinite && r.isInfinite && (p.sign == r.sign) { continue }
        let diff = abs(Double(p) - Double(r))
        let ulp = Double(r.ulp)
        if ulp > 0 {
            let ulpErr = diff / ulp
            if ulpErr > maxULP { maxULP = ulpErr }
        }
    }
    return maxULP
}

// MARK: - Inputs

let inputsSqrtD: [Double] = [0.5, 1.0, 2.0, 3.14159, 100.0, 1e6, 1e-6, 1e10, 1e-10, 17.5]
let inputsExpD: [Double] = [-5.0, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0]
let inputsLogD: [Double] = [0.5, 1.0, 1.5, 2.0, 2.71828, 10.0, 100.0, 1e6, 1e-6, 1.234]
let inputsSinD: [Double] = [-3.14, -1.5, -0.5, 0.0, 0.5, 1.0, 1.5, 3.14, 6.28, 100.0]
let inputsAtanD: [Double] = [-100.0, -1.0, -0.5, 0.0, 0.5, 1.0, 5.0, 100.0, 0.1, 10.0]

let inputsSqrtF = inputsSqrtD.map(Float.init)
let inputsExpF = inputsExpD.map(Float.init)
let inputsLogF = inputsLogD.map(Float.init)
let inputsSinF = inputsSinD.map(Float.init)
let inputsAtanF = inputsAtanD.map(Float.init)

// MARK: - Main

let iterations = 100_000

print("=== Pure-Swift vs libm Transcendentals ===")
print("Toolchain: \(getSwiftVersion())")
print("Iterations per measurement: \(iterations) × inputs (\(inputsExpD.count) inputs ⇒ \(iterations * inputsExpD.count) calls)")
print("Median of 5 timing samples reported.\n")

print(pad("Function", 12) + " | " + pad("PureSwift ns", 14) + " | " + pad("libm ns", 14) + " | " + pad("Ratio", 9) + " | " + "Max ULP")
print(String(repeating: "-", count: 78))

func pad(_ s: String, _ width: Int) -> String {
    if s.count >= width { return s }
    return s + String(repeating: " ", count: width - s.count)
}

func fmtNs(_ x: Double) -> String {
    if !x.isFinite { return "inf" }
    if x > 1e15 { return ">1e15" }
    let i = Int(x * 1000)
    let whole = i / 1000
    let frac = abs(i % 1000)
    let fracStr = (frac < 100 ? "0" : "") + (frac < 10 ? "0" : "") + "\(frac)"
    return "\(whole).\(fracStr)"
}

func fmtRatio(_ x: Double) -> String {
    if !x.isFinite { return "inf" }
    if x > 1e10 { return ">1e10" }
    let i = Int(x * 100)
    let whole = i / 100
    let frac = abs(i % 100)
    let fracStr = (frac < 10 ? "0" : "") + "\(frac)"
    return "\(whole).\(fracStr)"
}

func fmtULP(_ x: Double) -> String {
    if !x.isFinite { return "inf" }
    if x == 0 { return "0.0000" }
    if x > 1e10 { return ">1e10" }  // huge ULP error — guard Int conversion
    let i = Int(x * 10000)
    let whole = i / 10000
    let frac = abs(i % 10000)
    var fracStr = "\(frac)"
    while fracStr.count < 4 { fracStr = "0" + fracStr }
    return "\(whole).\(fracStr)"
}

func report(_ name: String, _ pureNs: Double, _ libmNs: Double, _ ulp: Double) {
    let ratio = libmNs > 0 ? pureNs / libmNs : Double.infinity
    print(pad(name, 12) + " | " + pad(fmtNs(pureNs), 14) + " | " + pad(fmtNs(libmNs), 14) + " | " + pad(fmtRatio(ratio), 9) + " | " + fmtULP(ulp))
}

// Double
let pureSqrtD_ns = benchmarkD("sqrt(D)", pureSwiftSqrtD, inputs: inputsSqrtD, iterations: iterations)
let libmSqrtD_ns = benchmarkD("libm sqrt(D)", libmSqrtD, inputs: inputsSqrtD, iterations: iterations)
let sqrtD_ulp = maxULPErrorD(pureSwiftSqrtD, libmSqrtD, inputs: inputsSqrtD)
report("sqrt[D]", pureSqrtD_ns, libmSqrtD_ns, sqrtD_ulp)

let pureExpD_ns = benchmarkD("exp(D)", pureSwiftExpD, inputs: inputsExpD, iterations: iterations)
let libmExpD_ns = benchmarkD("libm exp(D)", libmExpD, inputs: inputsExpD, iterations: iterations)
let expD_ulp = maxULPErrorD(pureSwiftExpD, libmExpD, inputs: inputsExpD)
report("exp[D]", pureExpD_ns, libmExpD_ns, expD_ulp)

let pureLogD_ns = benchmarkD("log(D)", pureSwiftLogD, inputs: inputsLogD, iterations: iterations)
let libmLogD_ns = benchmarkD("libm log(D)", libmLogD, inputs: inputsLogD, iterations: iterations)
let logD_ulp = maxULPErrorD(pureSwiftLogD, libmLogD, inputs: inputsLogD)
report("log[D]", pureLogD_ns, libmLogD_ns, logD_ulp)

let pureSinD_ns = benchmarkD("sin(D)", pureSwiftSinD, inputs: inputsSinD, iterations: iterations)
let libmSinD_ns = benchmarkD("libm sin(D)", libmSinD, inputs: inputsSinD, iterations: iterations)
let sinD_ulp = maxULPErrorD(pureSwiftSinD, libmSinD, inputs: inputsSinD)
report("sin[D]", pureSinD_ns, libmSinD_ns, sinD_ulp)

let pureAtanD_ns = benchmarkD("atan(D)", pureSwiftAtanD, inputs: inputsAtanD, iterations: iterations)
let libmAtanD_ns = benchmarkD("libm atan(D)", libmAtanD, inputs: inputsAtanD, iterations: iterations)
let atanD_ulp = maxULPErrorD(pureSwiftAtanD, libmAtanD, inputs: inputsAtanD)
report("atan[D]", pureAtanD_ns, libmAtanD_ns, atanD_ulp)

// Float
let pureSqrtF_ns = benchmarkF("sqrt(F)", pureSwiftSqrtF, inputs: inputsSqrtF, iterations: iterations)
let libmSqrtF_ns = benchmarkF("libm sqrt(F)", libmSqrtF, inputs: inputsSqrtF, iterations: iterations)
let sqrtF_ulp = maxULPErrorF(pureSwiftSqrtF, libmSqrtF, inputs: inputsSqrtF)
report("sqrt[F]", pureSqrtF_ns, libmSqrtF_ns, sqrtF_ulp)

let pureExpF_ns = benchmarkF("exp(F)", pureSwiftExpF, inputs: inputsExpF, iterations: iterations)
let libmExpF_ns = benchmarkF("libm exp(F)", libmExpF, inputs: inputsExpF, iterations: iterations)
let expF_ulp = maxULPErrorF(pureSwiftExpF, libmExpF, inputs: inputsExpF)
report("exp[F]", pureExpF_ns, libmExpF_ns, expF_ulp)

let pureLogF_ns = benchmarkF("log(F)", pureSwiftLogF, inputs: inputsLogF, iterations: iterations)
let libmLogF_ns = benchmarkF("libm log(F)", libmLogF, inputs: inputsLogF, iterations: iterations)
let logF_ulp = maxULPErrorF(pureSwiftLogF, libmLogF, inputs: inputsLogF)
report("log[F]", pureLogF_ns, libmLogF_ns, logF_ulp)

let pureSinF_ns = benchmarkF("sin(F)", pureSwiftSinF, inputs: inputsSinF, iterations: iterations)
let libmSinF_ns = benchmarkF("libm sin(F)", libmSinF, inputs: inputsSinF, iterations: iterations)
let sinF_ulp = maxULPErrorF(pureSwiftSinF, libmSinF, inputs: inputsSinF)
report("sin[F]", pureSinF_ns, libmSinF_ns, sinF_ulp)

let pureAtanF_ns = benchmarkF("atan(F)", pureSwiftAtanF, inputs: inputsAtanF, iterations: iterations)
let libmAtanF_ns = benchmarkF("libm atan(F)", libmAtanF, inputs: inputsAtanF, iterations: iterations)
let atanF_ulp = maxULPErrorF(pureSwiftAtanF, libmAtanF, inputs: inputsAtanF)
report("atan[F]", pureAtanF_ns, libmAtanF_ns, atanF_ulp)

print("\n=== Sink (prevents DCE): \(sinkD) \(sinkF) ===")

func getSwiftVersion() -> String {
    #if swift(>=6.3)
    return "Swift 6.3+"
    #else
    return "Swift <6.3"
    #endif
}
