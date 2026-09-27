import Foundation
import CoreGraphics

public struct OCRLine: Sendable, Equatable {
    public let text: String
    public let confidence: Float
    /// Normalized bounding box, origin bottom-left (Vision convention).
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
