import Foundation

public struct OCRDocument: Sendable, Equatable {
    public let sourceURL: URL
    public let pages: [OCRPage]
    public let languages: [String]

    public init(sourceURL: URL, pages: [OCRPage], languages: [String]) {
        self.sourceURL = sourceURL
        self.pages = pages
        self.languages = languages
    }
}
