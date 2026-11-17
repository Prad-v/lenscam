import AVFoundation
import Foundation
import LenscamCore
import Speech

@MainActor
final class VoiceShutter {
    var onCue: (() -> Void)?
    var onUnavailable: ((String) -> Void)?

    private let audio = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var running = false
    private var tapInstalled = false
    private var wantsRunning = false
    private var lastFire = Date.distantPast

    func setEnabled(_ enabled: Bool) {
        wantsRunning = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard !running else { return }
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard self.wantsRunning else { return }
                guard status == .authorized else {
                    self.onUnavailable?("Voice shutter needs speech recognition turned on for Lenscam.")
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        guard wantsRunning, !running else { return }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            onUnavailable?("Voice shutter is not available for this language.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            onUnavailable?("Voice shutter needs the on-device speech model.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let input = audio.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                onUnavailable?("Voice shutter could not open the microphone.")
                return
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            audio.prepare()
            try audio.start()
        } catch {
            stop()
            onUnavailable?("Voice shutter could not open the microphone.")
            return
        }
        running = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in
                self?.consider(text)
            }
        }
    }

    private func consider(_ text: String) {
        guard running, VoiceCue.matches(text) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= VoiceCue.cooldown else { return }
        lastFire = now
        stop()
        onCue?()
    }

    private func stop() {
        if audio.isRunning { audio.stop() }
        if tapInstalled {
            audio.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        running = false
    }
}
