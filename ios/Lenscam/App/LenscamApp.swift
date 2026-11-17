import SwiftUI
import Translation

@main
struct LenscamApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear { model.prepare() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.consumeRouter() }
                }
                .translationTask(model.translationConfiguration) { session in
                    await model.performTranslation(session)
                }
        }
    }
}

private struct RootView: View {
    @Bindable var model: AppModel
    private let router = CaptureRouter.shared

    var body: some View {
        NavigationStack(path: $model.path) {
            CameraScreen(model: model)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .library:
                        LibraryScreen(model: model)
                    case .capture(let id):
                        CaptureDetailView(model: model, id: id)
                    }
                }
        }
        .task(id: router.requestedProfile?.rawValue) {
            model.consumeRouter()
        }
        .task(id: router.pendingCaptureID) {
            model.consumeRouter()
        }
    }
}
