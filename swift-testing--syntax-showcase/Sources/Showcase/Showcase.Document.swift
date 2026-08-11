extension Showcase {
    public struct Document: Sendable {
        public var title: String
        public var sections: [Section]

        public init(title: String, sections: [Section] = []) {
            self.title = title
            self.sections = sections
        }
    }
}

extension Showcase.Document {
    public struct Section: Sendable {
        public var heading: String
        public var body: String

        public init(heading: String, body: String) {
            self.heading = heading
            self.body = body
        }
    }
}

extension Showcase.Document {
    public func render() -> String {
        var lines: [String] = ["# \(title)", ""]
        for section in sections {
            lines.append("## \(section.heading)")
            lines.append(section.body)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

extension Showcase.Document {
    public static var example: Self {
        Self(
            title: "Getting Started",
            sections: [
                Section(heading: "Installation", body: "Add the package dependency."),
                Section(heading: "Usage", body: "Import the module and call the API."),
            ]
        )
    }
}
