import LenscamCore
import SwiftUI

struct LibraryScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.captures.isEmpty {
                ContentUnavailableView(
                    "No captures yet",
                    systemImage: "camera",
                    description: Text("A master and its sidecar appear here after you shoot or import a still.")
                )
            } else {
                List(model.captures) { sidecar in
                    NavigationLink(value: Route.capture(sidecar.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sidecar.genre?.title ?? sidecar.profile.title)
                                    .font(.headline)
                                if sidecar.evidenceLocked {
                                    Text("Locked")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.accent, in: Capsule())
                                        .foregroundStyle(.black)
                                }
                            }
                            Text(sidecar.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            Text("\(sidecar.zoom.band.title) · \(sidecar.masterSHA256.prefix(12))")
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Translate into", selection: Binding(
                        get: { model.targetLanguageID },
                        set: { model.setTargetLanguage($0) }
                    )) {
                        ForEach(LanguageChoices.all) { choice in
                            Text(choice.name).tag(choice.id)
                        }
                    }
                } label: {
                    Image(systemName: "character.bubble")
                }
                .accessibilityLabel("Translation language")
            }
        }
    }
}
