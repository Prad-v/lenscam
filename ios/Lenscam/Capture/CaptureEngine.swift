import AVFoundation
import Foundation
import LenscamCore
import UIKit

struct CameraSnapshot: Sendable, Equatable {
    var cameraAvailable = false
    var audioAllowed = false
    var isRunning = false
    var isRecording = false
    var zoomFactor = 1.0
    var minZoom = 1.0
    var maxZoom = 1.0
    var opticalStops: [Double] = [1]
    var highResolutionCrop = false
    var iso = 0.0
    var shutterSeconds = 0.0
    var exposureBias = 0.0
    var minExposureBias = -2.0
    var maxExposureBias = 2.0
    var minShutter = 1.0 / 8000
    var maxShutter = 1.0 / 3
    var horizonDegrees: Double?
    var suggestion: SettingAdjustment?
    var usingFrontCamera = false
    var canSwitchCamera = false
    var flash = FlashChoice.off
    var flashAvailable = false
    var portraitDepthAvailable = false
    var nightChoice = NightChoice.auto
    var nightManualSeconds = 1.0
    var nightEngaged = false
    var nightSeconds = 0.0
    var nightLabel = "Off"
    var lowLightBoost = false
    var exposureManual = false
    var focusLocked = false
    var whiteBalanceManual = false
    var temperature = 5600.0
    var lensPosition = 0.6
    var minISO = 0.0
    var maxISO = 0.0
    var rawChoice = RawChoice.auto
    var rawSupported = false
    var sceneGenre: CaptureGenre?
    var histogram: [Double] = []
    var message: String?
}

enum FlashChoice: String, Sendable, Equatable {
    case off
    case auto
    case on

    var deviceMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
    }

    var symbol: String {
        switch self {
        case .off: "bolt.slash"
        case .auto: "bolt.badge.automatic"
        case .on: "bolt.fill"
        }
    }

    var title: String {
        switch self {
        case .off: "Flash off"
        case .auto: "Flash auto"
        case .on: "Flash on"
        }
    }
}

struct StillCapture: Sendable {
    var raw: Data?
    var processed: Data?
    var portrait: Data?
    var look: Data?
}

enum CaptureFailure: LocalizedError {
    case cameraUnavailable
    case noImage
    case notRecording
    case busy

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "The camera is not available. Import a still to read, translate, or file evidence."
        case .noImage:
            "The camera did not return an image."
        case .notRecording:
            "There is no interview in progress."
        case .busy:
            "A capture is already in progress."
        }
    }
}

@MainActor
@Observable
final class CaptureEngine {
    private(set) var snapshot = CameraSnapshot()
    var portraitPreview: UIImage?
    var assistOverlay: UIImage?
    var onPalm: (() -> Void)?
    let previewSession: AVCaptureSession
    private let driver: SessionDriver

    init() {
        let driver = SessionDriver()
        self.driver = driver
        previewSession = driver.session
        driver.snapshotHandler = { [weak self] snapshot in
            Task { @MainActor in
                self?.snapshot = snapshot
            }
        }
        driver.portraitHandler = { [weak self] image in
            Task { @MainActor in
                self?.portraitPreview = image
            }
        }
        driver.assistHandler = { [weak self] image in
            Task { @MainActor in
                self?.assistOverlay = image
            }
        }
        driver.palmHandler = { [weak self] in
            Task { @MainActor in
                self?.onPalm?()
            }
        }
    }

    func start() {
        Task {
            let video = await AVCaptureDevice.requestAccess(for: .video)
            let audio = await AVCaptureDevice.requestAccess(for: .audio)
            driver.start(videoAllowed: video, audioAllowed: audio)
        }
    }

    func apply(profile: CaptureProfile) {
        driver.apply(recordsAudio: profile.recipe.recordsAudio)
    }

    func setZoom(_ factor: Double) {
        driver.setZoom(factor)
    }

    func switchCamera() {
        driver.switchCamera()
    }

    func cycleFlash() {
        driver.cycleFlash()
    }

    func focus(at devicePoint: CGPoint) {
        driver.focus(at: devicePoint)
    }

    func setExposureBias(_ bias: Double) {
        driver.setExposureBias(bias)
    }

    func setNight(_ choice: NightChoice) {
        driver.setNight(choice)
    }

    func setNightDuration(_ seconds: Double) {
        driver.setNightDuration(seconds)
    }

    func setManual(_ setup: ManualSetup) {
        driver.setManual(setup)
    }

    func setRaw(_ choice: RawChoice) {
        driver.setRaw(choice)
    }

    func setAssists(histogram: Bool, zebra: Bool, peaking: Bool, scene: Bool) {
        driver.setAssists(histogram: histogram, zebra: zebra, peaking: peaking, scene: scene)
    }

    func applyAssistant(_ settings: AssistantSettings) {
        driver.applyAssistant(settings)
    }

    func setCaptureRotation(_ angle: CGFloat) {
        driver.setCaptureRotation(angle)
    }

    func setPortrait(light: PortraitLight, aperture: Double) {
        driver.setPortrait(light: light, aperture: aperture)
    }

    func setGrade(_ grade: PhotoGrade) {
        driver.setGrade(grade)
    }

    func applyGenre(_ genre: CaptureGenre) {
        driver.applyGenre(genre)
    }

    func setSuggestionsEnabled(_ enabled: Bool) {
        driver.setSuggestionsEnabled(enabled)
    }

