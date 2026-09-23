import Foundation

enum LogTag {
    case plain, folder, skip, err, warn, done
}

struct SortStats {
    var moved = 0
    var skipped = 0
    var errors = 0
}

@MainActor
final class PhotoSorterEngine {

    static let mediaExts: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tiff", "tif",
        "cr2", "cr3", "nef", "arw", "dng", "rw2", "orf", "raf",
        "mp4", "mov", "m4v", "avi", "mkv", "3gp",
    ]
    static let sidecarExts: Set<String> = ["aae", "xmp", "thm"]
    static let monthNames = [
        "", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    /// Excludes 0/O/1/I/L, which look alike at a glance.
    private static let idAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    private static let idLength = 7
    private static let generatedNamePattern = try! NSRegularExpression(
        pattern: #"^\d{4}-\d{2}-\d{2}-[A-Z2-9]{\#(idLength)}$"#
    )

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let geocodeCache = GeocodeCache()

    func run(
        source: URL,
        log: @escaping (String, LogTag) -> Void,
        progress: @escaping (Int, Int, String) -> Void
    ) async -> SortStats {
        let fm = FileManager.default
        let (mediaFiles, sidecarFiles) = scanFiles(under: source, fm: fm)

        var stats = SortStats()
        var stemToDest: [String: (dir: URL, newStem: String)] = [:]
        let total = mediaFiles.count

        for (index, fileURL) in mediaFiles.enumerated() {
            progress(index + 1, total, fileURL.lastPathComponent)

            let meta = await MetadataReader.read(fileURL)
            let destDir = await destination(for: source, meta: meta)
            let ext = fileURL.pathExtension.lowercased()
            let originalName = fileURL.lastPathComponent

            let alreadySorted = fileURL.deletingLastPathComponent().standardizedFileURL.path == destDir.standardizedFileURL.path
                && (meta.date == nil || isGeneratedName(originalName))
            let newName = alreadySorted
                ? originalName
                : meta.date.map { generatedFilename(date: $0, ext: ext) } ?? originalName

            let target = uniqueDestination(destDir, filename: newName, excluding: fileURL, fm: fm)
            stemToDest[fileURL.deletingPathExtension().lastPathComponent.lowercased()] =
                (destDir, target.deletingPathExtension().lastPathComponent)

            if fileURL.standardizedFileURL.path == target.standardizedFileURL.path {
                stats.skipped += 1
                continue
            }

            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try fm.moveItem(at: fileURL, to: target)
                stats.moved += 1
                let rel = destDir.path.replacingOccurrences(of: source.path + "/", with: "")
                log("  \(pad(originalName, 40))  →  \(rel)/\(target.lastPathComponent)", .folder)
            } catch {
                stats.errors += 1
                log("  ERROR \(originalName): \(error.localizedDescription)", .err)
            }
        }

        for sidecar in sidecarFiles {
            let stem = sidecar.deletingPathExtension().lastPathComponent.lowercased()
            guard let (destDir, newStem) = stemToDest[stem] else { continue }
            let sidecarExt = sidecar.pathExtension
            let newSidecarName = sidecarExt.isEmpty ? newStem : "\(newStem).\(sidecarExt)"
            let target = uniqueDestination(destDir, filename: newSidecarName, excluding: sidecar, fm: fm)
            if sidecar.standardizedFileURL.path == target.standardizedFileURL.path { continue }
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            try? fm.moveItem(at: sidecar, to: target)
        }

        cleanupEmptyDirs(under: source, fm: fm)
        return stats
    }

    private func scanFiles(under source: URL, fm: FileManager) -> (media: [URL], sidecar: [URL]) {
        var mediaFiles: [URL] = []
        var sidecarFiles: [URL] = []

        if let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                    continue
                }
                let ext = url.pathExtension.lowercased()
                if Self.mediaExts.contains(ext) {
                    mediaFiles.append(url)
                } else if Self.sidecarExts.contains(ext) {
                    sidecarFiles.append(url)
                }
            }
        }
        mediaFiles.sort { $0.path < $1.path }
        return (mediaFiles, sidecarFiles)
    }

    private func destination(for source: URL, meta: MediaMetadata) async -> URL {
        guard let date = meta.date else {
            return source.appendingPathComponent("Unknown Date")
        }
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let monthFolder = String(format: "%02d - %@", month, Self.monthNames[month])

        var location = "Unknown Location"
        if let lat = meta.latitude, let lon = meta.longitude,
           let country = await geocodeCache.country(for: lat, lon) {
            location = sanitize(country)
        }

        return source
            .appendingPathComponent(String(year))
            .appendingPathComponent(monthFolder)
            .appendingPathComponent(location)
    }

    /// Renames every sorted file to `yyyy-MM-dd-XXXXXXX.ext`, so that files
    /// from different cameras/phones (which love reusing names like
    /// IMG_0001.jpg) stay unique even if the whole library ends up flattened
    /// into one folder later.
    private func generatedFilename(date: Date, ext: String) -> String {
        let datePart = Self.filenameDateFormatter.string(from: date)
        let id = String((0..<Self.idLength).map { _ in Self.idAlphabet.randomElement()! })
        return ext.isEmpty ? "\(datePart)-\(id)" : "\(datePart)-\(id).\(ext)"
    }

    private func isGeneratedName(_ filename: String) -> Bool {
        let stem = (filename as NSString).deletingPathExtension
        let range = NSRange(stem.startIndex..., in: stem)
        return Self.generatedNamePattern.firstMatch(in: stem, range: range) != nil
    }

    private func sanitize(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(
            of: #"[<>:"/\\|?*\x00-\x1f]"#, with: "-", options: .regularExpression
        )
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
        return String(trimmed.prefix(60))
    }

    /// Picks a non-colliding destination filename. `source` is the file being
    /// moved: if it's already sitting at the naive target (already sorted on
    /// a previous run), that's not a collision, so it's excluded from the
    /// existence check — otherwise a second pass would rename it to `_1`.
    private func uniqueDestination(_ dir: URL, filename: String, excluding source: URL, fm: FileManager) -> URL {
        var target = dir.appendingPathComponent(filename)
        let sourcePath = source.standardizedFileURL.path
        guard target.standardizedFileURL.path != sourcePath, fm.fileExists(atPath: target.path) else {
            return target
        }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var n = 1
        repeat {
            let candidate = ext.isEmpty ? "\(name)_\(n)" : "\(name)_\(n).\(ext)"
            target = dir.appendingPathComponent(candidate)
            n += 1
        } while target.standardizedFileURL.path != sourcePath && fm.fileExists(atPath: target.path)
        return target
    }

    private func cleanupEmptyDirs(under source: URL, fm: FileManager) {
        guard let enumerator = fm.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var dirs: [URL] = []
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                dirs.append(url)
            }
        }
        // Deepest paths first so parents empty out after their children are removed.
        for dir in dirs.sorted(by: { $0.path.count > $1.path.count }) {
            if let contents = try? fm.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }
    }

    private func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
}
