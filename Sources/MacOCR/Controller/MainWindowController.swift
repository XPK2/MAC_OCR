import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    convenience init() {
        let viewController = MainViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "MacOCR"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 800, height: 500)
        window.setContentSize(NSSize(width: 1000, height: 650))
        window.center()
        self.init(window: window)
    }
}
