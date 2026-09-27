import AppKit
import UniformTypeIdentifiers

final class DropZoneView: NSView {
    var onFilesDropped: (([URL]) -> Void)?

    private let label: NSTextField = {
        let field = NSTextField(labelWithString: "Kéo thả ảnh hoặc PDF vào đây\nhoặc bấm Open…")
        field.alignment = .center
        field.font = .systemFont(ofSize: 14)
        field.textColor = .secondaryLabelColor
        field.maximumNumberOfLines = 2
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    var statusText: String = "" {
        didSet { label.stringValue = statusText.isEmpty ? defaultText : statusText }
    }

    private let defaultText = "Kéo thả ảnh hoặc PDF vào đây\nhoặc bấm Open…"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 8

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])

        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        let urls = (sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }
}
