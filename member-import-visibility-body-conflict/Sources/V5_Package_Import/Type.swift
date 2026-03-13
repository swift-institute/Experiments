// V5: Struct with stored `body` property
// MemberImportVisibility ON, Bridge.swift uses `package import SwiftUI`

import CustomProtocol

public struct MyDoc<Body: CustomView>: CustomView {
    public let body: Body
    public init(body: Body) { self.body = body }
}
