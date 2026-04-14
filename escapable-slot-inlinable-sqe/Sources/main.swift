// MARK: - ~Escapable Slot + @inlinable Mutating Entry Methods
// Purpose: Validate the io_uring SQE pointer-elimination architecture.
//          Can we use ~Copyable ~Escapable slot types with nonmutating _modify
//          to provide @inlinable mutating methods on Entry — zero pointers in
//          the public API?
//
// Hypothesis: All 5 variants compile and run correctly under Swift 6.2+
//             with Lifetimes + LifetimeDependence + InternalImportsByDefault.
//
// Toolchain: swift-6.3-RELEASE
// Platform: macOS (arm64)
//
// Result: ALL CONFIRMED (V1-V2, V4-V6) / V3 REFUTED (return-based ~Escapable)
// Date: 2026-04-12
//
// Key finding: ~Escapable DOES work for pointer-backed mmap'd memory — but only
// through coroutine yield (_read/_modify), NOT through function return.
// The coroutine scope IS the lifetime boundary. No @lifetime annotation needed.
// This is the same pattern Property.View uses in the ecosystem.

// ============================================================================
// Simulate the io_uring types without C dependencies
// ============================================================================

/// Simulates io_uring_sqe — the C struct we want to hide
struct CValue: @unchecked Sendable {
    var opcode: UInt8 = 0
    var flags: UInt8 = 0
    var fd: Int32 = 0
    var off: UInt64 = 0
    var addr: UInt64 = 0
    var len: UInt32 = 0
    var rw_flags: UInt32 = 0
    var user_data: UInt64 = 0
    var buf_index: UInt16 = 0
    var splice_fd_in: Int32 = 0
}

// ============================================================================
// MARK: - Variant 1: @usableFromInline accessors hiding internal C type
// Hypothesis: @usableFromInline computed properties that internally access
//             a non-public stored property compile without exposing the type.
// ============================================================================

public struct Entry: Sendable {
    internal var cValue: CValue

    public init() {
        self.cValue = CValue()
    }

    // Public typed accessors
    public var opcode: UInt8 {
        get { cValue.opcode }
        set { cValue.opcode = newValue }
    }

    public var addr: UInt64 {
        get { cValue.addr }
        set { cValue.addr = newValue }
    }

    public var length: UInt32 {
        get { cValue.len }
        set { cValue.len = newValue }
    }

    public var data: UInt64 {
        get { cValue.user_data }
        set { cValue.user_data = newValue }
    }

    // @usableFromInline for overloaded union fields
    @usableFromInline
    var _fd: Int32 {
        get { cValue.fd }
        set { cValue.fd = newValue }
    }

    @usableFromInline
    var _rawFlags: UInt32 {
        get { cValue.rw_flags }
        set { cValue.rw_flags = newValue }
    }

    @usableFromInline
    var _rawLength: UInt32 {
        get { cValue.len }
        set { cValue.len = newValue }
    }

    @usableFromInline
    var _rawOffset: UInt64 {
        get { cValue.off }
        set { cValue.off = newValue }
    }

    @usableFromInline
    var _bufferIndex: UInt16 {
        get { cValue.buf_index }
        set { cValue.buf_index = newValue }
    }

    @usableFromInline
    var _spliceSourceFd: Int32 {
        get { cValue.splice_fd_in }
        set { cValue.splice_fd_in = newValue }
    }
}

// Result V1: CONFIRMED — @usableFromInline computed properties compile, hide internal cValue

// ============================================================================
// MARK: - Variant 2: @inlinable mutating methods on Entry
// Hypothesis: Mutating methods that access only public and @usableFromInline
//             properties can be @inlinable — no cValue reference in body.
// ============================================================================

extension Entry {
    @inlinable
    public mutating func read(
        fd: Int32,
        buffer: UInt64,
        length: UInt32,
        offset: UInt64,
        data: UInt64
    ) {
        self = .init()
        self.opcode = 22  // IORING_OP_READ
        self._fd = fd
        self.addr = buffer
        self.length = length
        self._rawOffset = offset
        self.data = data
    }

