import AVFoundation
import Foundation
import LenscamCore
import Speech

enum SpeechFailure: LocalizedError {
    case exportFailed

    var errorDescription: String? {
        "Lenscam could not read the interview audio. The video master is still saved."
    }
}

enum SpeechTranscript {
    static func transcribe(movieAt url: URL, locale: Locale) async throws -> [TranscriptSegment] {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try await extractAudio(from: url, to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) ?? locale
        let transcriber = SpeechTranscriber(locale: resolved, preset: .timeIndexedProgressiveTranscription)
        let status = await AssetInventory.status(forModules: [transcriber])
        if status != .installed, let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let audioFile = try AVAudioFile(forReading: audioURL)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let box = TextBox()
        let collector = Task {
            do {
                for try await result in transcriber.results {
                    box.set(result.text)
                }
            } catch is CancellationError {
                return
            } catch {
                box.setError(error)
            }
        }

        do {
            _ = try await analyzer.analyzeSequence(from: audioFile)
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            collector.cancel()
            throw error
        }
        collector.cancel()
        if let error = box.error {
            throw error
        }
        guard let text = box.text else { return [] }
        return segments(from: text)
    }

    private static func extractAudio(from movie: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: movie)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SpeechFailure.exportFailed
        }
        try await exporter.export(to: destination, as: .m4a)
    }

    private static func segments(from text: AttributedString) -> [TranscriptSegment] {
        var output: [TranscriptSegment] = []
        for run in text.runs {
            guard let range = run.audioTimeRange else { continue }
            let piece = String(text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { continue }
            let start = range.start.seconds
            let end = range.end.seconds
            guard start.isFinite, end.isFinite else { continue }
            output.append(TranscriptSegment(start: start, end: max(end, start), text: piece))
        }
        if output.isEmpty {
            let plain = String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                output.append(TranscriptSegment(start: 0, end: 0, text: plain))
            }
        }
        return output
    }
}

private final class TextBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AttributedString?
    private var storedError: Error?

    func set(_ text: AttributedString) {
        lock.lock()
        stored = text
        lock.unlock()
    }

    func setError(_ error: Error) {
        lock.lock()
        storedError = error
        lock.unlock()
    }

    var text: AttributedString? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }
}
