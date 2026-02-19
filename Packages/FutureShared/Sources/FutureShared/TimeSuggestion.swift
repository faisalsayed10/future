import Foundation

public struct TimeSuggestion: Identifiable, Sendable {
    public var id: String { label + (isAIParsed ? "-ai" : "") + (neverNotify ? "-never" : "") }
    public let label: String
    public let date: Date
    public let formattedDate: String
    public var isAIParsed: Bool
    public var neverNotify: Bool

    public init(label: String, date: Date, formattedDate: String, isAIParsed: Bool = false, neverNotify: Bool = false) {
        self.label = label
        self.date = date
        self.formattedDate = formattedDate
        self.isAIParsed = isAIParsed
        self.neverNotify = neverNotify
    }
}