    @inlinable
    public mutating func splice(
        sourceFd: Int32,
        flags: UInt32,
        length: UInt32,
        data: UInt64
    ) {
        self = .init()
        self.opcode = 30  // IORING_OP_SPLICE
        self._spliceSourceFd = sourceFd
        self._rawFlags = flags
        self._rawLength = length
        self.data = data
    }

    @inlinable
    public mutating func timeout(
        timespecAddr: UInt64,
        count: UInt32,
        flags: UInt32,
        data: UInt64
    ) {
        self = .init()
        self.opcode = 11  // IORING_OP_TIMEOUT
        self._fd = -1     // sentinel
        self.addr = timespecAddr
        self._rawLength = count
        self._rawFlags = flags
        self.data = data
    }
}

// Result V2: CONFIRMED — @inlinable mutating methods compile, access only public/@usableFromInline

// ============================================================================
// MARK: - Variant 3: ~Copyable ~Escapable Slot with nonmutating _modify
// Hypothesis: A ~Copyable ~Escapable struct can provide nonmutating _modify
//             access to a pointed-to Entry, enabling slot.entry.read(...).
// ============================================================================

// V3: ~Escapable Slot — REFUTED
// @lifetime(borrow self) cannot trace through UnsafeMutablePointer indirection.
// mmap'd memory lifetime is managed by Ring's deinit, not by Swift's type system.
// Falling back to ~Copyable Slot (same safety as current Prepare type).

// Result V3: REFUTED — ~Escapable not viable for mmap'd pointer indirection

// ============================================================================
// MARK: - Variant 4: ~Escapable return with lifetime dependence
// Hypothesis: A mutating function can return a ~Escapable value with
//             lifetime dependence on self (the ring).
// ============================================================================

@unsafe public struct Ring: ~Copyable {
    @usableFromInline var entries: UnsafeMutablePointer<Entry>
    @usableFromInline var tail: Int = 0
    @usableFromInline var capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self.entries = .allocate(capacity: capacity)
        self.entries.initialize(repeating: Entry(), count: capacity)
    }

    // V4: nextEntry() mutating, returns ~Copyable Slot (pointer hidden)
    @inlinable
    public mutating func nextEntry() -> Slot? {
        guard tail < capacity else { return nil }
        let index = tail
        tail += 1
        let ptr = unsafe entries.advanced(by: index)
        return unsafe Slot(ptr)
    }

    deinit {
        unsafe entries.deallocate()
    }
}

// V4b: Slot without ~Escapable — same ownership safety as current Prepare
@safe public struct Slot: ~Copyable {
    @usableFromInline
    let pointer: UnsafeMutablePointer<Entry>

    @usableFromInline @unsafe
    init(_ pointer: UnsafeMutablePointer<Entry>) {
        self.pointer = unsafe pointer
    }

    @inlinable
    public var entry: Entry {
        _read { yield unsafe pointer.pointee }
        nonmutating _modify { yield unsafe &pointer.pointee }
    }
}

// Result V4: CONFIRMED — mutating nextEntry() returns ~Copyable Slot, hides pointer

// ============================================================================
// MARK: - Variant 5: Full chain end-to-end
// Hypothesis: ring.nextEntry() returns ~Copyable Slot, slot.entry.read(...)
//             writes through nonmutating _modify, all @inlinable.
// ============================================================================

