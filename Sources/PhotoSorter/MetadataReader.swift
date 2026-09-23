import Foundation
import ImageIO
import AVFoundation

struct MediaMetadata {
    var date: Date?
    var latitude: Double?
    var longitude: Double?
}

enum MetadataReader {

    static let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "3gp"]

    private static let exifFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func read(_ url: URL) async -> MediaMetadata {
        let ext = url.pathExtension.lowercased()
        let meta = videoExts.contains(ext) ? await readVideo(url) : readImage(url)
        if meta.date != nil {
            return meta
        }
        return MediaMetadata(date: fileDate(url), latitude: meta.latitude, longitude: meta.longitude)
    }

    private static func readImage(_ url: URL) -> MediaMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return MediaMetadata()
        }

        var lat: Double?
        var lon: Double?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            if let latVal = gps[kCGImagePropertyGPSLatitude] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
                lat = latRef.uppercased() == "S" ? -latVal : latVal
            }
            if let lonVal = gps[kCGImagePropertyGPSLongitude] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                lon = lonRef.uppercased() == "W" ? -lonVal : lonVal
            }
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let s = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                date = exifFormatter.date(from: s)
            } else if let s = exif[kCGImagePropertyExifDateTimeDigitized] as? String {
                date = exifFormatter.date(from: s)
            }
        }
        if date == nil, let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let s = tiff[kCGImagePropertyTIFFDateTime] as? String {
            date = exifFormatter.date(from: s)
        }

        return MediaMetadata(date: date, latitude: lat, longitude: lon)
    }

    private static func readVideo(_ url: URL) async -> MediaMetadata {
        let asset = AVURLAsset(url: url)
        var date: Date?
        var lat: Double?
        var lon: Double?

        if let item = try? await asset.load(.creationDate) {
            if let d = try? await item.load(.dateValue) {
                date = d
            } else if let s = try? await item.load(.stringValue) {
                date = ISO8601DateFormatter().date(from: s) ?? exifFormatter.date(from: s)
            }
        }

        if let items = try? await asset.load(.metadata) {
            for item in items where item.commonKey == .commonKeyLocation {
                if let s = try? await item.load(.stringValue) {
                    (lat, lon) = parseISO6709(s)
                }
            }
        }

        if lat == nil, let items = try? await asset.loadMetadata(for: .quickTimeMetadata) {
            for item in items where (item.key as? String) == "com.apple.quicktime.location.ISO6709" {
                if let s = try? await item.load(.stringValue) {
                    (lat, lon) = parseISO6709(s)
                }
            }
        }

        return MediaMetadata(date: date, latitude: lat, longitude: lon)
    }

    private static func parseISO6709(_ s: String) -> (Double?, Double?) {
        let pattern = #"([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let latRange = Range(match.range(at: 1), in: s),
              let lonRange = Range(match.range(at: 2), in: s),
              let lat = Double(s[latRange]), let lon = Double(s[lonRange]) else {
            return (nil, nil)
        }
        return (lat, lon)
    }

    private static func fileDate(_ url: URL) -> Date? {
        // File copies keep their modification time but get a fresh creation
        // (birth) time, so mtime is the more reliable stand-in for the
        // original photo date when no EXIF/QuickTime date is embedded.
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return (attrs[.modificationDate] as? Date) ?? (attrs[.creationDate] as? Date)
    }
}
