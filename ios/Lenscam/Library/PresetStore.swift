import Foundation
import LenscamCore

enum PresetStore {
    private static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Lenscam", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("presets.json")
    }

    static func load() -> [ShootingPreset] {
        guard let data = try? Data(contentsOf: file),
              let presets = try? JSONDecoder().decode([ShootingPreset].self, from: data) else { return [] }
        return presets.filter { !$0.builtIn }
    }

    static func save(_ presets: [ShootingPreset]) {
        let saved = presets.filter { !$0.builtIn }
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
