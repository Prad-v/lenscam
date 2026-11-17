import AppIntents
import LenscamCore
#if canImport(VisualIntelligence)
import VisualIntelligence
#endif

struct CaptureEntity: AppEntity, Identifiable, Sendable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Capture")
    static var defaultQuery = CaptureEntityQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static let handoffID = "visual-intelligence-read"

    static func visualHandoff(labels: String) -> CaptureEntity {
        CaptureEntity(
            id: handoffID,
            title: labels.isEmpty ? "Read this in Lenscam" : "Read in Lenscam: \(labels)"
        )
    }
}

struct CaptureEntityQuery: EntityQuery {
    func entities(for identifiers: [CaptureEntity.ID]) async throws -> [CaptureEntity] {
        let sidecars = await MainActor.run { CaptureStore.shared.load() }
        return sidecars
            .filter { identifiers.contains($0.id.uuidString) }
            .map { CaptureEntity(id: $0.id.uuidString, title: "\($0.profile.title) \($0.createdAt.formatted(date: .abbreviated, time: .shortened))") }
    }
}

#if canImport(VisualIntelligence)
extension CaptureEntityQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [CaptureEntity] {
        let labels = input.labels.joined(separator: ", ")
        await MainActor.run {
            CaptureRouter.shared.visualLabels = labels
            CaptureRouter.shared.requestedProfile = .read
        }
        return [CaptureEntity.visualHandoff(labels: labels)]
    }
}
#endif

struct OpenCaptureIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Capture"

    @Parameter(title: "Capture")
    var target: CaptureEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if target.id == CaptureEntity.handoffID {
            CaptureRouter.shared.requestedProfile = .read
        } else if let id = UUID(uuidString: target.id) {
            CaptureRouter.shared.pendingCaptureID = id
        }
        return .result()
    }
}

struct StartEvidenceIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Evidence Shoot"
    static var description = IntentDescription("Opens Lenscam in Evidence. The master is hashed, and no brief is written.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            CaptureRouter.shared.requestedProfile = .evidence
        }
        return .result()
    }
}

struct StartReadIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Text with Lenscam"
    static var description = IntentDescription("Opens Lenscam in Read so text can be extracted and translated on device.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            CaptureRouter.shared.requestedProfile = .read
        }
        return .result()
    }
}

struct LenscamShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEvidenceIntent(),
            phrases: [
                "Start an evidence shoot in \(.applicationName)",
                "Open evidence in \(.applicationName)",
            ],
            shortTitle: "Evidence shoot",
            systemImageName: "checkmark.shield"
        )
        AppShortcut(
            intent: StartReadIntent(),
            phrases: [
                "Read text with \(.applicationName)",
                "Translate a photo in \(.applicationName)",
            ],
            shortTitle: "Read text",
            systemImageName: "text.viewfinder"
        )
    }
}
