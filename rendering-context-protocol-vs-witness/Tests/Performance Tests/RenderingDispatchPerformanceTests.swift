// MARK: - Rendering Dispatch Performance Tests
// Purpose: Compare protocol vs witness vs action vs existential dispatch
//          for Rendering.Context operations
// Hypothesis: Protocol (V1) fastest in release; witness (V2) adds measurable
//             closure overhead; action variants (V3/V4) add switch + allocation;
//             AnyView (V5) slowest due to existential allocation + dispatch
//
// Toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — V2 Witness ≈ V1 Protocol (0.99–1.04x release).
//         Action variants 1.20–1.36x. AnyView 1.03–1.07x (dispatch only).
// Date: 2026-03-14

import Testing
public import Variants

// MARK: - Correctness Validation

@Suite(.serialized)
struct Correctness {

    @Test
    func allVariantsProduceIdenticalOutput() {
        // V1: Protocol
        var ctx1 = HTMLContext()
        renderViaProtocol(elements: 10, context: &ctx1)

        // V2: Witness
        var buffer2: ContiguousArray<UInt8> = []
        withUnsafeMutablePointer(to: &buffer2) { ptr in
            var witness = ContextWitness.html(buffer: ptr)
            renderViaWitness(elements: 10, witness: &witness)
        }

        // V3: Action batch
        var ctx3 = HTMLContext()
        renderViaActionsBatch(elements: 10, context: &ctx3)

        // V4: Action reuse
        var ctx4 = HTMLContext()
        renderViaActionsReused(elements: 10, context: &ctx4)

        // V5: AnyView
        var ctx5 = HTMLContext()
        renderViaAnyView(elements: 10, context: &ctx5)

        let baseline = Array(ctx1.bytes)
        #expect(Array(buffer2) == baseline, "V2 witness must match V1 baseline")
        #expect(Array(ctx3.bytes) == baseline, "V3 action batch must match V1 baseline")
        #expect(Array(ctx4.bytes) == baseline, "V4 action reuse must match V1 baseline")
        #expect(Array(ctx5.bytes) == baseline, "V5 AnyView must match V1 baseline")
    }
}

// MARK: - All Benchmarks (serialized across suites)

/// Wrapper suite serializes ALL contained performance tests across all variant
/// suites. Without this, V1 and V2 tests can run simultaneously, causing CPU
/// contention, thermal throttling, and noisy measurements.
///
/// The `.serialized` trait propagates to all nested suites and tests via
/// `Test.Plan.Registry.propagate()`. Inner suites inherit serialization
/// and do not need their own `.serialized`.
@Suite(.serialized)
enum AllBenchmarks {

    // MARK: - V1: Protocol Baseline

    @Suite
    struct V1_Protocol {

        @Test(.timed(iterations: 100, warmup: 10))
        func _10_elements() {
            var context = HTMLContext()
            renderViaProtocol(elements: 10, context: &context)
        }

        @Test(.timed(iterations: 50, warmup: 5))
        func _100_elements() {
            var context = HTMLContext()
            renderViaProtocol(elements: 100, context: &context)
        }

        @Test(.timed(iterations: 20, warmup: 3))
        func _1000_elements() {
            var context = HTMLContext()
            renderViaProtocol(elements: 1000, context: &context)
        }

        @Test(.timed(iterations: 10, warmup: 2))
        func _10000_elements() {
            var context = HTMLContext()
            renderViaProtocol(elements: 10000, context: &context)
        }
    }

    // MARK: - V2: Witness Closures

    @Suite
    struct V2_Witness {

        @Test(.timed(iterations: 100, warmup: 10))
        func _10_elements() {
            var buffer: ContiguousArray<UInt8> = []
            withUnsafeMutablePointer(to: &buffer) { ptr in
                var witness = ContextWitness.html(buffer: ptr)
                renderViaWitness(elements: 10, witness: &witness)
            }
        }

        @Test(.timed(iterations: 50, warmup: 5))
        func _100_elements() {
            var buffer: ContiguousArray<UInt8> = []
            withUnsafeMutablePointer(to: &buffer) { ptr in
                var witness = ContextWitness.html(buffer: ptr)
                renderViaWitness(elements: 100, witness: &witness)
            }
        }

        @Test(.timed(iterations: 20, warmup: 3))
        func _1000_elements() {
            var buffer: ContiguousArray<UInt8> = []
            withUnsafeMutablePointer(to: &buffer) { ptr in
                var witness = ContextWitness.html(buffer: ptr)
                renderViaWitness(elements: 1000, witness: &witness)
            }
        }

        @Test(.timed(iterations: 10, warmup: 2))
        func _10000_elements() {
            var buffer: ContiguousArray<UInt8> = []
            withUnsafeMutablePointer(to: &buffer) { ptr in
                var witness = ContextWitness.html(buffer: ptr)
                renderViaWitness(elements: 10000, witness: &witness)
            }
        }
    }

    // MARK: - V3: Action Batch

    @Suite
    struct V3_ActionBatch {

        @Test(.timed(iterations: 100, warmup: 10))
        func _10_elements() {
            var context = HTMLContext()
            renderViaActionsBatch(elements: 10, context: &context)
        }

        @Test(.timed(iterations: 50, warmup: 5))
        func _100_elements() {
            var context = HTMLContext()
            renderViaActionsBatch(elements: 100, context: &context)
        }

        @Test(.timed(iterations: 20, warmup: 3))
        func _1000_elements() {
            var context = HTMLContext()
            renderViaActionsBatch(elements: 1000, context: &context)
        }

        @Test(.timed(iterations: 10, warmup: 2))
        func _10000_elements() {
            var context = HTMLContext()
            renderViaActionsBatch(elements: 10000, context: &context)
        }
    }

    // MARK: - V4: Action Reuse

    @Suite
    struct V4_ActionReuse {

        @Test(.timed(iterations: 100, warmup: 10))
        func _10_elements() {
            var context = HTMLContext()
            renderViaActionsReused(elements: 10, context: &context)
        }

        @Test(.timed(iterations: 50, warmup: 5))
        func _100_elements() {
            var context = HTMLContext()
            renderViaActionsReused(elements: 100, context: &context)
        }

        @Test(.timed(iterations: 20, warmup: 3))
        func _1000_elements() {
            var context = HTMLContext()
            renderViaActionsReused(elements: 1000, context: &context)
        }

        @Test(.timed(iterations: 10, warmup: 2))
        func _10000_elements() {
            var context = HTMLContext()
            renderViaActionsReused(elements: 10000, context: &context)
        }
    }

    // MARK: - V5: AnyView Existential

    @Suite
    struct V5_AnyView {

        @Test(.timed(iterations: 100, warmup: 10))
        func _10_elements() {
            var context = HTMLContext()
            renderViaAnyView(elements: 10, context: &context)
        }

        @Test(.timed(iterations: 50, warmup: 5))
        func _100_elements() {
            var context = HTMLContext()
            renderViaAnyView(elements: 100, context: &context)
        }

        @Test(.timed(iterations: 20, warmup: 3))
        func _1000_elements() {
            var context = HTMLContext()
            renderViaAnyView(elements: 1000, context: &context)
        }

        @Test(.timed(iterations: 10, warmup: 2))
        func _10000_elements() {
            var context = HTMLContext()
            renderViaAnyView(elements: 10000, context: &context)
        }
    }
}
