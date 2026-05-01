// V5_Consumer's own raw-FFI shim. In production this would be a small
// .systemLibrary/.target with a C header importing libc directly. Here
// it is a Swift stub to keep the experiment focused on access-control
// mechanics; the relevant question is "can the consumer's own code reach
// raw FFI without L2's involvement?" — yes, trivially, but at the cost
// of duplicating the FFI binding and violating [PLAT-ARCH-008a].
internal func consumerOwnedRawClose(_ fd: Int32) -> Int32 {
    fd >= 0 ? 0 : -1
}
