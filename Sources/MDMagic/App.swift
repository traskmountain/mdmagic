import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - App entry

@main
struct MDMagicApp: App {
    @StateObject private var store = TabStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 620, minHeight: 440)
                .preferredColorScheme(store.appearance.colorScheme)
                .onOpenURL { store.openFile(url: $0) }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Rich Text") { store.newEditorTab() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { store.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { store.active?.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save As Markdown…") { store.active?.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .importExport) {
                Button("Export as HTML…") { store.active?.exportHTML() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Export as PDF…") { store.active?.exportPDF() }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Toggle Dark Mode") { store.appearance.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Edit Source") { store.active?.toggleEditMode() }
                    .keyboardShortcut("e", modifiers: [.command, .option])
                Button("Reload") { store.active?.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Zoom In") { store.active?.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { store.active?.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { store.active?.zoomReset() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

// MARK: - Appearance

enum Appearance: String {
    case system, light, dark
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon.fill"
        }
    }
    mutating func toggle() {
        // Cycle: system -> dark -> light -> system
        switch self {
        case .system: self = .dark
        case .dark:   self = .light
        case .light:  self = .system
        }
    }
}

// MARK: - Tab store

@MainActor
final class TabStore: ObservableObject {
    @Published var tabs: [TabModel] = []
    @Published var activeID: UUID?
    @Published var appearance: Appearance = .system {
        didSet { tabs.forEach { $0.applyAppearance(appearance) } }
    }
    let recents = Recents()

    var active: TabModel? { tabs.first { $0.id == activeID } }

    init() {
        recents.refresh()
        let dash = TabModel(kind: .dashboard)
        dash.title = "Dashboard"
        tabs = [dash]
        activeID = dash.id
    }

    /// Opens (or re-focuses) the dashboard tab.
    func showDashboard() {
        if let existing = tabs.first(where: { $0.kind == .dashboard }) {
            activeID = existing.id
        } else {
            let dash = TabModel(kind: .dashboard)
            dash.title = "Dashboard"
            tabs.insert(dash, at: 0)
            activeID = dash.id
        }
        recents.refresh()
    }

    func newEditorTab() {
        let tab = TabModel(kind: .editor)
        tab.title = "Untitled"
        tab.onSavedToDisk = { [weak self] savedURL in self?.recents.record(url: savedURL) }
        tabs.append(tab)
        activeID = tab.id
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { openFile(url: url) }
    }

    func openFile(url: URL) {
        let tab = TabModel(kind: .markdown)
        tab.loadFile(url: url)
        tab.onSavedToDisk = { [weak self] savedURL in self?.recents.record(url: savedURL) }
        tabs.append(tab)
        activeID = tab.id
        recents.record(url: url)
    }

    func close(_ tab: TabModel) {
        guard let idx = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: idx)
        if activeID == tab.id {
            activeID = tabs.indices.contains(idx) ? tabs[idx].id : tabs.last?.id
        }
        if tabs.isEmpty {
            let dash = TabModel(kind: .dashboard)
            dash.title = "Dashboard"
            tabs = [dash]; activeID = dash.id
        }
    }
}

// MARK: - Tab model

enum TabKind { case markdown, editor, dashboard }

@MainActor
final class TabModel: ObservableObject, Identifiable {
    let id = UUID()
    let kind: TabKind
    @Published var title: String = "Untitled"
    @Published var html: String          // HTML loaded into the web view
    @Published var isEditing: Bool = false // markdown tabs only
    private var markdownSource: String = "" // raw Markdown (viewer tabs)
    private var currentURL: URL?
    weak var webView: WKWebView?
    private(set) lazy var scriptProxy: ScriptMessageProxy = {
        let p = ScriptMessageProxy(); p.tab = self; return p
    }()
    private var autoSaveTimer: Timer?

    var hasCurrentURL: Bool { currentURL != nil }
    /// Called with the destination URL whenever this tab writes a file to disk,
    /// so the store can record it in recents.
    var onSavedToDisk: ((URL) -> Void)?

