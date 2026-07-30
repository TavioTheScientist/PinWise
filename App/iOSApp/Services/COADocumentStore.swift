import UIKit
import UniformTypeIdentifiers

/// On-disk store for COA documents — images and PDFs.
///
/// Mirrors `PhysiquePhotoStore` exactly, including its central rule: **only a filename goes in
/// SwiftData; the bytes live on disk and are never a blob in the store or synced.**
///
/// Two deliberate deviations from the physique numbers, stated here so nobody "unifies" the
/// constants later: `maxEdge` is 2400 (not 1280) and JPEG quality is 0.9 (not 0.85). A progress photo
/// is a photo; a COA is **evidence with small print** — a purity table at 1280px is unreadable, which
/// would defeat the entire point of attaching it.
enum COADocumentStore {
    /// Long edge cap for captured/imported images. Large enough to keep a purity table legible.
    private static let maxEdge: CGFloat = 2400
    private static let jpegQuality: CGFloat = 0.9

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("COADocuments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(named name: String) -> URL { directory.appendingPathComponent(name) }

    /// Persists a captured or picked image as JPEG. Returns the filename, or nil on failure.
    static func save(_ image: UIImage) -> String? {
        let scaled = downscale(image, maxEdge: maxEdge)
        guard let data = scaled.jpegData(compressionQuality: jpegQuality) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(named: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// Copies a user-picked file (typically an emailed COA PDF) into our own directory.
    ///
    /// The picked URL is **not durable** — it is a security-scoped handle that stops resolving once
    /// the picker's scope ends, so the bytes must be copied immediately rather than referenced. The
    /// `startAccessingSecurityScopedResource` pairing is mandatory, not defensive.
    static func save(fileAt source: URL) -> (filename: String, kind: COADocumentKind)? {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let ext = source.pathExtension.isEmpty ? "pdf" : source.pathExtension.lowercased()
        let isPDF = (UTType(filenameExtension: ext)?.conforms(to: .pdf) ?? (ext == "pdf"))

        // An image arriving via the file picker still goes through `save(_ image:)` so it gets the
        // same downscale/quality treatment as a camera capture — otherwise a 12 MP screenshot of a
        // COA would be stored at full size while a photographed one wouldn't.
        if !isPDF, let data = try? Data(contentsOf: source), let image = UIImage(data: data) {
            return save(image).map { ($0, .image) }
        }

        let name = "\(UUID().uuidString).\(ext)"
        do {
            let data = try Data(contentsOf: source)
            try data.write(to: url(named: name), options: .atomic)
            return (name, isPDF ? .pdf : .image)
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(named: name)) else { return nil }
        return UIImage(data: data)
    }

    static func delete(named name: String) {
        guard !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(named: name))
    }

    static func exists(named name: String) -> Bool {
        !name.isEmpty && FileManager.default.fileExists(atPath: url(named: name).path)
    }

    private static func downscale(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
