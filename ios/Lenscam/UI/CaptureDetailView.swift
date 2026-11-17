import LenscamCore
import SwiftUI
import UIKit

struct CaptureDetailView: View {
    @Bindable var model: AppModel
    let id: UUID
    @State private var report: ReportFile?

    private var sidecar: CaptureSidecar? {
        model.captures.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let sidecar {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        preview(sidecar)
                        header(sidecar)
                        if sidecar.evidenceLocked {
                            Text(EvidencePolicy.masterStatement)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let reading = sidecar.reading {
                            section("Text", reading.sourceText.isEmpty ? "No text found." : reading.sourceText)
                            if !reading.barcodes.isEmpty {
                                section("Barcodes", reading.barcodes.joined(separator: "\n"))
                            }
                            if let translated = reading.translatedText, !translated.isEmpty {
                                section("Translation", translated)
                            }
                        }
                        if !sidecar.transcript.isEmpty {
                            section(
                                "Transcript",
                                sidecar.transcript.map { segment in
                                    [segment.text, segment.translation].compactMap { $0 }.joined(separator: "\n")
                                }.joined(separator: "\n\n")
                            )
                        }
                        if let brief = sidecar.brief {
                            section("Brief · \(brief.model)", ([brief.title, brief.summary] + brief.actions).joined(separator: "\n"))
                        }
                        if !sidecar.derivatives.isEmpty {
                            section(
                                "Copies",
                                sidecar.derivatives.map { "\($0.kind.rawValue): \($0.note)" }.joined(separator: "\n\n")
                            )
                        }
                        if !sidecar.note.isEmpty {
                            section("Note", sidecar.note)
                        }
                        actions(sidecar)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("Missing capture", systemImage: "questionmark", description: Text("This sidecar is no longer in the library."))
            }
        }
        .navigationTitle(sidecar?.genre?.title ?? sidecar?.profile.title ?? "Capture")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background)
        .sheet(item: $report) { file in
            ShareSheet(items: [file.url])
        }
    }

    @ViewBuilder
    private func preview(_ sidecar: CaptureSidecar) -> some View {
        let store = CaptureStore.shared
        let imageURL: URL = {
            if let edited = sidecar.derivatives.first(where: { $0.kind == .look || $0.kind == .portrait || $0.kind == .letterbox || $0.kind == .enhance }) {
                return store.file(sidecar, edited.filename)
            }
            if let preview = sidecar.derivatives.first(where: { $0.kind == .preview }) {
                return store.file(sidecar, preview.filename)
            }
            return store.file(sidecar, sidecar.masterFilename)
        }()
        if let image = UIImage(contentsOfFile: imageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if sidecar.codec == "mov" {
            Label("Video master", systemImage: "video")
                .font(.headline)
        }
    }

    private func header(_ sidecar: CaptureSidecar) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(sidecar.zoom.band.title) · \(sidecar.zoom.factorLabel)")
                .font(.subheadline.weight(.semibold))
            Text(sidecar.zoom.coach)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(sidecar.masterSHA256)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Button("Copy hash") {
                UIPasteboard.general.string = sidecar.masterSHA256
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(body)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func actions(_ sidecar: CaptureSidecar) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if sidecar.profile.recipe.translatesText || sidecar.reading != nil || !sidecar.transcript.isEmpty {
                Button("Translate") { model.beginTranslation(id: sidecar.id) }
            }
            if EvidencePolicy.allowsGenerativeEdits(sidecar.profile) {
                Button("Write brief from the text") {
                    Task { await model.rewriteBrief(id: sidecar.id) }
                }
            }
            Button("Save master to Photos") {
                Task { await model.saveMasterToPhotos(id: sidecar.id) }
            }
            ShareLink(item: CaptureStore.shared.file(sidecar, "sidecar.json")) {
                Text("Share sidecar")
            }
            ShareLink(item: CaptureStore.shared.file(sidecar, sidecar.masterFilename)) {
                Text("Share master")
            }
            if sidecar.evidenceLocked {
                Button("Share evidence report") {
                    let data = EvidenceReport.pdf(for: sidecar)
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sidecar.id.uuidString)-evidence.pdf")
                    try? data.write(to: url)
                    report = ReportFile(url: url)
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ReportFile: Identifiable {
    let id = UUID()
    let url: URL
}
