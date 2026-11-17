import Foundation
import LenscamCore

@MainActor
@Observable
final class CaptureRouter {
    static let shared = CaptureRouter()

    var requestedProfile: CaptureProfile?
    var pendingCaptureID: UUID?
    var visualLabels: String = ""
}
