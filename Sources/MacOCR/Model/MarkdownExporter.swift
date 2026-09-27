import Foundation

public enum MarkdownExporter {
    private static let leadingEscapeChars: Set<Character> = ["#", ">", "-", "*", "+"]

    public static func export(
        _ document: OCRDocument,
        markLowConfidence: Bool = false,
        date: Date = Date()
    ) -> String {
        let fileName = document.sourceURL.deletingPathExtension().lastPathComponent
        let langs = document.languages.isEmpty ? "auto" : document.languages.joined(separator: ", ")
        let dateString = ISO8601DateFormatter().string(from: date)
        let singlePage = document.pages.count == 1

        var output = "# \(fileName)\n\n"
        output += "> OCR bởi Apple Vision · \(dateString) · Ngôn ngữ: \(langs) · Trang: \(document.pages.count)\n\n"

        for (offset, page) in document.pages.enumerated() {
            if !singlePage {
                output += "## Trang \(page.index)\n\n"
            }

            let paragraphs = paragraphs(from: page.lines, markLowConfidence: markLowConfidence)
            if paragraphs.isEmpty {
                output += "_(Không phát hiện văn bản)_\n\n"
            } else {
                output += paragraphs.joined(separator: "\n\n") + "\n\n"
            }

            if !singlePage && offset < document.pages.count - 1 {
                output += "---\n\n"
            }
        }

        while output.hasSuffix("\n\n") {
            output.removeLast()
        }
        output += "\n"
        return output
    }

    private static func paragraphs(from lines: [OCRLine], markLowConfidence: Bool) -> [String] {
        guard let first = lines.first else { return [] }

        var groups: [[OCRLine]] = [[first]]
        for line in lines.dropFirst() {
            let prev = groups[groups.count - 1].last!
            let lineHeight = prev.boundingBox.height
            let verticalGap = prev.boundingBox.minY - line.boundingBox.maxY
            if lineHeight > 0 && verticalGap > lineHeight * 1.5 {
                groups.append([line])
            } else {
                groups[groups.count - 1].append(line)
            }
        }

        return groups.map { group in
            group.map { formatLine($0, markLowConfidence: markLowConfidence) }.joined(separator: "\n")
        }
    }

    private static func formatLine(_ line: OCRLine, markLowConfidence: Bool) -> String {
        let escaped = escapeLeadingMarkdown(line.text)
        if markLowConfidence && line.confidence < 0.5 {
            return "<mark>\(escaped)</mark>"
        }
        return escaped
    }

    private static func escapeLeadingMarkdown(_ line: String) -> String {
        guard let firstChar = line.first else { return line }

        if leadingEscapeChars.contains(firstChar) {
            return "\\" + line
        }

        if let dotRange = line.range(of: #"^\d+\."#, options: .regularExpression) {
            var escaped = line
            escaped.insert("\\", at: line.index(before: dotRange.upperBound))
            return escaped
        }

        return line
    }
}
