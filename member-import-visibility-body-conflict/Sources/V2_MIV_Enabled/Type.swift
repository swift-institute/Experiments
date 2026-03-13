// V2: Struct with stored `body` property, in a DIFFERENT file from SwiftUI import
// MemberImportVisibility is ON — so `public import SwiftUI` in Bridge.swift leaks here

import CustomProtocol

public struct MyDoc<Body: CustomView>: CustomView {
    public let body: Body
    public init(body: Body) { self.body = body }
}
