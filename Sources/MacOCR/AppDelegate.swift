import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
        NSApp.activate()
    }

    /// Finder "Open With", drag onto the Dock icon, `open -a MacOCR file.pdf`.
    /// Can arrive before `applicationDidFinishLaunching` on a cold launch, hence `showMainWindow()` here too.
    func application(_ application: NSApplication, open urls: [URL]) {
        showMainWindow().open(urls: urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @discardableResult
    private func showMainWindow() -> MainViewController {
        let controller = windowController ?? MainWindowController()
        windowController = controller
        controller.showWindow(nil)
        return controller.contentViewController as! MainViewController
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MacOCR", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide MacOCR", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit MacOCR", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(MainViewController.performOpen(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Export .md", action: #selector(MainViewController.performExport(_:)), keyEquivalent: "s")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = windowMenu

        for menu in [appMenu, fileMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }
}
