import Foundation

struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String          // slash command (e.g., "code-review")
    var title: String         // display name
    var body: String          // content with {{placeholder}} support
    var category: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var usageCount: Int = 0

    static let placeholderPattern = #"\{\{([^}]+)\}\}"#

    func placeholderRanges() -> [(name: String, range: Range<String.Index>)] {
        guard let regex = try? NSRegularExpression(pattern: Self.placeholderPattern) else {
            return []
        }
        let nsText = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let nameNSRange = match.range(at: 1)
            let fullNSRange = match.range(at: 0)
            guard
                let nameRange = Range(nameNSRange, in: body),
                let fullRange = Range(fullNSRange, in: body)
            else { return nil }
            return (String(body[nameRange]), fullRange)
        }
    }
}
