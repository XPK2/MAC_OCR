import Foundation
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum DocumentLoaderError: Error, LocalizedError {
    case unreadableFile(URL)
    case unsupportedFormat(URL)
    case passwordProtectedPDF(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let url):
            return "Không thể đọc file: \(url.lastPathComponent)"
        case .unsupportedFormat(let url):
            return "Định dạng không được hỗ trợ: \(url.lastPathComponent)"
        case .passwordProtectedPDF(let url):
            return "File PDF có mật khẩu: \(url.lastPathComponent)"
        }
    }
}

/// One page's content: either a text layer already present in the source PDF,
/// or an image to be run through OCR.
public enum PageContent: @unchecked Sendable {
    case text(String)
    case image(CGImage, CGImagePropertyOrientation)
}

/// Opens a file cheaply; pages are produced one at a time by `page(at:)` so a
/// large PDF never holds more than one rendered page in memory.
public final class DocumentLoader {
    public let url: URL
    public let pageCount: Int
    private let pdf: PDFDocument?
    private let imageSource: CGImageSource?

    public static func isSupported(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .pdf) || type.conforms(to: .image)
    }

    public init(url: URL) throws {
        self.url = url
        guard Self.isSupported(url) else { throw DocumentLoaderError.unsupportedFormat(url) }

        if UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url) else { throw DocumentLoaderError.unreadableFile(url) }
            if document.isLocked { throw DocumentLoaderError.passwordProtectedPDF(url) }
            pdf = document
            imageSource = nil
            pageCount = document.pageCount
        } else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  CGImageSourceGetCount(source) > 0 else {
                throw DocumentLoaderError.unreadableFile(url)
            }
            pdf = nil
            imageSource = source
            pageCount = 1 // ponytail: multi-frame GIF/TIFF → first frame only
        }
    }

    public func page(at index: Int) throws -> PageContent {
        if let imageSource {
            guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw DocumentLoaderError.unreadableFile(url)
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            let raw = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
            return .image(image, CGImagePropertyOrientation(rawValue: raw) ?? .up)
        }

        guard let page = pdf?.page(at: index) else { return .text("") }
        // ponytail: any non-blank text layer is trusted; garbage layers from bad scanners pass through
        if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        guard let image = Self.render(page) else { return .text("") }
        return .image(image, .up)
    }

    /// Renders the visible (crop box) area honoring /Rotate, in 8-bit grayscale
    /// (4× less memory than RGBA; Vision doesn't need color).
    static func render(_ page: PDFPage, dpi: CGFloat = 300, maxPixels: CGFloat = 6000) -> CGImage? {
        guard let cgPage = page.pageRef else { return nil }
        let box = cgPage.getBoxRect(.cropBox)
        let size = cgPage.rotationAngle % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
        let scale = min(dpi / 72, maxPixels / max(size.width, size.height, 1))
        let width = Int(size.width * scale), height = Int(size.height * scale)

        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else { return nil }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.concatenate(cgPage.getDrawingTransform(
            .cropBox, rect: CGRect(origin: .zero, size: size), rotate: 0, preserveAspectRatio: true
        ))
        context.drawPDFPage(cgPage)
        return context.makeImage()
    }
}