    func suppressSuggestion(_ id: String) {
        driver.suppressSuggestion(id)
    }

    func apply(_ adjustment: SettingAdjustment) {
        driver.apply(adjustment)
    }

    func capture(prefersRaw: Bool) async throws -> StillCapture {
        guard snapshot.cameraAvailable else { throw CaptureFailure.cameraUnavailable }
        return try await driver.capture(prefersRaw: prefersRaw)
    }

    func startRecording(to url: URL, cinematic: Bool = false) throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
        try audio.setActive(true)
        driver.startRecording(to: url, cinematic: cinematic)
    }

    func stopRecording() async throws -> URL {
        try await driver.stopRecording()
    }
}

private final class SessionDriver: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var snapshotHandler: (@Sendable (CameraSnapshot) -> Void)?
    var portraitHandler: ((UIImage?) -> Void)?
    var assistHandler: ((UIImage?) -> Void)?
    var palmHandler: (@Sendable () -> Void)?

    private let sessionQueue = DispatchQueue(label: "lenscam.capture.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let visionQueue = DispatchQueue(label: "lenscam.capture.vision")
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var flashMode = FlashChoice.off
    private var captureRotation: CGFloat = 90
    private var depthOutputAdded = false
    private var portraitDepthEnabled = false
    private var latestDisparity: CVPixelBuffer?
    private var portraitLight = PortraitLight.natural
    private var portraitAperture = 4.5
    private var photoGrade = PhotoGrade()
    private var lastPortraitRender = Date.distantPast
    private var renderingLiveFrame = false
    private var probing = false
    private var depthFrame = 0
    private var audioInput: AVCaptureDeviceInput?
    private var snapshot = CameraSnapshot()
    private var wantsAudio = false
    private var cinematicRate = false
    private var configured = false
    private var genre: CaptureGenre = .photography
    private var nightChoice: NightChoice = .auto
    private var nightManualSeconds = 1.0
    private var manual = ManualSetup.automatic
    private var rawChoice = RawChoice.auto
    private var histogramEnabled = false
    private var zebraEnabled = false
    private var peakingEnabled = false
    private var sceneAssist = true
    private var assistBusy = false
    private var lastAssist = Date.distantPast
    private var lensMode = LensSwitching.automatic
    private var focusTuning = FocusTuning.standard
    private var palmEnabled = false
    private var palmStreak = 0
    private var lastPalm: Date?
    private var palmBusy = false
    private var sceneBrightness: Double?
    private var appliedNight = NightPlan(longExposure: false, seconds: 0, boost: false)
    private var pendingBias: Double?
    private var biasWriteQueued = false
    private var suggestionsEnabled = true
    private var frameIndex = 0
    private var lastSuggestionID: String?
    private let photoLock = NSLock()
    private var photoWait: PhotoWait?
    private let movieLock = NSLock()
    private var movieContinuation: CheckedContinuation<URL, Error>?

    func start(videoAllowed: Bool, audioAllowed: Bool) {
        sessionQueue.async {
            self.snapshot.audioAllowed = audioAllowed
            guard videoAllowed else {
                self.snapshot.cameraAvailable = false
                self.snapshot.message = "Camera access is off. You can still import a still."
                self.publish()
                return
            }
            self.configureIfNeeded()
        }
    }

    func apply(recordsAudio: Bool) {
        sessionQueue.async {
            guard self.configured else {
                self.wantsAudio = recordsAudio
                return
            }
            guard recordsAudio != self.wantsAudio else { return }
            self.wantsAudio = recordsAudio
            self.session.beginConfiguration()
            self.session.sessionPreset = recordsAudio ? .high : .photo
            self.installAudio(recordsAudio)
            self.session.commitConfiguration()
            self.refreshOptics()
            self.publish()
        }
    }

    func applyGenre(_ genre: CaptureGenre) {
        sessionQueue.async {
            self.genre = genre
            self.suggestionsEnabled = true
            self.snapshot.suggestion = nil
            self.lastSuggestionID = nil
            guard self.configured else { return }
            self.updatePortraitConfiguration()
            self.applyBaseline(genre)
            self.refreshOptics()
            if genre != .portrait {
                self.portraitHandler?(nil)
            }
            self.publish()
        }
    }

    func suppressSuggestion(_ id: String) {
        sessionQueue.async {
            self.lastSuggestionID = id
            self.snapshot.suggestion = nil
            self.publish()
        }
    }

    func setSuggestionsEnabled(_ enabled: Bool) {
        sessionQueue.async {
            self.suggestionsEnabled = enabled
            if !enabled {
                self.snapshot.suggestion = nil
                self.lastSuggestionID = nil
                self.publish()
            }
        }
    }

    func apply(_ adjustment: SettingAdjustment) {
        sessionQueue.async {
            self.applyAdjustment(adjustment)
            self.refreshOptics()
            self.snapshot.suggestion = nil
            self.lastSuggestionID = adjustment.id
            self.publish()
        }
    }

    func switchCamera() {
        sessionQueue.async {
            guard self.configured, !self.movieOutput.isRecording else { return }
            let next: AVCaptureDevice.Position = self.position == .back ? .front : .back
            guard let device = Self.camera(position: next),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            if let current = self.videoInput {
                self.session.removeInput(current)
            }
            guard self.session.canAddInput(input) else {
                if let current = self.videoInput, self.session.canAddInput(current) {
                    self.session.addInput(current)
                }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.videoInput = input
            self.videoDevice = device
            self.position = next
            self.configurePhotoOutput(for: device)
            self.alignConnections(front: next == .front)
            self.session.commitConfiguration()
            self.snapshot.suggestion = nil
            self.lastSuggestionID = nil
            self.refreshOptics()
            self.refreshCameraControls()
            self.updatePortraitConfiguration()
            self.applyBaseline(self.genre)
            self.publish()
        }
    }

    func cycleFlash() {
        sessionQueue.async {
            let supported = self.photoOutput.supportedFlashModes
            let order: [FlashChoice] = [.off, .auto, .on]
            let usable = order.filter { supported.contains($0.deviceMode) }
            guard usable.count > 1 else { return }
            let index = usable.firstIndex(of: self.flashMode) ?? 0
            self.flashMode = usable[(index + 1) % usable.count]
            self.snapshot.flash = self.flashMode
            self.syncTorch(recording: self.movieOutput.isRecording)
            self.publish()
        }
    }

    func setPortrait(light: PortraitLight, aperture: Double) {
        portraitLight = light
        portraitAperture = min(16, max(1.4, aperture))
    }

    func setGrade(_ grade: PhotoGrade) {
        photoGrade = grade
        if grade.isNeutral, genre != .portrait {
            portraitHandler?(nil)
        }
    }

    func setCaptureRotation(_ angle: CGFloat) {
        sessionQueue.async {
            guard abs(self.captureRotation - angle) > 0.5 else { return }
            self.captureRotation = angle
            self.applyCaptureRotation()
        }
    }

    func focus(at devicePoint: CGPoint) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            let point = CGPoint(
                x: min(1, max(0, devicePoint.x)),
                y: min(1, max(0, devicePoint.y))
            )
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if !self.manual.focusLocked {
                    if device.isFocusPointOfInterestSupported {
                        device.focusPointOfInterest = point
                    }
                    if let tuned = self.focusTuning.lensPosition, device.isLockingFocusWithCustomLensPositionSupported {
                        device.setFocusModeLocked(lensPosition: Float(tuned), completionHandler: nil)
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if !self.manual.exposureManual, device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
            } catch {
                self.snapshot.message = error.localizedDescription
            }
            self.publish()
        }
    }

    func setExposureBias(_ bias: Double) {
        sessionQueue.async {
            self.pendingBias = bias
            guard !self.biasWriteQueued else { return }
            self.biasWriteQueued = true
            self.sessionQueue.asyncAfter(deadline: .now() + 0.05) {
                self.biasWriteQueued = false
                self.writePendingBias()
            }
        }
    }

    func setNight(_ choice: NightChoice) {
        sessionQueue.async {
            self.nightChoice = choice
            self.applyNightPolicy(force: true)
            self.publish()
        }
    }

    func setNightDuration(_ seconds: Double) {
        sessionQueue.async {
            self.nightChoice = .manual
            self.nightManualSeconds = min(NightMode.maximumSeconds, max(NightMode.minimumSeconds, seconds))
            self.applyNightPolicy(force: true)
            self.publish()
        }
    }

    func setManual(_ setup: ManualSetup) {
        sessionQueue.async {
            self.manual = setup
            self.snapshot.exposureManual = setup.exposureManual
            self.snapshot.focusLocked = setup.focusLocked
            self.snapshot.whiteBalanceManual = setup.whiteBalanceManual
            self.snapshot.temperature = setup.temperature
            self.snapshot.lensPosition = setup.lensPosition
            if !setup.exposureManual {
                self.restoreAutoExposure()
            }
            if !setup.focusLocked {
                self.restoreAutoFocus()
            }
            if !setup.whiteBalanceManual {
                self.restoreAutoWhiteBalance()
            }
            self.applyManualLocks()
            self.refreshOptics()
            self.publish()
        }
    }

    func setRaw(_ choice: RawChoice) {
        sessionQueue.async {
            self.rawChoice = choice
            self.snapshot.rawChoice = choice
            self.publish()
        }
    }

    func setAssists(histogram: Bool, zebra: Bool, peaking: Bool, scene: Bool) {
        sessionQueue.async {
            self.histogramEnabled = histogram
            self.zebraEnabled = zebra
            self.peakingEnabled = peaking
            self.sceneAssist = scene
            if !histogram {
                self.snapshot.histogram = []
            }
            if !scene {
                self.snapshot.sceneGenre = nil
            }
            if !zebra && !peaking {
                self.assistHandler?(nil)
            }
            self.publish()
        }
    }

    func applyAssistant(_ settings: AssistantSettings) {
        sessionQueue.async {
            let lensChanged = settings.lensSwitching != self.lensMode
            self.lensMode = settings.lensSwitching
            self.focusTuning = settings.focusTuning
            self.palmEnabled = settings.palmGesture
            if !settings.palmGesture {
                self.palmStreak = 0
            }
            guard self.configured else { return }
            if lensChanged {
                self.applyBaseline(self.genre)
            } else {
                self.applyFocusTuning()
            }
            self.refreshOptics()
            self.publish()
        }
    }

    func setZoom(_ factor: Double) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = max(minZoom, device.maxAvailableVideoZoomFactor)
            let snapped = LensSwitchPolicy.pinchResult(factor, stops: self.snapshot.opticalStops, mode: self.lensMode)
            let clamped = min(maxZoom, max(minZoom, CGFloat(snapped)))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                self.snapshot.zoomFactor = Double(device.videoZoomFactor)
                self.publish()
            } catch {
                self.snapshot.message = error.localizedDescription
                self.publish()
            }
        }
    }

    func capture(prefersRaw: Bool) async throws -> StillCapture {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.snapshot.cameraAvailable, self.configured else {
                    continuation.resume(throwing: CaptureFailure.cameraUnavailable)
                    return
                }
                self.photoLock.lock()
                if self.photoWait != nil {
                    self.photoLock.unlock()
                    continuation.resume(throwing: CaptureFailure.busy)
                    return
                }
                self.photoWait = PhotoWait(continuation)
                self.photoLock.unlock()

                self.applyCaptureRotation()
                let settings = self.makeSettings(prefersRaw: prefersRaw)
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func startRecording(to url: URL, cinematic: Bool) {
        sessionQueue.async {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = cinematic ? .cinematic : .auto
                }
            }
            self.applyCaptureRotation()
            self.setFrameRate(cinematic: cinematic)
            self.applyNightPolicy(force: true)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            self.syncTorch(recording: true)
            self.snapshot.isRecording = true
            self.publish()
        }
    }

    func stopRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.movieLock.lock()
            self.movieContinuation = continuation
            self.movieLock.unlock()
            self.sessionQueue.async {
                guard self.movieOutput.isRecording else {
                    self.finishMovie(throwing: CaptureFailure.notRecording)
                    return
                }
                self.movieOutput.stopRecording()
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = wantsAudio ? .high : .photo

        guard let device = Self.backCamera(),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            snapshot.cameraAvailable = false
            snapshot.message = "No camera is available on this device. Import a still to continue."
            publish()
            return
        }
        session.addInput(input)
        videoInput = input
        videoDevice = device
        position = .back

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.automaticallyConfiguresOutputBufferDimensions = false
        videoOutput.deliversPreviewSizedOutputBuffers = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        configurePhotoOutput(for: device)
        alignConnections(front: false)
        installAudio(wantsAudio)
        session.commitConfiguration()
        configured = true
        snapshot.cameraAvailable = true
        snapshot.message = nil
        refreshOptics()
        refreshCameraControls()
        applyBaseline(genre)
        publish()
        session.startRunning()
        snapshot.isRunning = session.isRunning
        publish()
    }

    private func installAudio(_ enabled: Bool) {
        if enabled {
            guard audioInput == nil,
                  let device = AVCaptureDevice.default(for: .audio),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            audioInput = input
        } else if let audioInput {
            session.removeInput(audioInput)
            self.audioInput = nil
        }
    }

    private func refreshOptics() {
        guard let device = videoDevice else { return }
        var stops = device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
        if !stops.contains(where: { abs($0 - 1) < 0.02 }) {
            stops.append(1)
        }
        snapshot.opticalStops = stops.sorted()
        snapshot.minZoom = Double(device.minAvailableVideoZoomFactor)
        snapshot.maxZoom = Double(max(device.minAvailableVideoZoomFactor, device.maxAvailableVideoZoomFactor))
        snapshot.zoomFactor = Double(device.videoZoomFactor)
        snapshot.highResolutionCrop = device.activeFormat.supportedMaxPhotoDimensions.contains {
            max(Int($0.width), Int($0.height)) >= 7000
        }
        snapshot.iso = Double(device.iso)
        snapshot.shutterSeconds = device.exposureDuration.seconds
        snapshot.exposureBias = Double(device.exposureTargetBias)
        snapshot.minExposureBias = Double(device.minExposureTargetBias)
        snapshot.maxExposureBias = Double(device.maxExposureTargetBias)
        snapshot.minShutter = device.activeFormat.minExposureDuration.seconds
        snapshot.maxShutter = device.activeFormat.maxExposureDuration.seconds
        snapshot.minISO = Double(device.activeFormat.minISO)
        snapshot.maxISO = Double(device.activeFormat.maxISO)
        snapshot.exposureManual = manual.exposureManual
        snapshot.focusLocked = manual.focusLocked
        snapshot.whiteBalanceManual = manual.whiteBalanceManual
        snapshot.rawChoice = rawChoice
    }

    private func applyBaseline(_ genre: CaptureGenre) {
        guard let device = videoDevice else { return }
        let stops = snapshot.opticalStops
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let preferred = LensSwitchPolicy.zoom(
                preferred: genre.preferredZoom(among: stops),
                current: Double(device.videoZoomFactor),
                stops: stops,
                mode: lensMode
            )
            if let preferred {
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = max(minZoom, device.maxAvailableVideoZoomFactor)
                device.videoZoomFactor = min(maxZoom, max(minZoom, CGFloat(preferred)))
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            let bias: Float = switch genre {
            case .landscape: -0.35
            case .portrait: 0.15
            case .food: 0.25
            default: 0
            }
            let clamped = min(device.maxExposureTargetBias, max(device.minExposureTargetBias, bias))
            device.setExposureTargetBias(clamped, completionHandler: nil)
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
        applyNightPolicy(force: true)
        applyManualLocks()
        applyFocusTuning()
    }

    private func applyFocusTuning() {
        guard !manual.focusLocked, let position = focusTuning.lensPosition, let device = videoDevice,
              device.isLockingFocusWithCustomLensPositionSupported else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.setFocusModeLocked(lensPosition: Float(position), completionHandler: nil)
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func writePendingBias() {
        guard let bias = pendingBias, let device = videoDevice, !manual.exposureManual else { return }
        pendingBias = nil
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let clamped = min(device.maxExposureTargetBias, max(device.minExposureTargetBias, Float(bias)))
            device.setExposureTargetBias(clamped, completionHandler: nil)
            snapshot.exposureBias = Double(clamped)
        } catch {
            snapshot.message = error.localizedDescription
        }
        publish()
    }

    /// Night mode, then the sport shutter cap, own `activeMaxExposureDuration`.
    @discardableResult
    private func applyNightPolicy(force: Bool) -> Bool {
        guard let device = videoDevice else { return false }
        let formatMax = device.activeFormat.maxExposureDuration.seconds
        let plan = NightMode.plan(
            choice: nightChoice,
            manualSeconds: nightManualSeconds,
            brightness: sceneBrightness,
            formatMaxSeconds: formatMax,
            currentlyEngaged: appliedNight.longExposure
        )
        let changed = force
            || plan != appliedNight
            || snapshot.nightChoice != nightChoice
            || abs(snapshot.nightManualSeconds - nightManualSeconds) > 0.02
        snapshot.nightChoice = nightChoice
        snapshot.nightManualSeconds = nightManualSeconds
        snapshot.nightEngaged = plan.longExposure
        snapshot.nightSeconds = plan.seconds
        snapshot.nightLabel = plan.label
        snapshot.lowLightBoost = plan.boost
        guard changed else { return false }
        appliedNight = plan
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = plan.boost
            }
            let formatMin = device.activeFormat.minExposureDuration.seconds
            let formatCeiling = device.activeFormat.maxExposureDuration.seconds
            var seconds = formatCeiling
            if plan.longExposure {
                seconds = plan.seconds
            } else if genre == .sport {
                seconds = 1.0 / 500.0
            }
            if cinematicRate {
                let frame = device.activeVideoMinFrameDuration.seconds
                if frame > 0 { seconds = min(seconds, frame) }
            }
            if seconds.isFinite, formatCeiling > 0 {
                seconds = min(formatCeiling, max(formatMin, seconds))
                if cinematicRate, plan.longExposure {
                    snapshot.nightSeconds = seconds
                    snapshot.nightLabel = NightMode.durationLabel(seconds)
                }
                device.activeMaxExposureDuration = CMTime(seconds: seconds, preferredTimescale: 1000)
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
        return true
    }

    private func restoreAutoExposure() {
        guard let device = videoDevice, device.isExposureModeSupported(.continuousAutoExposure) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.exposureMode = .continuousAutoExposure
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func restoreAutoFocus() {
        guard let device = videoDevice, device.isFocusModeSupported(.continuousAutoFocus) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.focusMode = .continuousAutoFocus
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func restoreAutoWhiteBalance() {
        guard let device = videoDevice, device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func applyManualLocks() {
        guard let device = videoDevice else { return }
        guard manual.exposureManual || manual.focusLocked || manual.whiteBalanceManual else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if manual.exposureManual {
                let iso = ManualExposure.clampISO(
                    manual.iso,
                    min: Double(device.activeFormat.minISO),
                    max: Double(device.activeFormat.maxISO)
                )
                let seconds = ManualExposure.clampShutter(
                    manual.shutterSeconds,
                    min: device.activeFormat.minExposureDuration.seconds,
                    max: device.activeFormat.maxExposureDuration.seconds
                )
                device.setExposureModeCustom(
                    duration: CMTime(seconds: seconds, preferredTimescale: 1000),
                    iso: Float(iso),
                    completionHandler: nil
                )
                snapshot.iso = iso
                snapshot.shutterSeconds = seconds
            }
            if manual.focusLocked, device.isLockingFocusWithCustomLensPositionSupported {
                let position = Float(FocusDial.clamp(manual.lensPosition))
                device.setFocusModeLocked(lensPosition: position, completionHandler: nil)
                snapshot.lensPosition = Double(position)
            }
            if manual.whiteBalanceManual {
                let kelvin = Float(WhiteBalanceDial.clamp(manual.temperature))
                let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: kelvin, tint: 0)
                var gains = device.deviceWhiteBalanceGains(for: values)
                let limit = device.maxWhiteBalanceGain
                func clampGain(_ value: Float) -> Float { min(limit, max(1, value)) }
                gains.redGain = clampGain(gains.redGain)
                gains.greenGain = clampGain(gains.greenGain)
                gains.blueGain = clampGain(gains.blueGain)
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                snapshot.temperature = Double(kelvin)
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func applyAdjustment(_ adjustment: SettingAdjustment) {
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            switch adjustment.action {
            case .exposureBias:
                if let value = adjustment.exposureBias {
                    let bias = Float(value)
                    let clamped = min(device.maxExposureTargetBias, max(device.minExposureTargetBias, bias))
                    device.setExposureTargetBias(clamped, completionHandler: nil)
                }
            case .zoom:
                if let factor = adjustment.zoomFactor {
                    let minZoom = device.minAvailableVideoZoomFactor
                    let maxZoom = max(minZoom, device.maxAvailableVideoZoomFactor)
                    device.videoZoomFactor = min(maxZoom, max(minZoom, CGFloat(factor)))
                }
            case .shutterCap:
                if let seconds = adjustment.shutterSeconds {
                    let cap = CMTime(seconds: seconds, preferredTimescale: 1000)
                    let formatMin = device.activeFormat.minExposureDuration
                    let formatMax = device.activeFormat.maxExposureDuration
                    if CMTimeCompare(cap, formatMin) >= 0, CMTimeCompare(cap, formatMax) <= 0 {
                        device.activeMaxExposureDuration = cap
                    }
                }
            case .focusPoint:
                if let x = adjustment.focusX, let y = adjustment.focusY {
                    let point = CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
                    if device.isFocusPointOfInterestSupported {
                        device.focusPointOfInterest = point
                    }
                    if device.isExposurePointOfInterestSupported {
                        device.exposurePointOfInterest = point
                    }
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameIndex += 1
        if palmEnabled, position == .front, frameIndex % 24 == 0, !palmBusy,
           let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            palmBusy = true
            let spread = PalmReader.spread(buffer)
            palmBusy = false
            let now = Date()
            palmStreak = PalmPolicy.advanced(open: PalmPolicy.isOpen(spread), streak: palmStreak)
            if PalmPolicy.ready(streak: palmStreak, lastFire: lastPalm, now: now) {
                lastPalm = now
                palmStreak = 0
                palmHandler?()
            }
        }
        if frameIndex % 8 == 0, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), genre == .portrait || !photoGrade.isNeutral {
            renderLiveFrame(buffer)
        }
        if frameIndex % 15 == 0, frameIndex % 45 != 0, zebraEnabled || peakingEnabled,
           let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            renderAssist(buffer)
        }
        guard frameIndex % 45 == 0, !probing else { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        probing = true
        let broad = sceneAssist && frameIndex % 90 == 0
        let reading = SceneProbe.read(buffer, genre: genre, broadScene: broad, histogram: histogramEnabled)
        probing = false
        sessionQueue.async {
            self.sceneBrightness = reading.brightness
            let nightChanged = self.applyNightPolicy(force: false)
            let assistChanged = self.noteAssist(reading, broad: broad)
            guard self.suggestionsEnabled else {
                if nightChanged || assistChanged { self.publish() }
                return
            }
            self.refreshOptics()
            let zoom = ZoomMeter.reading(
                zoomFactor: self.snapshot.zoomFactor,
                opticalStops: self.snapshot.opticalStops,
                highResolutionCrop: self.snapshot.highResolutionCrop,
                pastSharpCrop: self.genre.watchesSharpCrop
            )
            let scene = LiveScene(
                brightness: reading.brightness,
                faceDetected: reading.faceDetected,
                faceX: reading.faceX,
                faceY: reading.faceY,
                horizonDegrees: reading.horizonDegrees,
                animalDetected: reading.animalDetected,
                iso: self.snapshot.iso,
                shutterSeconds: self.snapshot.shutterSeconds,
                exposureBias: self.snapshot.exposureBias,
                minBias: self.snapshot.minExposureBias,
                maxBias: self.snapshot.maxExposureBias,
                minShutter: self.snapshot.minShutter,
                maxShutter: self.snapshot.maxShutter
            )
            let horizonChanged = self.snapshot.horizonDegrees != reading.horizonDegrees
            self.snapshot.horizonDegrees = reading.horizonDegrees
            let advice = SettingAdvisor.recommend(
                genre: self.genre,
                zoom: zoom,
                scene: scene,
                stops: self.snapshot.opticalStops,
                nightEngaged: self.snapshot.nightEngaged
            )
            if let advice {
                guard advice.id != self.lastSuggestionID else {
                    if horizonChanged || nightChanged || assistChanged { self.publish() }
                    return
                }
                guard self.snapshot.suggestion?.id != advice.id || horizonChanged || nightChanged || assistChanged else { return }
                self.snapshot.suggestion = advice
            } else if self.snapshot.suggestion != nil || horizonChanged {
                self.snapshot.suggestion = nil
                self.lastSuggestionID = nil
            } else if nightChanged || assistChanged {
                self.publish()
                return
            } else {
                return
            }
            self.publish()
        }
    }

    private func updatePortraitConfiguration() {
        session.beginConfiguration()
        if genre == .portrait {
            enablePortraitDepth()
        } else if portraitDepthEnabled {
            disablePortraitDepth()
        }
        session.commitConfiguration()
        alignConnections(front: position == .front)
    }

    private func enablePortraitDepth() {
        guard let device = videoDevice else {
            portraitDepthEnabled = false
            snapshot.portraitDepthAvailable = false
            return
        }
        session.sessionPreset = .inputPriority
        guard let pair = depthFormat(for: device) else {
            portraitDepthEnabled = false
            snapshot.portraitDepthAvailable = false
            snapshot.message = "This camera cannot make a depth portrait."
            return
        }
        do {
            try device.lockForConfiguration()
            device.activeFormat = pair.video
            device.activeDepthDataFormat = pair.depth
            device.unlockForConfiguration()
        } catch {
            portraitDepthEnabled = false
            snapshot.portraitDepthAvailable = false
            snapshot.message = error.localizedDescription
            return
        }
        if photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = true
        }
        if photoOutput.isPortraitEffectsMatteDeliverySupported {
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = true
        }
        let wanted: [AVSemanticSegmentationMatte.MatteType] = [.skin, .hair, .teeth, .glasses]
        let available = photoOutput.availableSemanticSegmentationMatteTypes
        let chosen = wanted.filter { available.contains($0) }
        if !chosen.isEmpty {
            photoOutput.enabledSemanticSegmentationMatteTypes = chosen
        }
        if !depthOutputAdded {
            depthOutput.isFilteringEnabled = true
            depthOutput.alwaysDiscardsLateDepthData = true
            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
                depthOutput.setDelegate(self, callbackQueue: visionQueue)
                depthOutputAdded = true
            }
        }
        portraitDepthEnabled = photoOutput.isDepthDataDeliveryEnabled
        snapshot.portraitDepthAvailable = portraitDepthEnabled
        if portraitDepthEnabled {
            snapshot.message = nil
        }
    }

    private func disablePortraitDepth() {
        photoOutput.isDepthDataDeliveryEnabled = false
        photoOutput.isPortraitEffectsMatteDeliveryEnabled = false
        photoOutput.enabledSemanticSegmentationMatteTypes = []
        if depthOutputAdded {
            session.removeOutput(depthOutput)
            depthOutputAdded = false
        }
        session.sessionPreset = wantsAudio ? .high : .photo
        portraitDepthEnabled = false
        snapshot.portraitDepthAvailable = false
        latestDisparity = nil
    }

    private func depthFormat(for device: AVCaptureDevice) -> (video: AVCaptureDevice.Format, depth: AVCaptureDevice.Format)? {
        let candidates = device.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
        guard let video = candidates.max(by: { lhs, rhs in
            let left = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let right = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return Int(left.width) * Int(left.height) < Int(right.width) * Int(right.height)
        }), let depth = video.supportedDepthDataFormats.last else { return nil }
        return (video, depth)
    }

    private func noteAssist(_ reading: SceneProbe.Reading, broad: Bool) -> Bool {
        var changed = false
        if histogramEnabled {
            if snapshot.histogram != reading.histogram {
                snapshot.histogram = reading.histogram
                changed = true
            }
        } else if !snapshot.histogram.isEmpty {
            snapshot.histogram = []
            changed = true
        }
        if !sceneAssist {
            if snapshot.sceneGenre != nil {
                snapshot.sceneGenre = nil
                changed = true
            }
        } else if broad {
            let offer = SceneGuide.suggestion(
                face: reading.faceMeasured ? reading.faceDetected : nil,
                animal: reading.animalMeasured ? reading.animalDetected : nil,
                horizon: reading.horizonMeasured ? reading.horizonDegrees : nil,
                current: genre
            )
            if snapshot.sceneGenre != offer {
                snapshot.sceneGenre = offer
                changed = true
            }
        }
        return changed
    }

    private func renderAssist(_ buffer: CVPixelBuffer) {
        let now = Date()
        guard !assistBusy, now.timeIntervalSince(lastAssist) > 0.4 else { return }
        assistBusy = true
        lastAssist = now
        let zebra = zebraEnabled
        let peaking = peakingEnabled
        let image = AssistOverlay.image(buffer: buffer, zebra: zebra, peaking: peaking)
        assistBusy = false
        assistHandler?(image)
    }

    private func renderLiveFrame(_ buffer: CVPixelBuffer) {
        let now = Date()
        guard !renderingLiveFrame, now.timeIntervalSince(lastPortraitRender) > 0.35 else { return }
        renderingLiveFrame = true
        lastPortraitRender = now
        defer { renderingLiveFrame = false }
        let image = CIImage(cvPixelBuffer: buffer)
        if genre == .portrait, let disparityBuffer = latestDisparity {
            let disparity = CIImage(cvPixelBuffer: disparityBuffer)
            guard let preview = PortraitStudio.preview(
                image: image,
                disparity: disparity,
                aperture: portraitAperture,
                light: portraitLight,
                grade: photoGrade
            ) else { return }
            portraitHandler?(preview)
            return
        }
        guard !photoGrade.isNeutral else { return }
        guard let preview = PhotoGradeRender.preview(image: image, grade: photoGrade) else { return }
        portraitHandler?(preview)
    }

    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        depthFrame += 1
        guard depthFrame % 3 == 0 else { return }
        let disparity = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        latestDisparity = disparity.depthDataMap
    }

    private func makeSettings(prefersRaw: Bool) -> AVCapturePhotoSettings {
        if prefersRaw, flashMode == .off,
           photoOutput.isAppleProRAWEnabled,
           let raw = photoOutput.availableRawPhotoPixelFormatTypes.last {
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? .hevc : .jpeg
            let settings = AVCapturePhotoSettings(
                rawPixelFormatType: raw,
                processedFormat: [AVVideoCodecKey: codec]
            )
            if photoOutput.maxPhotoDimensions.width > 0 {
                settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            }
            applyFlash(to: settings)
            applyNightQuality(to: settings)
            return settings
        }

        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        if photoOutput.maxPhotoDimensions.width > 0 {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }
        applyFlash(to: settings)
        applyPortraitDelivery(to: settings)
        applyNightQuality(to: settings)
        return settings
    }

    private func applyNightQuality(to settings: AVCapturePhotoSettings) {
        guard snapshot.nightEngaged else { return }
        settings.photoQualityPrioritization = .quality
    }

    private func applyPortraitDelivery(to settings: AVCapturePhotoSettings) {
        guard genre == .portrait else { return }
        if photoOutput.isDepthDataDeliveryEnabled {
            settings.isDepthDataDeliveryEnabled = true
        }
        if photoOutput.isPortraitEffectsMatteDeliveryEnabled {
            settings.isPortraitEffectsMatteDeliveryEnabled = true
        }
        let types = photoOutput.enabledSemanticSegmentationMatteTypes
        if !types.isEmpty {
            settings.enabledSemanticSegmentationMatteTypes = types
        }
    }

    private func applyFlash(to settings: AVCapturePhotoSettings) {
        let mode = flashMode.deviceMode
        guard photoOutput.supportedFlashModes.contains(mode) else { return }
        settings.flashMode = mode
    }

    private func publish() {
        snapshotHandler?(snapshot)
    }

    private func configurePhotoOutput(for device: AVCaptureDevice) {
        if photoOutput.isAppleProRAWSupported, position == .back {
            photoOutput.isAppleProRAWEnabled = true
        }
        if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { lhs, rhs in
            Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
        }) {
            photoOutput.maxPhotoDimensions = largest
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
    }

    private func alignConnections(front: Bool) {
        for output in [photoOutput as AVCaptureOutput, movieOutput, videoOutput] {
            guard let connection = output.connection(with: .video) else { continue }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = front
            }
        }
        applyCaptureRotation()
    }

    private func applyCaptureRotation() {
        for output in [photoOutput as AVCaptureOutput, movieOutput, videoOutput] {
            guard let connection = output.connection(with: .video),
                  connection.isVideoRotationAngleSupported(captureRotation) else { continue }
            connection.videoRotationAngle = captureRotation
        }
    }

    private func refreshCameraControls() {
        let supported = photoOutput.supportedFlashModes
        if !supported.contains(flashMode.deviceMode) {
            flashMode = .off
        }
        snapshot.flash = flashMode
        snapshot.flashAvailable = supported.contains(.on) || supported.contains(.auto)
        snapshot.usingFrontCamera = position == .front
        snapshot.canSwitchCamera = Self.camera(position: .front) != nil && Self.camera(position: .back) != nil
        snapshot.rawSupported = photoOutput.isAppleProRAWSupported && position == .back
        snapshot.rawChoice = rawChoice
    }

    private func syncTorch(recording: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if recording, flashMode == .on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private static func camera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            let types: [AVCaptureDevice.DeviceType] = [.builtInTrueDepthCamera, .builtInWideAngleCamera]
            return types.compactMap { AVCaptureDevice.default($0, for: .video, position: .front) }.first
        }
        return backCamera()
    }

    private static func backCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
        ]
        return types.compactMap { AVCaptureDevice.default($0, for: .video, position: .back) }.first
            ?? AVCaptureDevice.default(for: .video)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        photoLock.lock()
        defer { photoLock.unlock() }
        guard let wait = photoWait else { return }
        if photo.resolvedSettings.expectedPhotoCount > 0 {
            wait.expected = photo.resolvedSettings.expectedPhotoCount
        }
        wait.received += 1
        if let data = photo.fileDataRepresentation(), !data.isEmpty {
            if photo.isRawPhoto {
                wait.raw = data
            } else {
                wait.processed = data
                if self.genre == .portrait {
                    wait.portrait = PortraitStudio.jpeg(
                        from: photo,
                        light: self.portraitLight,
                        aperture: self.portraitAperture,
                        grade: self.photoGrade
                    )
                } else if !self.photoGrade.isNeutral {
                    wait.look = PhotoGradeRender.jpeg(from: data, grade: self.photoGrade)
                }
            }
        } else if let error {
            wait.failure = error
        }
        guard wait.received >= wait.expected else { return }
        photoWait = nil
        if wait.raw != nil || wait.processed != nil {
            wait.continuation.resume(returning: StillCapture(raw: wait.raw, processed: wait.processed, portrait: wait.portrait, look: wait.look))
        } else {
            wait.continuation.resume(throwing: wait.failure ?? CaptureFailure.noImage)
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        sessionQueue.async {
            self.snapshot.isRecording = false
            self.setFrameRate(cinematic: false)
            self.applyNightPolicy(force: true)
            self.syncTorch(recording: false)
            self.publish()
        }
        if let error, !FileManager.default.fileExists(atPath: outputFileURL.path) {
            finishMovie(throwing: error)
        } else {
            finishMovie(returning: outputFileURL)
        }
    }

    private func setFrameRate(cinematic: Bool) {
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if cinematic {
                let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
                    $0.minFrameRate <= 24 && $0.maxFrameRate >= 24
                }
                guard supported else { return }
                let frame = CMTime(value: 1, timescale: 24)
                device.activeVideoMinFrameDuration = frame
                device.activeVideoMaxFrameDuration = frame
                cinematicRate = true
            } else if cinematicRate {
                device.activeVideoMinFrameDuration = .invalid
                device.activeVideoMaxFrameDuration = .invalid
                cinematicRate = false
            }
        } catch {
            snapshot.message = error.localizedDescription
        }
    }

    private func finishMovie(returning url: URL) {
        movieLock.lock()
        let continuation = movieContinuation
        movieContinuation = nil
        movieLock.unlock()
        continuation?.resume(returning: url)
    }

    private func finishMovie(throwing error: Error) {
        movieLock.lock()
        let continuation = movieContinuation
        movieContinuation = nil
        movieLock.unlock()
        continuation?.resume(throwing: error)
    }
}

private final class PhotoWait {
    let continuation: CheckedContinuation<StillCapture, Error>
    var raw: Data?
    var processed: Data?
    var received = 0
    var expected = 1
    var failure: Error?
    var portrait: Data?
    var look: Data?

    init(_ continuation: CheckedContinuation<StillCapture, Error>) {
        self.continuation = continuation
    }
}
