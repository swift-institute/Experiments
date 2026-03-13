// V4: Struct with stored `body` property
// MemberImportVisibility ON, but Bridge.swift uses `internal import SwiftUI`

import CustomProtocol

public struct MyDoc<Body: CustomView>: CustomView {
    public let body: Body
    public init(body: Body) { self.body = body }
}
