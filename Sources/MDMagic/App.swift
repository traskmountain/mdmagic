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
            CommandGroup(after: .toolbar) {
                Button("Reload") { doc.reload() }
                    .keyboardShortcut("r", modifiers: .command)
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
        WebView(html: doc.html) { url in
            Task { @MainActor in doc.load(url: url) }
        }
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

    func makeNSView(context: Context) -> DroppableWebView {
        let config = WKWebViewConfiguration()
        let view = DroppableWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground") // transparent -> matches window
        view.onFileDrop = onFileDrop
        return view
    }

    func updateNSView(_ view: DroppableWebView, context: Context) {
        view.onFileDrop = onFileDrop
        view.loadHTMLString(html, baseURL: nil)
    }
}