func testFullChain() {
    var ring = unsafe Ring(capacity: 256)

    if let slot = ring.nextEntry() {
        slot.entry.read(fd: 5, buffer: 0x1000, length: 4096, offset: 0, data: 42)
        print("After read: opcode=\(slot.entry.opcode), fd=\(slot.entry._fd), data=\(slot.entry.data)")
    }

    if let slot = ring.nextEntry() {
        slot.entry.splice(sourceFd: 7, flags: 1, length: 8192, data: 43)
        print("After splice: opcode=\(slot.entry.opcode), splice_fd=\(slot.entry._spliceSourceFd), data=\(slot.entry.data)")
    }

    if let slot = ring.nextEntry() {
        slot.entry.timeout(timespecAddr: 0x2000, count: 0, flags: 0, data: 44)
        print("After timeout: opcode=\(slot.entry.opcode), fd=\(slot.entry._fd), data=\(slot.entry.data)")
    }

    print("Ring tail: \(ring.tail)")
}

// Result V5: CONFIRMED — full chain: ring → slot → entry.read() → correct field values

// ============================================================================
// MARK: - Variant 6: ~Escapable Slot via coroutine yield (not function return)
// Hypothesis: _read/_modify coroutines can yield a ~Escapable Slot because
//             the coroutine scope limits the value's lifetime — no @lifetime
//             annotation needed for the yield, the scope IS the lifetime.
//             This is how Property.View works in the ecosystem.
// ============================================================================

@safe public struct EscapableSlot: ~Copyable, ~Escapable {
    @usableFromInline
    let pointer: UnsafeMutablePointer<Entry>

    @lifetime(borrow pointer)
    @usableFromInline @unsafe
    init(_ pointer: UnsafeMutablePointer<Entry>) {
        self.pointer = unsafe pointer
    }

    @inlinable
    public var entry: Entry {
        _read { yield unsafe pointer.pointee }
        nonmutating _modify { yield unsafe &pointer.pointee }
    }
}

@unsafe public struct EscapableRing: ~Copyable {
    @usableFromInline var entries: UnsafeMutablePointer<Entry>
    @usableFromInline var tail: Int = 0
    @usableFromInline var capacity: Int

    public init(capacity: Int) {
        self.capacity = capacity
        self.entries = .allocate(capacity: capacity)
        self.entries.initialize(repeating: Entry(), count: capacity)
    }

    /// Coroutine-based slot access — yields ~Escapable slot.
    /// The _modify scope IS the lifetime boundary.
    public var next: EscapableSlot {
        mutating _read {
            let ptr = unsafe entries.advanced(by: tail)
            yield unsafe EscapableSlot(ptr)
        }
    }

    public mutating func advance() {
        tail += 1
    }

    deinit {
        unsafe entries.deallocate()
    }
}

func testEscapableCoroutine() {
    print("\n=== V6: ~Escapable Slot via coroutine ===")
    var ring = unsafe EscapableRing(capacity: 256)

    // Access slot through coroutine scope — slot can't escape
    ring.next.entry.read(fd: 10, buffer: 0x3000, length: 512, offset: 100, data: 60)
    print("After read: opcode=\(ring.next.entry.opcode), data=\(ring.next.entry.data)")
    ring.advance()

    ring.next.entry.timeout(timespecAddr: 0x4000, count: 0, flags: 0, data: 61)
    print("After timeout: opcode=\(ring.next.entry.opcode), fd=\(ring.next.entry._fd)")
    ring.advance()

    print("Ring tail: \(ring.tail)")
}

// Result V6: CONFIRMED — ~Escapable Slot via coroutine yield compiles AND runs correctly
//             opcode=22/data=60 (read), opcode=11/fd=-1 (timeout). Coroutine scope
//             provides lifetime safety without @lifetime annotation on the property.

// ============================================================================
// MARK: - Run
// ============================================================================

testFullChain()
testEscapableCoroutine()

// ============================================================================
// MARK: - Results Summary
// V1 (@usableFromInline accessors):          CONFIRMED
// V2 (@inlinable mutating methods):          CONFIRMED
// V3 (~Escapable via function return):        REFUTED — can't trace lifetime through pointer
// V4 (~Copyable Slot, pointer hidden):        CONFIRMED
// V5 (Full chain ~Copyable end-to-end):       CONFIRMED
// V6 (~Escapable Slot via coroutine yield):   CONFIRMED — the correct architecture
// ============================================================================
