import Foundation
import CoreGraphics

public struct OCRPage: Sendable, Equatable {
    public let index: Int
    public let lines: [OCRLine]

    public init(index: Int, lines: [OCRLine]) {
        self.index = index
        self.lines = lines
    }

    /// Builds a page from an already-extracted PDF text layer (no OCR needed).
    /// Blank-line paragraph breaks are preserved by encoding them as an extra vertical
    /// gap between synthetic line boxes, so `MarkdownExporter`'s geometry-based paragraph
    /// grouping reconstructs the same paragraphs as the source PDF.
    public static func fromPlainText(_ text: String, index: Int) -> OCRPage {
        let height = 0.01
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var y = 1.0
        var lines: [OCRLine] = []
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            if paragraphIndex > 0 { y -= height * 2 }
            for rawLine in paragraph.split(separator: "\n", omittingEmptySubsequences: true) {
                y -= height
                lines.append(OCRLine(
                    text: String(rawLine),
                    confidence: 1.0,
                    boundingBox: CGRect(x: 0, y: y, width: 1, height: height)
                ))
            }
        }
        return OCRPage(index: index, lines: lines)
    }
}
