// MARK: - ~Copyable Driver with Closure Witness: Can methods borrow stored fd and pass to stored closures?
// Purpose: Verify that a ~Copyable struct can hold both a ~Copyable resource (fd)
//          and @Sendable closures that receive the resource via borrowing parameter.
//          The METHOD borrows self.fd and passes it to the closure — the closure
//          does NOT capture the fd.
//
// Hypothesis: This compiles and runs correctly. The closure takes `borrowing Resource`
//             as a parameter. The struct's method borrows `self.resource` and passes
//             it. No capture of ~Copyable values in closures.
//
// Toolchain: swiftlang-6.3.0.123.5
// Platform: macOS (arm64)
//
// Result: CONFIRMED — all 5 variants compile and produce correct output
// Output: V1: 52 / V2: 300 / V3: 10 / V4: count=1 / V5: id=55, polled 1, closed
// Date: 2026-04-05

struct Resource: ~Copyable, Sendable { let value: Int }
struct Descriptor: ~Copyable, Sendable { let fd: Int }
enum DriverError: Error, Sendable { case failed }

// MARK: - Variant 1: Basic — method borrows self.resource, passes to stored closure
// Hypothesis: Compiles and produces correct result

func variant1() {
    struct Driver: ~Copyable {
        let resource: Resource
        let _op: @Sendable (borrowing Resource, Int) -> Int
        func op(_ x: Int) -> Int { _op(resource, x) }
        consuming func close() { print("V1: closed \(resource.value)") }
    }

    var d = Driver(resource: Resource(value: 42), _op: { r, x in r.value + x })
    print("V1: \(d.op(10))")  // Expected: 52
    d.close()
}
variant1()

// MARK: - Variant 2: Sendable + typed throws
// Hypothesis: Typed throws work through the closure witness

func variant2() throws {
    struct Driver: ~Copyable, Sendable {
        let resource: Resource
        let _op: @Sendable (borrowing Resource, Int) throws(DriverError) -> Int
        func op(_ x: Int) throws(DriverError) -> Int { try _op(resource, x) }
    }

    let d = Driver(resource: Resource(value: 100), _op: { r, x in r.value * x })
    print("V2: \(try d.op(3))")  // Expected: 300
}
try variant2()

// MARK: - Variant 3: consuming parameter (like register taking consuming Descriptor)
// Hypothesis: Closure takes borrowing resource + consuming descriptor

func variant3() {
    struct Driver: ~Copyable, Sendable {
        let resource: Resource
        let _register: @Sendable (borrowing Resource, consuming Descriptor) -> Int
        func register(_ desc: consuming Descriptor) -> Int { _register(resource, desc) }
    }

    let d = Driver(resource: Resource(value: 7), _register: { r, desc in r.value + desc.fd })
    print("V3: \(d.register(Descriptor(fd: 3)))")  // Expected: 10
}
variant3()

// MARK: - Variant 4: inout parameter (like poll's inout buffer)
// Hypothesis: Closure takes borrowing resource + inout buffer

func variant4() {
    struct Driver: ~Copyable, Sendable {
        let resource: Resource
        let _poll: @Sendable (borrowing Resource, inout [Int]) -> Int
        func poll(into buffer: inout [Int]) -> Int { _poll(resource, &buffer) }
    }

    var buf = [0, 0, 0]
    let d = Driver(resource: Resource(value: 99), _poll: { r, buf in buf[0] = r.value; return 1 })
    let n = d.poll(into: &buf)
    print("V4: count=\(n), buffer=\(buf)")  // Expected: count=1, buffer=[99, 0, 0]
}
variant4()

// MARK: - Variant 5: Full driver — owns fd, multiple closures, wakeup, consuming close
// Hypothesis: Single ~Copyable type replaces Driver + Handle + Make.Result

func variant5() throws {
    struct Driver: ~Copyable, Sendable {
        let fd: Descriptor
        let capabilities: Int
        let wakeup: @Sendable () -> Void

        let _register: @Sendable (borrowing Descriptor, consuming Descriptor, Int) throws(DriverError) -> Int
        let _poll: @Sendable (borrowing Descriptor, inout [Int]) throws(DriverError) -> Int
        let _close: @Sendable (consuming Descriptor) -> Void

        func register(_ desc: consuming Descriptor, interest: Int) throws(DriverError) -> Int {
            try _register(fd, desc, interest)
        }
        func poll(into buffer: inout [Int]) throws(DriverError) -> Int {
            try _poll(fd, &buffer)
        }
        consuming func close() {
            _close(fd)
        }
    }

    var d = Driver(
        fd: Descriptor(fd: 42),
        capabilities: 256,
        wakeup: { print("V5: wakeup!") },
        _register: { fd, desc, interest in fd.fd + desc.fd + interest },
        _poll: { fd, buf in buf[0] = fd.fd; return 1 },
        _close: { fd in print("V5: closed fd \(fd.fd)") }
    )

    let regId = try d.register(Descriptor(fd: 10), interest: 3)
    print("V5: registered id=\(regId)")  // Expected: 55
    d.wakeup()
    var pollBuf = [0, 0]
    let n = try d.poll(into: &pollBuf)
    print("V5: polled \(n), buffer=\(pollBuf)")  // Expected: 1, [42, 0]
    d.close()
}
try variant5()

// MARK: - Results Summary
// V1: CONFIRMED — basic borrow + pass to closure
// V2: CONFIRMED — typed throws through closure witness
// V3: CONFIRMED — consuming param alongside borrowing resource
// V4: CONFIRMED — inout param alongside borrowing resource
// V5: CONFIRMED — full driver pattern: ~Copyable owns fd, 3 closures, wakeup, consuming close
//
// CONCLUSION: The Handle/Make.Result split is unnecessary. A single ~Copyable Driver
// type can own the fd AND hold closures that receive it via borrowing parameter.
// The "closures can't borrow from self" claim was about CAPTURE, not PARAMETER PASSING.
// Methods bridge the gap: they borrow self.fd and pass it as a parameter to the closure.