    init(kind: TabKind) {
        self.kind = kind
        switch kind {
        case .editor:    self.html = EditorTemplate.html
        case .markdown:  self.html = MarkdownRenderer.html(from: "")
        case .dashboard: self.html = ""   // native SwiftUI view, no web content
        }
    }

    func loadMarkdown(text: String, title: String) {
        self.title = title
        self.markdownSource = text
        self.html = MarkdownRenderer.html(from: text)
    }

    func loadFile(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            html = MarkdownRenderer.html(from: "# Could not read file\n\n`\(url.path)`")
            return
        }
        currentURL = url
        title = url.lastPathComponent
        markdownSource = text
        html = MarkdownRenderer.html(from: text)
    }

    func reload() {
        if kind == .markdown, let url = currentURL, !isEditing { loadFile(url: url) }
    }

    func toggleEditMode() {
        guard kind == .markdown else { return }
        if isEditing {
            stopAutoSave()
            webView?.evaluateJavaScript("disableEditing()")
            isEditing = false
        } else {
            webView?.evaluateJavaScript("enableEditing()")
            isEditing = true
            startAutoSave()
        }
    }

    func receiveEditSave(markdown: String) {
        stopAutoSave()
        markdownSource = markdown
        if let url = currentURL { writeToDisk(markdown, to: url) }
        html = MarkdownRenderer.html(from: markdown)
        isEditing = false
    }

    func receiveEditCancel() {
        stopAutoSave()
        isEditing = false
    }

    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.performAutoSave()
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func performAutoSave() {
        guard isEditing, let url = currentURL else { return }
        webView?.evaluateJavaScript("getMarkdown()") { [weak self] result, _ in
            guard let self, let md = result as? String else { return }
            self.markdownSource = md
            self.writeToDisk(md, to: url)
        }
    }

    /// The WebView content uses CSS `prefers-color-scheme`, which follows the *system*
    /// appearance — not SwiftUI's `preferredColorScheme`. So when the user forces a
    /// mode in-app we override `color-scheme` on the document directly.
    func applyAppearance(_ a: Appearance) {
        let scheme: String   // for native controls (scrollbars, color input, etc.)
        let js: String
        switch a {
        case .system:
            scheme = "light dark"
            js = "document.documentElement.removeAttribute('data-theme');"
        case .light:
            scheme = "light"
            js = "document.documentElement.setAttribute('data-theme','light');"
        case .dark:
            scheme = "dark"
            js = "document.documentElement.setAttribute('data-theme','dark');"
        }
        webView?.evaluateJavaScript(
            js + "document.documentElement.style.setProperty('color-scheme','\(scheme)');")
    }

    // MARK: Zoom

    private var zoom: CGFloat = 1.0
    func zoomIn()    { setZoom(zoom + 0.1) }
    func zoomOut()   { setZoom(zoom - 0.1) }
    func zoomReset() { setZoom(1.0) }
    private func setZoom(_ v: CGFloat) {
        zoom = min(max(v, 0.5), 3.0)
        webView?.pageZoom = zoom
    }

    // MARK: Save (Markdown)

    /// Save in-place if the file has a known URL; show Save As panel otherwise.
    func save() {
        switch kind {
        case .dashboard: return
        case .editor: saveAs()
        case .markdown:
            if isEditing {
                webView?.evaluateJavaScript("getMarkdown()") { [weak self] result, _ in
                    guard let self, let md = result as? String else { return }
                    self.receiveEditSave(markdown: md)
                }
            } else if let url = currentURL {
                writeToDisk(markdownSource, to: url)
            } else {
                saveAs()
            }
        }
    }

    private func writeToDisk(_ text: String, to url: URL) {
        do { try text.write(to: url, atomically: true, encoding: .utf8) }
        catch { presentError("Could not save: \(error.localizedDescription)") }
    }

    /// Show Save As panel. Editor tabs serialize rich content to Markdown first;
    /// markdown tabs use their raw source (extracting from the textarea when in edit mode).
    func saveAs() {
        switch kind {
        case .dashboard:
            return
        case .editor:
            guard let webView else { return }
            webView.evaluateJavaScript("toMarkdown()") { [weak self] result, _ in
                self?.writeMarkdown((result as? String) ?? "")
            }
        case .markdown:
            if isEditing {
                webView?.evaluateJavaScript("getMarkdown()") { [weak self] result, _ in
                    guard let self, let md = result as? String else { return }
                    self.writeMarkdown(md)
                }
            } else {
                writeMarkdown(markdownSource)
            }
        }
    }

    private func writeMarkdown(_ text: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        let base = (title as NSString).deletingPathExtension
        panel.nameFieldStringValue = (base.isEmpty ? "Untitled" : base) + ".md"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, var dest = panel.url else { return }
        if dest.pathExtension.lowercased() != "md" { dest.appendPathExtension("md") }
        do {
            try text.write(to: dest, atomically: true, encoding: .utf8)
            title = dest.lastPathComponent
            currentURL = dest
            markdownSource = text
            onSavedToDisk?(dest)
        } catch { presentError("Could not save: \(error.localizedDescription)") }
    }

    // MARK: Export (HTML)

    func exportHTML() {
        if kind == .editor {
            guard let webView else { return }
            webView.evaluateJavaScript("document.getElementById('editor').innerHTML") { [weak self] result, _ in
                guard let self else { return }
                let base = (self.title as NSString).deletingPathExtension
                self.writeHTML(Self.standaloneEditorHTML(body: (result as? String) ?? "", title: base))
            }
        } else {
            writeHTML(html)
        }
    }

    private func writeHTML(_ document: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        let base = (title as NSString).deletingPathExtension
        panel.nameFieldStringValue = (base.isEmpty ? "Document" : base) + ".html"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, var dest = panel.url else { return }
        if dest.pathExtension.lowercased() != "html" { dest.appendPathExtension("html") }
        do { try document.write(to: dest, atomically: true, encoding: .utf8) }
        catch { presentError("Could not export: \(error.localizedDescription)") }
    }

    // MARK: Export (PDF) — works for both viewer and editor tabs

    func exportPDF() {
        guard let webView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let base = (title as NSString).deletingPathExtension
        panel.nameFieldStringValue = (base.isEmpty ? "Document" : base) + ".pdf"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        let forceLight = """
        document.documentElement.style.setProperty('color-scheme','light');
        var s=document.getElementById('__pdf_light__');
        if(!s){s=document.createElement('style');s.id='__pdf_light__';
          s.textContent=':root{--bg:#fff;--fg:#1f2328;--muted:#59636e;--border:#d1d9e0;--link:#0969da;--code-bg:#f6f8fa;--code-fg:#1f2328;--quote-border:#d0d7de;--quote-fg:#59636e;--th-bg:#f6f8fa;--hr:#d1d9e0;--bar-bg:#f6f8fa;--kw:#cf222e;--str:#0a3069;--num:#0550ae;--com:#59636e;--fn:#8250df;}body{background:#fff;}#toolbar{display:none;}#editor{padding-top:40px;}';
          document.head.appendChild(s);}
        """
        webView.evaluateJavaScript(forceLight) { [weak self] _, _ in
            webView.createPDF(configuration: WKPDFConfiguration()) { result in
                webView.evaluateJavaScript("var e=document.getElementById('__pdf_light__');if(e)e.remove();document.documentElement.style.removeProperty('color-scheme');")
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

    private static func standaloneEditorHTML(body: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(title.isEmpty ? "Document" : title)</title>
        <meta name="color-scheme" content="light dark">
        <style>
        body{font-family:-apple-system,"Helvetica Neue",sans-serif;font-size:16px;
        line-height:1.65;max-width:860px;margin:0 auto;padding:40px 56px;color:#1f2328;background:#fff;}
        @media (prefers-color-scheme:dark){body{color:#e6edf3;background:#0d1117;}}
        h1{font-size:2em}h2{font-size:1.5em}h3{font-size:1.25em}
        blockquote{margin:0 0 1em;padding:.2em 1em;border-left:.25em solid #d0d7de;color:#59636e}
        pre,code{font-family:"SF Mono",Menlo,monospace;background:#f6f8fa;border-radius:6px}
        code{padding:.15em .4em}pre{padding:14px 16px;overflow-x:auto}
        img{max-width:100%;border-radius:8px}a{color:#0969da}
        </style></head>
        <body>
        \(body)
        </body></html>
        """
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Save"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    static let welcome = """
    # MDMagic ✨

    A **lightweight** native macOS Markdown viewer with *rich* color and text.

    Drag a `.md` file onto this window, or press **⌘O** to open one.
    Click **＋ New** in the top bar to start a **rich-text document** — no Markdown required.

    ## Features

    - Dashboard of your **recent documents** with created / modified dates
    - GitHub-flavored Markdown viewer
    - WYSIWYG rich-text editor (New tab)
    - **Save** as Markdown (⌘S); **Export** as HTML or PDF
    - Light / **dark** mode (⇧⌘D)

    ```swift
    func greet(_ name: String) -> String {
        return "Hello, \\(name)!"  // rich highlighting
    }
    ```

    | Feature | Supported |
    |---------|:---------:|
    | Viewer  | ✅ |
    | Editor  | ✅ |
    | PDF     | ✅ |
    """
}

// MARK: - Main view

struct ContentView: View {
    @ObservedObject var store: TabStore

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(store: store)
            Divider()
            ZStack {
                ForEach(store.tabs) { tab in
                    TabContentView(tab: tab)
                        .environmentObject(store)
                        .opacity(tab.id == store.activeID ? 1 : 0)
                        .allowsHitTesting(tab.id == store.activeID)
                }
            }
        }
        .background {
            // Hidden catcher so ⌘= (zoom-in without Shift) also works.
            Button("") { store.active?.zoomIn() }
                .keyboardShortcut("=", modifiers: .command).opacity(0)
        }
    }
}

// MARK: - Top nav bar

struct TopNavBar: View {
    @ObservedObject var store: TabStore

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { store.showDashboard() }) {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .help("Show recent documents dashboard")

            Button(action: { store.newEditorTab() }) {
                Label("New", systemImage: "plus")
            }
            .help("New rich-text document (⌘N)")

            Button(action: { store.openPanel() }) {
                Label("Open", systemImage: "folder")
            }
            .help("Open a Markdown file (⌘O)")

            Button(action: { store.active?.save() }) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save current tab (⌘S)")

            if let active = store.active, active.kind == .markdown {
                EditToggleButton(tab: active)
            }

            Menu {
                Button("Export as HTML…") { store.active?.exportHTML() }
                Button("Export as PDF…")  { store.active?.exportPDF() }
            } label: {
                Label("Export", systemImage: "arrow.down.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export current tab as HTML or PDF")

            Divider().frame(height: 18)

            // Tab strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.tabs) { tab in
                        TabChip(tab: tab,
                                isActive: tab.id == store.activeID,
                                onSelect: { store.activeID = tab.id },
                                onClose: { store.close(tab) })
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: { store.appearance.toggle() }) {
                Image(systemName: store.appearance.icon)
            }
            .help("Toggle light / dark (⇧⌘D)")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 44)
        .background(.bar)
    }
}

struct EditToggleButton: View {
    @ObservedObject var tab: TabModel

    var body: some View {
        Button(action: { tab.toggleEditMode() }) {
            Label(tab.isEditing ? "Preview" : "Edit",
                  systemImage: tab.isEditing ? "eye" : "pencil.line")
        }
        .help(tab.isEditing ? "Switch to rendered preview" : "Edit markdown source")
    }
}

struct TabChip: View {
    @ObservedObject var tab: TabModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var tabIcon: String {
        switch tab.kind {
        case .editor:    return "pencil"
        case .markdown:  return "doc.text"
        case .dashboard: return "square.grid.2x2"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tabIcon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .frame(maxWidth: 160)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.25),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Tab content

struct TabContentView: View {
    @ObservedObject var tab: TabModel
    @EnvironmentObject var store: TabStore

    var body: some View {
        if tab.kind == .dashboard {
            DashboardView(store: store)
        } else {
            WebView(html: tab.html,
                    editable: tab.kind == .editor,
                    onFileDrop: { url in
                        if tab.kind == .markdown { tab.loadFile(url: url) }
                    },
                    onCreate: { view in tab.webView = view },
                    onLoad: { tab.applyAppearance(store.appearance) },
                    messageProxy: tab.kind == .markdown ? tab.scriptProxy : nil)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var store: TabStore
    @ObservedObject var recents: Recents

    init(store: TabStore) {
        self.store = store
        self.recents = store.recents
    }

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MDMagic").font(.system(size: 28, weight: .bold))
                        Text("Recent documents").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.newEditorTab()
                    } label: { Label("New", systemImage: "plus") }
                    Button {
                        store.openPanel()
                    } label: { Label("Open", systemImage: "folder") }
                }

                if recents.files.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(recents.files) { file in
                            FileTile(file: file) { store.openFile(url: file.url) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { recents.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text("No recent documents yet")
                .font(.system(size: 16, weight: .medium))
            Text("Open a Markdown file or create a new document — it'll show up here.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct FileTile: View {
    let file: RecentFile
    let onOpen: () -> Void
    @State private var hovering = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()
    private func fmt(_ d: Date?) -> String { d.map { Self.dateFmt.string(from: $0) } ?? "—" }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1).truncationMode(.middle)
                        Text(file.url.deletingLastPathComponent().lastPathComponent)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    Label("Created  \(fmt(file.created))", systemImage: "calendar.badge.plus")
                    Label("Modified \(fmt(file.modified))", systemImage: "pencil")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Script message handler (weak proxy to avoid retain cycles)

final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var tab: TabModel?
    func userContentController(_ c: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any],
              let action = body["action"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let tab = self?.tab else { return }
            switch action {
            case "save":
                tab.receiveEditSave(markdown: (body["content"] as? String) ?? "")
            case "cancel":
                tab.receiveEditCancel()
            default: break
            }
        }
    }
}

// MARK: - WKWebView wrapper

final class DroppableWebView: WKWebView {
    var onFileDrop: ((URL) -> Void)?

    private func setup() { registerForDraggedTypes([.fileURL]) }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder); setup()
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

    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation {
        firstURL(in: s) != nil ? .copy : []
    }
    override func draggingUpdated(_ s: NSDraggingInfo) -> NSDragOperation {
        firstURL(in: s) != nil ? .copy : []
    }
    override func prepareForDragOperation(_ s: NSDraggingInfo) -> Bool {
        firstURL(in: s) != nil
    }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        guard let url = firstURL(in: s) else { return false }
        onFileDrop?(url); return true
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    let editable: Bool
    let onFileDrop: (URL) -> Void
    let onCreate: (DroppableWebView) -> Void
    let onLoad: () -> Void
    var messageProxy: ScriptMessageProxy?

    func makeNSView(context: Context) -> DroppableWebView {
        let config = WKWebViewConfiguration()
        if let proxy = messageProxy {
            config.userContentController.add(proxy, name: "mdmagic")
        }
        let view = DroppableWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.onFileDrop = onFileDrop
        view.navigationDelegate = context.coordinator
        view.loadHTMLString(html, baseURL: nil)
        onCreate(view)
        return view
    }

    func updateNSView(_ view: DroppableWebView, context: Context) {
        view.onFileDrop = onFileDrop
        // Editor tabs are interactive — never reload their HTML or we'd wipe the
        // user's work. Viewer tabs reload when their html changes.
        if !editable, context.coordinator.lastHTML != html {
            view.loadHTMLString(html, baseURL: nil)
            context.coordinator.lastHTML = html
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(html: html, onLoad: onLoad) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String
        let onLoad: () -> Void
        init(html: String, onLoad: @escaping () -> Void) {
            self.lastHTML = html; self.onLoad = onLoad
        }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { onLoad() }
    }
}
