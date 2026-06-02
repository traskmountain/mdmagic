import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - App entry

@main
struct MDMagicApp: App {
    @StateObject private var doc = DocumentModel()

    var body: some Scene {
        WindowGroup {
            ContentView(doc: doc)
                .frame(minWidth: 520, minHeight: 400)
                .onOpenURL { doc.load(url: $0) }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { doc.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .importExport) {
                Button("Export as PDF…") { doc.exportPDF() }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Reload") { doc.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                // ⌘+ is physically ⌘= ; bind both so it works with or without Shift.
                Button("Zoom In") { doc.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { doc.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { doc.zoomReset() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

// MARK: - Document model

@MainActor
final class DocumentModel: ObservableObject {
    @Published var html: String = MarkdownRenderer.html(from: DocumentModel.welcome)
    @Published var fileName: String = "Welcome"
    private var currentURL: URL?
    weak var webView: WKWebView?

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { load(url: url) }
    }

    func load(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            html = MarkdownRenderer.html(from: "# Could not read file\n\n`\(url.path)`")
            return
        }
        currentURL = url
        fileName = url.lastPathComponent
        html = MarkdownRenderer.html(from: text)
    }

    func reload() {
        if let url = currentURL { load(url: url) }
    }

    /// Exports the currently rendered document to a PDF via a save panel.
    /// Forces light styling so the PDF prints cleanly regardless of system appearance.
    func exportPDF() {
        guard let webView else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let base = (fileName as NSString).deletingPathExtension
        panel.nameFieldStringValue = (base.isEmpty ? "Document" : base) + ".pdf"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let dest = panel.url else { return }

        // Force a light color scheme on the DOM so the exported PDF isn't dark.
        let forceLight = """
        document.documentElement.style.setProperty('color-scheme', 'light');
        var s = document.getElementById('__pdf_light__');
        if (!s) { s = document.createElement('style'); s.id = '__pdf_light__';
          s.textContent = ':root{--bg:#fff;--fg:#1f2328;--muted:#59636e;--border:#d1d9e0;--link:#0969da;--code-bg:#f6f8fa;--code-fg:#1f2328;--quote-border:#d0d7de;--quote-fg:#59636e;--th-bg:#f6f8fa;--hr:#d1d9e0;--kw:#cf222e;--str:#0a3069;--num:#0550ae;--com:#59636e;--fn:#8250df;}body{background:#fff;}';
          document.head.appendChild(s); }
        """
        webView.evaluateJavaScript(forceLight) { [weak self] _, _ in
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                // Remove the forced-light override afterwards.
                webView.evaluateJavaScript(
                    "var e=document.getElementById('__pdf_light__'); if(e)e.remove(); document.documentElement.style.removeProperty('color-scheme');")
                switch result {
                case .success(let data):
                    do { try data.write(to: dest) }
                    catch { self?.presentError("Could not save PDF: \(error.localizedDescription)") }
                case .failure(let error):
                    self?.presentError("PDF export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Zoom

    func zoomIn()    { setZoom(zoom + 0.1) }
    func zoomOut()   { setZoom(zoom - 0.1) }
    func zoomReset() { setZoom(1.0) }

    private var zoom: CGFloat = 1.0
    private func setZoom(_ value: CGFloat) {
        zoom = min(max(value, 0.5), 3.0)
        webView?.pageZoom = zoom
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Export to PDF"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    static let welcome = """
    # MDMagic ✨

    A **lightweight** native macOS Markdown viewer with *rich* color and text.

    Drag a `.md` file onto this window, or press **⌘O** to open one.

    ## Features

    - GitHub-flavored Markdown
    - Syntax-highlighted code blocks
    - Tables, task lists, blockquotes
    - Automatic **light / dark** mode

    ```swift
    func greet(_ name: String) -> String {
        return "Hello, \\(name)!"  // rich highlighting
    }
    ```

    > Press **⌘R** to reload the current file.

    | Feature | Supported |
    |---------|:---------:|
    | Tables  | ✅ |
    | Code    | ✅ |
    | Images  | ✅ |

    - [x] Open a file
    - [ ] Enjoy reading
    """
}

// MARK: - Main view

struct ContentView: View {
    @ObservedObject var doc: DocumentModel

    var body: some View {
        WebView(html: doc.html, onFileDrop: { url in
            Task { @MainActor in doc.load(url: url) }
        }, onCreate: { view in
            doc.webView = view
        })
            .ignoresSafeArea()
            .navigationTitle(doc.fileName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { doc.openPanel() } label: { Image(systemName: "folder") }
                        .help("Open a Markdown file (⌘O)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { doc.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Reload (⌘R)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { doc.exportPDF() } label: { Image(systemName: "square.and.arrow.up") }
                        .help("Export as PDF (⌘E)")
                }
            }
            .background {
                // Hidden catcher so ⌘= (zoom-in without Shift) also works.
                Button("") { doc.zoomIn() }
                    .keyboardShortcut("=", modifiers: .command)
                    .opacity(0)
            }
    }
}

// MARK: - WKWebView wrapper

/// A WKWebView that accepts dragged Markdown files. WebKit registers its own
/// drag handlers, so dropping onto a plain WKWebView never reaches SwiftUI's
/// `.onDrop`. This subclass intercepts file drags itself.
final class DroppableWebView: WKWebView {
    var onFileDrop: ((URL) -> Void)?

    override func awakeFromNib() { super.awakeFromNib() }

    private func setup() {
        registerForDraggedTypes([.fileURL])
    }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func firstURL(in dragging: NSDraggingInfo) -> URL? {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["net.daringfireball.markdown",
                                                "public.text", "public.plain-text"]
        ]
        let urls = dragging.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: opts) as? [URL]
        return urls?.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        firstURL(in: sender) != nil ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        firstURL(in: sender) != nil ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        firstURL(in: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = firstURL(in: sender) else { return false }
        onFileDrop?(url)
        return true
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    let onFileDrop: (URL) -> Void
    let onCreate: (DroppableWebView) -> Void

    func makeNSView(context: Context) -> DroppableWebView {
        let config = WKWebViewConfiguration()
        let view = DroppableWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground") // transparent -> matches window
        view.onFileDrop = onFileDrop
        onCreate(view)
        return view
    }

    func updateNSView(_ view: DroppableWebView, context: Context) {
        view.onFileDrop = onFileDrop
        view.loadHTMLString(html, baseURL: nil)
    }
}
