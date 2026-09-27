import Testing
import Foundation
import CoreGraphics
import CoreText
import PDFKit
import ImageIO
@testable import MacOCR

struct OCRServiceTests {
    @Test func recognizesRenderedText() throws {
        let image = try #require(Self.makeTextImage(["Hello OCR 123"]))
        let lines = try OCRService.recognizeText(in: image, languages: [])
        #expect(lines.map(\.text).joined(separator: " ").contains("Hello"))
    }

    @Test func sortsSameRowByXDespiteBaselineJitter() {
        let right = OCRLine(text: "right", confidence: 1, boundingBox: CGRect(x: 0.6, y: 0.805, width: 0.2, height: 0.05))
        let left = OCRLine(text: "left", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.800, width: 0.2, height: 0.05))
        let below = OCRLine(text: "below", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.700, width: 0.2, height: 0.05))
        #expect(OCRService.sortReadingOrder([below, right, left]).map(\.text) == ["left", "right", "below"])
    }

    /// Photos from phones store pixels sideways + an EXIF orientation flag.
    @Test func honorsExifOrientation() throws {
        let upright = try #require(Self.makeTextImage(["Rotated Photo Text"]))
        let sideways = try #require(Self.rotate90(upright))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macocr-exif-\(UUID()).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        // Pixels rotated 90° clockwise → orientation 8 ("rotate 90° CCW to display").
        CGImageDestinationAddImage(dest, sideways, [kCGImagePropertyOrientation: 8] as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))

        guard case .image(let image, let orientation) = try DocumentLoader(url: url).page(at: 0) else {
            Issue.record("expected image page"); return
        }
        #expect(orientation == .left)
        let text = try OCRService.recognizeText(in: image, orientation: orientation, languages: []).map(\.text).joined(separator: " ")
        #expect(text.contains("Rotated"))
    }

    @Test func rendersRotatedPDFPageWithSwappedDimensions() throws {
        let page = Self.makePDFPage()
        page.rotation = 90
        let size = page.pageRef!.getBoxRect(.cropBox).size
        let image = try #require(DocumentLoader.render(page, dpi: 72))
        #expect(image.width == Int(size.height))
        #expect(image.height == Int(size.width))
    }

    @Test func pdfTextLayerSkipsOCRAndKeepsParagraphs() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macocr-text-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.writeTextPDF(to: url, pages: ["Page one text", "Page two text"])

        let loader = try DocumentLoader(url: url)
        #expect(loader.pageCount == 2)
        guard case .text(let text) = try loader.page(at: 1) else { Issue.record("expected text layer"); return }
        #expect(text.contains("Page two"))
    }

    /// End-to-end calibration of the paragraph-gap ratio on real Vision output:
    /// normal line spacing stays one paragraph, a blank line splits it.
    @Test func paragraphGroupingOnRealOCR() throws {
        let image = try #require(Self.makeTextImage(["Alpha line one", "Alpha line two", "", "Beta paragraph"], width: 900))
        let lines = try OCRService.recognizeText(in: image, languages: ["en-US"])
        let doc = OCRDocument(sourceURL: URL(fileURLWithPath: "/tmp/p.png"), pages: [OCRPage(index: 1, lines: lines)], languages: [])
        let md = MarkdownExporter.export(doc)
        #expect(md.contains("Alpha line one\nAlpha line two\n\nBeta paragraph"), "got: \(md)")
    }

    // MARK: - Fixtures

    static func makeTextImage(_ lines: [String], width: Int = 600, fontSize: CGFloat = 40) -> CGImage? {
        let lineHeight = fontSize * 1.3
        let height = Int(lineHeight * CGFloat(lines.count) + fontSize * 2)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        for (i, text) in lines.enumerated() where !text.isEmpty {
            let attributed = CFAttributedStringCreate(nil, text as CFString, [kCTFontAttributeName: font] as CFDictionary)!
            context.textPosition = CGPoint(x: 20, y: CGFloat(height) - fontSize * 1.5 - CGFloat(i) * lineHeight)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
        return context.makeImage()
    }

    /// Rotates pixels 90° clockwise.
    static func rotate90(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: image.height, height: image.width, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(image.width))
        context.rotate(by: -.pi / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    static func writeTextPDF(to url: URL, pages: [String]) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        for text in pages {
            context.beginPDFPage(nil)
            let attributed = CFAttributedStringCreate(nil, text as CFString, [kCTFontAttributeName: font] as CFDictionary)!
            context.textPosition = CGPoint(x: 72, y: 700)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            context.endPDFPage()
        }
        context.closePDF()
    }

    /// Portrait (non-square) page, so a 90° rotation visibly swaps dimensions.
    static func makePDFPage() -> PDFPage {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macocr-rot-\(UUID()).pdf")
        try? writeTextPDF(to: url, pages: ["x"])
        return PDFDocument(url: url)!.page(at: 0)!
    }
}
