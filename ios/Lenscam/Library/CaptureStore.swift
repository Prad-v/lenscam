import Foundation
import LenscamCore

enum StoreError: LocalizedError {
    case emptyCapture
    case masterChanged
    case missing

    var errorDescription: String? {
        switch self {
        case .emptyCapture:
            "The capture did not contain image data."
        case .masterChanged:
            "Lenscam refused to rewrite a master that was already hashed."
        case .missing:
            "That capture is no longer on this iPhone."
        }
    }
}

@MainActor
final class CaptureStore {
    static let shared = CaptureStore()

    private let root: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = base.appendingPathComponent("Lenscam/Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func load() -> [CaptureSidecar] {
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return folders.compactMap { folder in
            let url = folder.appendingPathComponent("sidecar.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? SidecarCodec.decode(data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func sidecar(id: UUID) -> CaptureSidecar? {
        load().first { $0.id == id }
    }

    func createStill(
        profile: CaptureProfile,
        genre: CaptureGenre? = nil,
        zoom: ZoomReading,
        still: StillCapture,
        location: GeoMark?,
        note: String
    ) throws -> CaptureSidecar {
        let id = UUID()
        let folder = try makeFolder(id)
        var derivatives: [DerivativeNote] = []
        let masterData: Data
        let filename: String
        let codec: String
        if let raw = still.raw {
            masterData = raw
            filename = "master.dng"
            codec = "dng"
            if let processed = still.processed {
                let previewName = "preview.heic"
                try processed.write(to: folder.appendingPathComponent(previewName), options: .atomic)
                derivatives.append(
                    DerivativeNote(
                        kind: .preview,
                        filename: previewName,
                        note: "Display preview from the camera. The hashed master is the raw file."
                    )
                )
            }
        } else if let processed = still.processed {
            masterData = processed
            filename = "master.heic"
            codec = "heic"
        } else {
            throw StoreError.emptyCapture
        }

        let masterURL = folder.appendingPathComponent(filename)
        try masterData.write(to: masterURL, options: .atomic)
        let sidecar = CaptureSidecar(
            id: id,
            profile: profile,
            genre: genre,
            createdAt: Date(),
            masterFilename: filename,
            masterSHA256: try MasterHash.sha256Hex(ofFile: masterURL),
            codec: codec,
            zoom: zoom,
            evidenceLocked: profile.recipe.evidenceLocked,
            location: location,
            derivatives: derivatives,
            note: note
        )
        try writeNew(sidecar)
        return sidecar
    }

    func createMovie(from temporary: URL, zoom: ZoomReading, genre: CaptureGenre? = nil) throws -> CaptureSidecar {
        let id = UUID()
        let folder = try makeFolder(id)
        let destination = folder.appendingPathComponent("interview.mov")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: temporary, to: destination)
        try? FileManager.default.removeItem(at: temporary)
        let sidecar = CaptureSidecar(
            id: id,
            profile: .interview,
            genre: genre,
            createdAt: Date(),
            masterFilename: "interview.mov",
            masterSHA256: try MasterHash.sha256Hex(ofFile: destination),
            codec: "mov",
            zoom: zoom,
            evidenceLocked: false
        )
        try writeNew(sidecar)
        return sidecar
    }

    func save(_ sidecar: CaptureSidecar) throws {
        let existing = try require(sidecar.id)
        guard existing.masterSHA256 == sidecar.masterSHA256, existing.masterFilename == sidecar.masterFilename else {
            throw StoreError.masterChanged
        }
        let data = try SidecarCodec.encode(sidecar)
        try data.write(to: file(sidecar, "sidecar.json"), options: .atomic)
    }

    func addDerivative(
        kind: DerivativeKind,
        filename: String,
        data: Data,
        note: String,
        to sidecar: inout CaptureSidecar
    ) throws {
        try data.write(to: file(sidecar, filename), options: .atomic)
        sidecar.derivatives.removeAll { $0.filename == filename }
        sidecar.derivatives.append(DerivativeNote(kind: kind, filename: filename, note: note))
        try save(sidecar)
    }

    func writeSRT(_ sidecar: CaptureSidecar) throws {
        let text = SRTWriter.render(sidecar.transcript)
        guard let data = text.data(using: .utf8) else { return }
        try data.write(to: file(sidecar, "captions.srt"), options: .atomic)
    }

    func file(_ sidecar: CaptureSidecar, _ filename: String) -> URL {
        root.appendingPathComponent(sidecar.id.uuidString).appendingPathComponent(filename)
    }

    func makeTemporaryMovieURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
    }

    private func makeFolder(_ id: UUID) throws -> URL {
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func writeNew(_ sidecar: CaptureSidecar) throws {
        let data = try SidecarCodec.encode(sidecar)
        try data.write(to: file(sidecar, "sidecar.json"), options: .atomic)
    }

    private func require(_ id: UUID) throws -> CaptureSidecar {
        guard let sidecar = sidecar(id: id) else { throw StoreError.missing }
        return sidecar
    }
}
