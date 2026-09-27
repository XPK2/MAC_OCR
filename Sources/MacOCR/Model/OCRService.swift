import Foundation
import Vision
import CoreGraphics
import ImageIO

public enum OCRService {
    /// Languages supported by Vision text recognition on this machine, at runtime.
    /// Must not be hard-coded: availability (e.g. Vietnamese) varies by OS/hardware.
    public static func supportedLanguages() throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return try request.supportedRecognitionLanguages()
    }

    /// Synchronous: `perform` blocks until done, so call it off the main thread.
    /// Empty `languages` → Vision auto-detects.
    public static func recognizeText(
        in image: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        languages: [String]
    ) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = languages.isEmpty
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])

        let lines: [OCRLine] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRLine(text: candidate.string, confidence: candidate.confidence, boundingBox: observation.boundingBox)
        }
        return sortReadingOrder(lines)
    }

    /// Vision's boundingBox origin is bottom-left; reading order is top-to-bottom, left-to-right.
    /// Lines whose vertical center falls inside the current row's first line are treated as the same row,
    /// so slight baseline jitter doesn't reorder words on one visual line.
    // ponytail: row bucketing only; true multi-column layouts still interleave column lines.
    static func sortReadingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        var rows: [[OCRLine]] = []
        for line in lines.sorted(by: { $0.boundingBox.maxY > $1.boundingBox.maxY }) {
            if let anchor = rows.last?.first, line.boundingBox.midY > anchor.boundingBox.minY {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
    }
}
