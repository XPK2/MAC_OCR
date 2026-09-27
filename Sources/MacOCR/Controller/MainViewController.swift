import AppKit
import UniformTypeIdentifiers

@MainActor
final class MainViewController: NSViewController {
    private let mainView = MainView()
    private var documents: [OCRDocument] = []
    private var currentTask: Task<Void, Never>?
    private var availableLanguages: [String] = []

    override func loadView() {
        view = mainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        wireActions()
        mainView.dropZoneView.onFilesDropped = { [weak self] urls in
            self?.open(urls: urls)
        }
        loadSupportedLanguages()
        updateResultControlsEnabled()
    }

    private func wireActions() {
        mainView.openButton.target = self
        mainView.openButton.action = #selector(performOpen(_:))
        mainView.exportButton.target = self
        mainView.exportButton.action = #selector(performExport(_:))
        mainView.copyButton.target = self
        mainView.copyButton.action = #selector(performCopy(_:))
        mainView.cancelButton.target = self
        mainView.cancelButton.action = #selector(performCancel(_:))
        mainView.markLowConfidenceCheckbox.target = self
        mainView.markLowConfidenceCheckbox.action = #selector(toggleMarkLowConfidence(_:))
    }

    private func loadSupportedLanguages() {
        Task.detached { [weak self] in
            let languages = (try? OCRService.supportedLanguages())?.sorted() ?? []
            await self?.populateLanguages(languages)
        }
    }

    private func populateLanguages(_ languages: [String]) {
        availableLanguages = languages
        mainView.languagePopUp.removeAllItems()
        mainView.languagePopUp.addItem(withTitle: "Automatic")
        mainView.languagePopUp.addItems(withTitles: languages)
    }

    private var selectedLanguages: [String] {
        guard mainView.languagePopUp.indexOfSelectedItem > 0,
              let title = mainView.languagePopUp.titleOfSelectedItem else {
            return []
        }
        return [title]
    }

    private var automaticallyDetectsLanguage: Bool {
        selectedLanguages.isEmpty
    }

    // MARK: - Actions

