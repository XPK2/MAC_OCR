import Testing
import Foundation
import CoreGraphics
@testable import MacOCR

struct MarkdownExporterTests {
    private func line(_ text: String, y: CGFloat, height: CGFloat = 0.05, x: CGFloat = 0.1, confidence: Float = 0.9) -> OCRLine {
        OCRLine(text: text, confidence: confidence, boundingBox: CGRect(x: x, y: y, width: 0.5, height: height))
    }

    @Test func twoPagesHeadingSeparatorAndParagraphOrder() {
        // Page 1: two lines close together (1 paragraph), then a big gap, then one more line (2nd paragraph).
        let page1 = OCRPage(index: 1, lines: [
            line("First paragraph line one", y: 0.90),
            line("First paragraph line two", y: 0.85),
            line("Second paragraph", y: 0.40)
        ])
        let page2 = OCRPage(index: 2, lines: [
            line("Page two text", y: 0.90)
        ])
        let doc = OCRDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/sample.png"),
            pages: [page1, page2],
            languages: ["en-US"]
        )

        let md = MarkdownExporter.export(doc, date: Date(timeIntervalSince1970: 0))

        #expect(md.contains("## Trang 1"))
        #expect(md.contains("## Trang 2"))
        #expect(md.contains("---"))

        let paragraphOrder = "First paragraph line one\nFirst paragraph line two\n\nSecond paragraph"
        #expect(md.contains(paragraphOrder))

        // Page 1 content must appear before page 2 content and before the separator.
        let page1Range = md.range(of: "## Trang 1")!
        let separatorRange = md.range(of: "---")!
        let page2Range = md.range(of: "## Trang 2")!
        #expect(page1Range.upperBound < separatorRange.lowerBound)
        #expect(separatorRange.upperBound < page2Range.lowerBound)
    }

    @Test func leadingHashIsEscaped() {
        let page = OCRPage(index: 1, lines: [line("# Not a heading", y: 0.9)])
        let doc = OCRDocument(sourceURL: URL(fileURLWithPath: "/tmp/a.png"), pages: [page], languages: ["en-US"])

        let md = MarkdownExporter.export(doc, date: Date(timeIntervalSince1970: 0))

        #expect(md.contains("\\# Not a heading"))
    }

    @Test func singlePageImageOmitsPageHeading() {
        let page = OCRPage(index: 1, lines: [line("Just some text", y: 0.9)])
        let doc = OCRDocument(sourceURL: URL(fileURLWithPath: "/tmp/a.png"), pages: [page], languages: ["en-US"])

        let md = MarkdownExporter.export(doc, date: Date(timeIntervalSince1970: 0))

        #expect(!md.contains("## Trang 1"))
        #expect(md.contains("Just some text"))
    }

    @Test func emptyPageReportsNoTextDetected() {
        let page = OCRPage(index: 1, lines: [])
        let doc = OCRDocument(sourceURL: URL(fileURLWithPath: "/tmp/a.png"), pages: [page], languages: ["en-US"])

        let md = MarkdownExporter.export(doc, date: Date(timeIntervalSince1970: 0))

        #expect(md.contains("_(Không phát hiện văn bản)_"))
    }
}
