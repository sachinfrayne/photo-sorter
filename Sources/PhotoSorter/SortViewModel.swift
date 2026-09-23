import Foundation

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let tag: LogTag
}

@MainActor
final class SortViewModel: ObservableObject {
    @Published var folderPath: String
    @Published var isSorting = false
    @Published var isDone = false
    @Published var statusText = "Select your photos folder, then click Sort Photos."
    @Published var progressCurrent = 0
    @Published var progressTotal = 0
    @Published var lines: [LogLine] = []

    private let engine = PhotoSorterEngine()

    init() {
        folderPath = SortViewModel.defaultSourceFolder()?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// When the built app is dropped inside a photos folder, default to that
    /// folder — mirrors "double-click and go" from the previous Python build.
    private static func defaultSourceFolder() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return nil }
        return bundleURL.deletingLastPathComponent()
    }

    func startSort() {
        guard !isSorting else { return }
        let path = folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            statusText = "Folder not found: \(path)"
            return
        }

        isSorting = true
        isDone = false
        lines = []
        progressCurrent = 0
        progressTotal = 0
        let source = URL(fileURLWithPath: path)

        Task {
            let stats = await engine.run(
                source: source,
                log: { [weak self] text, tag in
                    self?.lines.append(LogLine(text: text, tag: tag))
                },
                progress: { [weak self] current, total, name in
                    self?.progressCurrent = current
                    self?.progressTotal = total
                    self?.statusText = "[\(current)/\(total)]  \(name)"
                }
            )
            finish(stats: stats, total: progressTotal)
        }
    }

    private func finish(stats: SortStats, total: Int) {
        if total == 0 {
            statusText = "No media files found."
            lines.append(LogLine(
                text: "No supported photo or video files were found in that folder.",
                tag: .err
            ))
        } else {
            var summary = "Done!  \(stats.moved) moved"
            if stats.skipped > 0 { summary += "  ·  \(stats.skipped) already sorted" }
            if stats.errors > 0 { summary += "  ·  \(stats.errors) errors" }
            lines.append(LogLine(text: "", tag: .plain))
            lines.append(LogLine(text: summary, tag: .done))
            statusText = summary
        }
        isSorting = false
        isDone = true
    }
}
