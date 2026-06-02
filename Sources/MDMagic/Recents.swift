import Foundation

/// A single recently-opened Markdown file, with its created / modified dates.
struct RecentFile: Identifiable, Codable, Equatable {
    var id: String { path }      // path is the unique key
    let path: String
    var name: String
    var created: Date?
    var modified: Date?
    var lastOpened: Date

    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

/// Persists the list of recently opened/saved files (most-recent first, max 10).
@MainActor
final class Recents: ObservableObject {
    @Published private(set) var files: [RecentFile] = []
    private let key = "mdmagic.recents"
    private let limit = 10

    init() { load() }

    func record(url: URL) {
        let path = url.standardizedFileURL.path
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let entry = RecentFile(
            path: path,
            name: url.lastPathComponent,
            created: attrs?[.creationDate] as? Date,
            modified: attrs?[.modificationDate] as? Date,
            lastOpened: Date()
        )
        files.removeAll { $0.path == path }
        files.insert(entry, at: 0)
        if files.count > limit { files = Array(files.prefix(limit)) }
        save()
    }

    /// Re-reads file metadata and drops entries that no longer exist on disk.
    func refresh() {
        files = files.compactMap { f in
            guard f.exists else { return nil }
            var f = f
            let attrs = try? FileManager.default.attributesOfItem(atPath: f.path)
            f.created = attrs?[.creationDate] as? Date
            f.modified = attrs?[.modificationDate] as? Date
            return f
        }
        save()
    }

    func clear() { files = []; save() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentFile].self, from: data)
        else { return }
        files = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