    @objc func performOpen(_ sender: Any?) {
        guard currentTask == nil else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .pdf]
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.open(urls: panel.urls)
        }
    }

    @objc private func performCancel(_ sender: Any?) {
        currentTask?.cancel()
    }

    @objc private func performCopy(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(mainView.previewTextView.string, forType: .string)
    }

    @objc private func toggleMarkLowConfidence(_ sender: Any?) {
        guard !documents.isEmpty else { return }
        renderPreview(markLowConfidence: mainView.markLowConfidenceCheckbox.state == .on)
    }

    @objc func performExport(_ sender: Any?) {
        guard !documents.isEmpty else { return }
        if documents.count == 1 {
            exportMerged()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Xuất nhiều file"
        alert.informativeText = "Bạn muốn gộp thành 1 file .md hay xuất mỗi file 1 .md?"
        alert.addButton(withTitle: "Gộp 1 file")
        alert.addButton(withTitle: "Mỗi file 1 .md")
        alert.addButton(withTitle: "Huỷ")
        switch alert.runModal() {
        case .alertFirstButtonReturn: exportMerged()
        case .alertSecondButtonReturn: exportSeparately()
        default: break
        }
    }

    private func exportMerged() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultMergedFileName()
        if let directory = documents.first?.sourceURL.deletingLastPathComponent() {
            panel.directoryURL = directory
        }
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.write(self.mainView.previewTextView.string, to: url)
        }
    }

    private func exportSeparately() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Chọn thư mục"
        panel.begin { [weak self] response in
            guard let self, response == .OK, let directory = panel.url else { return }
            let markLow = self.mainView.markLowConfidenceCheckbox.state == .on
            for document in self.documents {
                let name = document.sourceURL.deletingPathExtension().lastPathComponent
                let markdown = MarkdownExporter.export(document, markLowConfidence: markLow)
                self.write(markdown, to: directory.appendingPathComponent("\(name).md"))
            }
        }
    }

    private func defaultMergedFileName() -> String {
        guard let first = documents.first else { return "OCR.md" }
        let base = first.sourceURL.deletingPathExtension().lastPathComponent
        return documents.count == 1 ? "\(base).md" : "\(base)_and_more.md"
    }

    private func write(_ text: String, to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showError(details: error.localizedDescription)
        }
    }

    // MARK: - Processing pipeline (runs off the main thread; only UI updates hop back to @MainActor)

    /// Entry point for Open panel, drag & drop, Finder "Open With" and Dock drops.
    func open(urls: [URL]) {
        guard currentTask == nil else { NSSound.beep(); return }
        let supported = urls.filter(DocumentLoader.isSupported)
        let rejected = urls.filter { !DocumentLoader.isSupported($0) }
        if !rejected.isEmpty {
            showError(message: "Bỏ qua file không hỗ trợ", details: rejected.map(\.lastPathComponent).joined(separator: "\n"))
        }
        guard !supported.isEmpty else { return }

        documents = []
        mainView.previewTextView.string = ""
        mainView.openButton.isEnabled = false
        mainView.cancelButton.isEnabled = true
        mainView.progressIndicator.doubleValue = 0
        mainView.pageLabel.stringValue = ""
        // First OCR on a Mac triggers a one-time Neural Engine model compile (can take minutes).
        let firstRun = !UserDefaults.standard.bool(forKey: "didRunOCR")
        mainView.statusLabel.stringValue = firstRun ? "Đang xử lý… (lần đầu trên máy này có thể mất 1–3 phút)" : "Đang xử lý…"
        mainView.dropZoneView.statusText = supported.map(\.lastPathComponent).joined(separator: "\n")
        updateResultControlsEnabled()

        let languages = selectedLanguages
        let markLow = mainView.markLowConfidenceCheckbox.state == .on

        currentTask = Task.detached { [weak self] in
            var documents: [OCRDocument] = []
            var failures: [String] = []

            // Opening is cheap (no rendering) — done up front only to know the total page count.
            var loaders: [DocumentLoader] = []
            for url in supported {
                do { loaders.append(try DocumentLoader(url: url)) }
                catch { failures.append(error.localizedDescription) }
            }
            let totalPages = max(loaders.reduce(0) { $0 + $1.pageCount }, 1)
            var done = 0

            do {
                for loader in loaders {
                    var pages: [OCRPage] = []
                    do {
                        for index in 0..<loader.pageCount {
                            try Task.checkCancellation()
                            switch try loader.page(at: index) {
                            case .text(let text):
                                pages.append(OCRPage.fromPlainText(text, index: index + 1))
                            case .image(let image, let orientation):
                                let lines = try OCRService.recognizeText(in: image, orientation: orientation, languages: languages)
                                pages.append(OCRPage(index: index + 1, lines: lines))
                            }
                            done += 1
                            await self?.updateProgress(done: done, total: totalPages)
                        }
                        documents.append(OCRDocument(sourceURL: loader.url, pages: pages, languages: languages))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        failures.append("\(loader.url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                await self?.finishProcessing(documents: documents, failures: failures, markLowConfidence: markLow)
            } catch {
                await self?.finishCancelled()
            }
        }
    }

    private func updateProgress(done: Int, total: Int) {
        mainView.progressIndicator.maxValue = Double(max(total, 1))
        mainView.progressIndicator.doubleValue = Double(done)
        mainView.pageLabel.stringValue = "Trang \(done)/\(total)"
    }

    private func finishProcessing(documents: [OCRDocument], failures: [String], markLowConfidence: Bool) {
        UserDefaults.standard.set(true, forKey: "didRunOCR")
        endProcessing(status: failures.isEmpty ? "Hoàn tất" : "Hoàn tất (\(failures.count) file lỗi)")
        self.documents = documents
        renderPreview(markLowConfidence: markLowConfidence)
        updateResultControlsEnabled()
        if !failures.isEmpty {
            showError(message: "Một số file không xử lý được", details: failures.joined(separator: "\n"))
        }
    }

    private func finishCancelled() {
        endProcessing(status: "Đã huỷ")
    }

    private func endProcessing(status: String) {
        currentTask = nil
        mainView.openButton.isEnabled = true
        mainView.cancelButton.isEnabled = false
        mainView.statusLabel.stringValue = status
    }

    private func renderPreview(markLowConfidence: Bool) {
        mainView.previewTextView.string = documents
            .map { MarkdownExporter.export($0, markLowConfidence: markLowConfidence) }
            .joined(separator: "\n")
    }

    private func updateResultControlsEnabled() {
        let hasResult = !documents.isEmpty
        mainView.exportButton.isEnabled = hasResult
        mainView.copyButton.isEnabled = hasResult
    }

    private func showError(message: String = "Đã xảy ra lỗi", details: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = details
        alert.runModal()
    }
}
