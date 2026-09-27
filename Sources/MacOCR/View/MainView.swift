import AppKit

final class MainView: NSView {
    let openButton = NSButton(title: "Open…", target: nil, action: nil)
    let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let markLowConfidenceCheckbox = NSButton(checkboxWithTitle: "Mark low confidence", target: nil, action: nil)
    let exportButton = NSButton(title: "Export .md", target: nil, action: nil)
    let copyButton = NSButton(title: "Copy", target: nil, action: nil)

    let dropZoneView = DropZoneView()
    let previewTextView = NSTextView()
    let previewScrollView = NSScrollView()

    let progressIndicator = NSProgressIndicator()
    let pageLabel = NSTextField(labelWithString: "")
    let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    let statusLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let topBar = NSStackView(views: [
            openButton, languagePopUp, markLowConfidenceCheckbox,
            spacerView(), exportButton, copyButton
        ])
        topBar.orientation = .horizontal
        topBar.spacing = 8
        topBar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        topBar.translatesAutoresizingMaskIntoConstraints = false

        previewTextView.isEditable = true
        previewTextView.isRichText = false
        previewTextView.allowsUndo = true
        previewTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.isAutomaticQuoteSubstitutionEnabled = false
        previewTextView.isAutomaticDashSubstitutionEnabled = false
        previewTextView.isAutomaticTextReplacementEnabled = false
        previewTextView.textContainerInset = NSSize(width: 8, height: 8)
        previewTextView.minSize = NSSize(width: 0, height: 0)
        previewTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.autoresizingMask = [.width]
        previewTextView.textContainer?.widthTracksTextView = true

        previewScrollView.documentView = previewTextView
        previewScrollView.hasVerticalScroller = true
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(dropZoneView)
        splitView.addArrangedSubview(previewScrollView)
        splitView.setHoldingPriority(.defaultLow + 1, forSubviewAt: 0)

        progressIndicator.style = .bar
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.isIndeterminate = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.isEnabled = false

        let bottomBar = NSStackView(views: [progressIndicator, pageLabel, cancelButton, statusLabel])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.widthAnchor.constraint(equalToConstant: 160).isActive = true

        addSubview(topBar)
        addSubview(splitView)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: topAnchor),
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            splitView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func spacerView() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }
}
