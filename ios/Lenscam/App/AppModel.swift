import AVFoundation
import Foundation
import FoundationModels
import LenscamCore
import Translation

enum Route: Hashable {
    case library
    case capture(UUID)
}

@MainActor
@Observable
final class AppModel {
    var profile: CaptureProfile = .master
    var genre: CaptureGenre = .photography
    var tool: CaptureProfile?
    var scene = SceneReading()
    var captures: [CaptureSidecar] = []
    var path: [Route] = []
    var banner: String?
    var isBusy = false
    var isBursting = false
    var burstTaken = 0
    private var burstCancel = false
    var recordingStarted: Date?
    var targetLanguageID: String = UserDefaults.standard.string(forKey: "lenscam.targetLanguage") ?? "en"
    var translationConfiguration: TranslationSession.Configuration?
    var visualLabels: String = ""

    let engine = CaptureEngine()
    private let locator = LocationMark()
    private let store = CaptureStore.shared
    private var translationCaptureID: UUID?

    var targetLanguage: Locale.Language {
        LanguageChoices.language(for: targetLanguageID)
    }

    var intelligenceWarning: String? {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            return BriefWriter.availabilityMessage(availability)
        }
        return nil
    }

    var assistant = AssistantSettings.standard
    var importedLooks: [ImportedLook] = []
    var importedLookID: String?
    private var foodLookApplied = false
    private let voice = VoiceShutter()

    init() {
        captures = store.load()
        if let data = UserDefaults.standard.data(forKey: "lenscam.assistant") {
            assistant = AssistantSettings.decode(data)
        }
        if let data = UserDefaults.standard.data(forKey: "lenscam.importedLooks"),
           let looks = try? LookImport.decode(data) {
            importedLooks = looks
        }
    }

    func prepare() {
        voice.onCue = { [weak self] in
            Task { await self?.voiceShutter() }
        }
        voice.onUnavailable = { [weak self] message in
            self?.banner = message
        }
        engine.onPalm = { [weak self] in
            Task { await self?.palmShutter() }
        }
        engine.start()
        engine.apply(profile: profile)
        engine.applyGenre(genre)
        engine.setRaw(rawChoice)
        engine.setAssists(histogram: showHistogram, zebra: showZebra, peaking: showPeaking, scene: showScene)
        engine.applyAssistant(assistant)
        syncVoice()
        consumeRouter()
    }

    var activeProfile: CaptureProfile {
        tool ?? genre.pipeline
    }

    var suggestionPhrase: String?
    var portraitLight: PortraitLight = .natural
    var portraitAperture = 4.5
    var editTool: EditTool = .exposure
    var grade = PhotoGrade()
    var lookFilter: LookFilter = .none
    var filterIntensity = 1.0
    var enhanceCopy = UserDefaults.standard.bool(forKey: "lenscam.enhance")
    var showHistogram = UserDefaults.standard.bool(forKey: "lenscam.histogram")
    var showZebra = UserDefaults.standard.bool(forKey: "lenscam.zebra")
    var showPeaking = UserDefaults.standard.bool(forKey: "lenscam.peaking")
    var showScene = UserDefaults.standard.object(forKey: "lenscam.scene") as? Bool ?? true
    var manual = ManualSetup.automatic
    var rawChoice: RawChoice = RawChoice(rawValue: UserDefaults.standard.string(forKey: "lenscam.raw") ?? "") ?? .auto
    var userPresets: [ShootingPreset] = PresetStore.load()
    var activePresetID: UUID?
    var presetDraft = ""
    var dismissedScene: CaptureGenre?
    private var phraseTask: Task<Void, Never>?
    private var phrasedSuggestionID: String?

    var visibleSuggestion: SettingAdjustment? {
        guard tool == nil else { return nil }
        return engine.snapshot.suggestion
    }

    var coachLine: String? {
        guard tool == nil, visibleSuggestion == nil else { return nil }
        var live = scene
        if let horizon = engine.snapshot.horizonDegrees {
            live.horizonDegrees = horizon
        }
        return GenreCoach.line(
            genre: genre,
            zoom: currentZoom(),
            scene: live,
            stops: engine.snapshot.opticalStops
        )
    }

    func selectGenre(_ genre: CaptureGenre) {
        guard !engine.snapshot.isRecording else { return }
        tool = nil
        scene = SceneReading()
        suggestionPhrase = nil
        self.genre = genre
        applyPipeline(genre.pipeline)
        engine.applyGenre(genre)
        if genre == .portrait {
            engine.setPortrait(light: portraitLight, aperture: portraitAperture)
        } else {
            engine.portraitPreview = nil
        }
        if genre == .food {
            if grade.isNeutral, lookFilter == .none, importedLookID == nil {
                selectFilter(.warm)
                foodLookApplied = true
            }
        } else if foodLookApplied {
            foodLookApplied = false
            selectFilter(.none)
        }
    }

    func select(_ profile: CaptureProfile) {
        guard !engine.snapshot.isRecording else { return }
        tool = profile
        applyPipeline(profile)
        engine.setSuggestionsEnabled(false)
    }

    func setPortraitLight(_ light: PortraitLight) {
        portraitLight = light
        engine.setPortrait(light: light, aperture: portraitAperture)
    }

    func setPortraitAperture(_ aperture: Double) {
        portraitAperture = aperture
        engine.setPortrait(light: portraitLight, aperture: aperture)
    }

    var visibleScene: CaptureGenre? {
        guard tool == nil, visibleSuggestion == nil else { return nil }
        guard let scene = engine.snapshot.sceneGenre, scene != dismissedScene else { return nil }
        return scene
    }

    func setGrade(tool: EditTool, value: Double) {
        editTool = tool
        lookFilter = .none
        importedLookID = nil
        foodLookApplied = false
        activePresetID = nil
        grade = grade.setting(tool, to: value)
        engine.setGrade(grade)
    }

    func selectFilter(_ filter: LookFilter) {
        lookFilter = filter
        importedLookID = nil
        foodLookApplied = false
        activePresetID = nil
        grade = PhotoGrade(LookFilters.recipe(filter, intensity: filter == .none ? 0 : filterIntensity))
        engine.setGrade(grade)
    }

    func selectImported(_ look: ImportedLook) {
        importedLookID = look.id
        lookFilter = .none
        foodLookApplied = false
        activePresetID = nil
        grade = PhotoGrade(look.recipe(intensity: filterIntensity))
        engine.setGrade(grade)
    }

    func setFilterIntensity(_ value: Double) {
        filterIntensity = min(1, max(0, value))
        if let id = importedLookID, let look = importedLooks.first(where: { $0.id == id }) {
            grade = PhotoGrade(look.recipe(intensity: filterIntensity))
            engine.setGrade(grade)
            return
        }
        guard lookFilter != .none else { return }
        grade = PhotoGrade(LookFilters.recipe(lookFilter, intensity: filterIntensity))
        engine.setGrade(grade)
    }

    func importLooks(_ data: Data) {
        guard let decoded = try? LookImport.decode(data) else {
            banner = "That file is not a Lenscam filter. It needs a title, or saturation, contrast, temperature, and grain."
            return
        }
        for look in decoded {
            if let index = importedLooks.firstIndex(where: { $0.id == look.id }) {
                importedLooks[index] = look
            } else {
                importedLooks.append(look)
            }
        }
        persistLooks()
        if let first = decoded.first {
            selectImported(first)
        }
        banner = decoded.count == 1 ? "Filter added." : "\(decoded.count) filters added."
    }

    func updateAssistant(_ edit: (inout AssistantSettings) -> Void) {
        var copy = assistant
        edit(&copy)
        assistant = AssistantSettings(
            quickTapShutter: copy.quickTapShutter,
            lensSwitching: copy.lensSwitching,
            focusTuning: copy.focusTuning,
            palmGesture: copy.palmGesture,
            voiceShutter: copy.voiceShutter,
            floatingShutter: copy.floatingShutter,
            floatX: copy.floatX,
            floatY: copy.floatY
        )
        persistAssistant()
        engine.applyAssistant(assistant)
        syncVoice()
    }

    func moveFloatingShutter(x: Double, y: Double) {
        assistant = AssistantSettings(
            quickTapShutter: assistant.quickTapShutter,
            lensSwitching: assistant.lensSwitching,
            focusTuning: assistant.focusTuning,
            palmGesture: assistant.palmGesture,
            voiceShutter: assistant.voiceShutter,
            floatingShutter: assistant.floatingShutter,
            floatX: x,
            floatY: y
        )
        persistAssistant()
    }

    private func persistAssistant() {
        if let data = try? JSONEncoder().encode(assistant) {
            UserDefaults.standard.set(data, forKey: "lenscam.assistant")
        }
    }

    private func persistLooks() {
        if let data = try? JSONEncoder().encode(importedLooks) {
            UserDefaults.standard.set(data, forKey: "lenscam.importedLooks")
        }
    }

    func syncVoice() {
        voice.setEnabled(assistant.voiceShutter && !engine.snapshot.isRecording)
    }

    private func voiceShutter() async {
        guard assistant.voiceShutter else { return }
        banner = "Voice shutter."
        await shutter()
        syncVoice()
    }

    private func palmShutter() async {
        guard assistant.palmGesture, engine.snapshot.usingFrontCamera, !engine.snapshot.isRecording, !isBusy else { return }
        banner = "Palm gesture."
        await shutter()
    }

    func setEnhance(_ enabled: Bool) {
        enhanceCopy = enabled
        UserDefaults.standard.set(enabled, forKey: "lenscam.enhance")
    }

    func setExposureManual(_ enabled: Bool) {
        manual.exposureManual = enabled
        if enabled {
            if engine.snapshot.iso > 0 { manual.iso = engine.snapshot.iso }
            if engine.snapshot.shutterSeconds > 0 { manual.shutterSeconds = engine.snapshot.shutterSeconds }
        }
        pushManual()
    }

    func setManualISO(_ iso: Double) {
        manual.exposureManual = true
        manual.iso = iso
        pushManual()
    }

    func setManualShutter(_ seconds: Double) {
        manual.exposureManual = true
        manual.shutterSeconds = seconds
        pushManual()
    }

    func setFocusLocked(_ locked: Bool) {
        manual.focusLocked = locked
        if locked, engine.snapshot.lensPosition > 0 {
            manual.lensPosition = engine.snapshot.lensPosition
        }
        pushManual()
    }

    func setLensPosition(_ position: Double) {
        manual.focusLocked = true
        manual.lensPosition = FocusDial.clamp(position)
        pushManual()
    }

    func setWhiteBalanceManual(_ enabled: Bool) {
        manual.whiteBalanceManual = enabled
        if enabled, manual.temperature == 0 {
            manual.temperature = 5600
        }
        pushManual()
    }

    func setTemperature(_ kelvin: Double) {
        manual.whiteBalanceManual = true
        manual.temperature = WhiteBalanceDial.clamp(kelvin)
        pushManual()
    }

    func setRawChoice(_ choice: RawChoice) {
        rawChoice = choice
        UserDefaults.standard.set(choice.rawValue, forKey: "lenscam.raw")
        engine.setRaw(choice)
    }

    func setAssist(histogram: Bool? = nil, zebra: Bool? = nil, peaking: Bool? = nil, scene: Bool? = nil) {
        if let histogram { showHistogram = histogram }
        if let zebra { showZebra = zebra }
        if let peaking { showPeaking = peaking }
        if let scene {
            showScene = scene
            if !scene { dismissedScene = nil }
        }
        UserDefaults.standard.set(showHistogram, forKey: "lenscam.histogram")
        UserDefaults.standard.set(showZebra, forKey: "lenscam.zebra")
        UserDefaults.standard.set(showPeaking, forKey: "lenscam.peaking")
        UserDefaults.standard.set(showScene, forKey: "lenscam.scene")
        engine.setAssists(histogram: showHistogram, zebra: showZebra, peaking: showPeaking, scene: showScene)
    }

    func acceptScene() {
        guard let genre = engine.snapshot.sceneGenre else { return }
        dismissedScene = nil
        selectGenre(genre)
    }

    func dismissScene() {
        dismissedScene = engine.snapshot.sceneGenre
    }

    var allPresets: [ShootingPreset] { PresetLibrary.builtIn + userPresets }

    func apply(preset: ShootingPreset) {
        foodLookApplied = false
        importedLookID = nil
        activePresetID = preset.id
        lookFilter = preset.filter
        filterIntensity = preset.intensity
        grade = PhotoGrade(LookFilters.recipe(preset.filter, intensity: preset.intensity))
        engine.setGrade(grade)
        manual = preset.manual
        selectGenre(preset.genre)
        engine.setManual(manual)
        setRawChoice(preset.raw)
    }

    func savePreset() {
        let trimmed = presetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Preset \(userPresets.count + 1)" : trimmed
        let preset = ShootingPreset(
            id: UUID(),
            name: name,
            genre: genre,
            filter: lookFilter,
            intensity: filterIntensity,
            manual: manual,
            raw: rawChoice,
            builtIn: false
        )
        userPresets.append(preset)
        PresetStore.save(userPresets)
        activePresetID = preset.id
        presetDraft = ""
        banner = "Saved \(name)."
    }

    func deletePreset(_ id: UUID) {
        userPresets.removeAll { $0.id == id && !$0.builtIn }
        PresetStore.save(userPresets)
        if activePresetID == id { activePresetID = nil }
    }

    private func pushManual() {
        activePresetID = nil
        engine.setManual(manual)
    }

    func acceptSuggestion() {
        guard let suggestion = visibleSuggestion else { return }
        engine.apply(suggestion)
        suggestionPhrase = nil
        banner = "Setting applied."
    }

    func dismissSuggestion() {
        guard let suggestion = visibleSuggestion else { return }
        engine.suppressSuggestion(suggestion.id)
        suggestionPhrase = nil
    }

    func refreshSuggestionPhrase() {
        guard let suggestion = visibleSuggestion else {
            suggestionPhrase = nil
            phrasedSuggestionID = nil
            return
        }
        guard phrasedSuggestionID != suggestion.id else { return }
        phrasedSuggestionID = suggestion.id
        suggestionPhrase = nil
        let sentence = suggestion.sentence
        let id = suggestion.id
        phraseTask?.cancel()
        phraseTask = Task {
            let line = await SuggestionPhrase.rephrase(sentence)
            guard !Task.isCancelled, phrasedSuggestionID == id else { return }
            suggestionPhrase = line
        }
    }

    private func applyPipeline(_ profile: CaptureProfile) {
        self.profile = profile
        engine.apply(profile: profile)
        if profile == .evidence {
            locator.arm()
        } else {
            locator.disarm()
        }
    }

    func setTargetLanguage(_ id: String) {
        targetLanguageID = id
        UserDefaults.standard.set(id, forKey: "lenscam.targetLanguage")
    }

    func consumeRouter() {
        let router = CaptureRouter.shared
        if let requested = router.requestedProfile {
            router.requestedProfile = nil
            select(requested)
        }
        if !router.visualLabels.isEmpty {
            visualLabels = router.visualLabels
        }
        if let id = router.pendingCaptureID {
            router.pendingCaptureID = nil
            path.append(.capture(id))
        }
    }

    func currentZoom(imported: Bool = false) -> ZoomReading {
        if imported { return .imported }
        guard engine.snapshot.isRunning else {
            return ZoomReading(
                factor: 1,
                band: .notMeasured,
                coach: "The lens meter starts when the camera is ready."
            )
        }
        return ZoomMeter.reading(
            zoomFactor: engine.snapshot.zoomFactor,
            opticalStops: engine.snapshot.opticalStops,
            highResolutionCrop: engine.snapshot.highResolutionCrop,
            pastSharpCrop: (tool == nil && genre.watchesSharpCrop) || profile.usesPastSharpCropCue
        )
    }

    private func nightNote(_ note: String) -> String {
        guard engine.snapshot.nightEngaged else { return note }
        let line = "Night mode let the shutter stay open for \(engine.snapshot.nightLabel). The master file was not changed."
        return note.isEmpty ? line : "\(note) \(line)"
    }

    func shutter() async {
        let profile = activeProfile
        if profile == .interview {
            await toggleRecording(cinematic: tool == nil && genre == .cinematic)
            return
        }
        let frames = tool == nil ? genre.burstCount : 1
        if frames > 1 {
            await runBurst(count: frames)
            return
        }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await captureOne(profile: profile)
    }

    /// Marks a held shutter as a burst before the first frame, so letting go does not also take a single photo.
    @discardableResult
    func armHoldBurst() -> Bool {
        guard BurstPolicy.allowsHold(profile: activeProfile), !isBusy, !isBursting else { return false }
        burstCancel = false
        burstTaken = 0
        isBursting = true
        return true
    }

    func stopHoldBurst() {
        burstCancel = true
    }

    func holdBurst() async {
        guard isBursting, !isBusy else { return }
        isBusy = true
        defer {
            isBusy = false
            isBursting = false
            burstTaken = 0
            burstCancel = false
        }
        if burstCancel {
            await captureOne(profile: activeProfile)
            return
        }
        var frames: [(StillCapture, Double)] = []
        let limit = BurstPolicy.frameLimit(nightEngaged: engine.snapshot.nightEngaged)
        while !burstCancel, frames.count < limit {
            guard let still = try? await engine.capture(prefersRaw: false) else { break }
            let data = still.processed ?? still.raw ?? Data()
            frames.append((still, GenreFinish.sharpness(data)))
            burstTaken = frames.count
        }
        if frames.count <= 1, let only = frames.first?.0 {
            await saveStill(only, profile: activeProfile, note: nightNote(""))
            return
        }
        await saveBurst(frames)
    }

    private func captureOne(profile: CaptureProfile) async {
        do {
            let still = try await engine.capture(prefersRaw: wantsRaw(profile))
            await saveStill(still, profile: profile, note: nightNote(""))
        } catch {
            banner = error.localizedDescription
        }
    }

    private func saveStill(_ still: StillCapture, profile: CaptureProfile, note: String) async {
        do {
            let location = profile == .evidence ? locator.currentMark() : nil
            var sidecar = try store.createStill(
                profile: profile,
                genre: tool == nil ? genre : nil,
                zoom: currentZoom(),
                still: still,
                location: location,
                note: note
            )
            reload()
            banner = "Master saved."
            attachFramedCopy(of: still, to: &sidecar)
            attachEnhance(of: still, to: &sidecar)
            sidecar = await enrich(sidecar, imageData: still.processed ?? still.raw)
            reload()
            _ = sidecar
        } catch {
            banner = error.localizedDescription
        }
    }

    private func wantsRaw(_ profile: CaptureProfile) -> Bool {
        RawChoice.wantsRaw(
            choice: rawChoice,
            profilePrefers: profile.recipe.prefersProRAW,
            deviceSupports: engine.snapshot.rawSupported,
            flashOff: engine.snapshot.flash == .off
        )
    }

    private func attachEnhance(of still: StillCapture, to sidecar: inout CaptureSidecar) {
        let framed = still.portrait != nil || still.look != nil
        guard EnhanceCopy.shouldWrite(
            enabled: enhanceCopy,
            allowsEdits: EvidencePolicy.allowsGenerativeEdits(sidecar.profile),
            gradeIsNeutral: grade.isNeutral,
            hasFramedCopy: framed
        ), let data = still.processed ?? still.raw,
              let jpeg = PhotoGradeRender.jpeg(from: data, grade: PhotoGrade(EnhanceCopy.recipe)) else { return }
        try? store.addDerivative(
            kind: .enhance,
            filename: "enhance.jpg",
            data: jpeg,
            note: EnhanceCopy.note,
            to: &sidecar
        )
    }

    private func runBurst(count: Int) async {
        guard !isBusy else { return }
        isBusy = true
        isBursting = true
        burstTaken = 0
        defer {
            isBusy = false
            isBursting = false
            burstTaken = 0
            burstCancel = false
        }
        var frames: [(StillCapture, Double)] = []
        for _ in 0..<count {
            guard let still = try? await engine.capture(prefersRaw: false) else { continue }
            let data = still.processed ?? still.raw ?? Data()
            frames.append((still, GenreFinish.sharpness(data)))
            burstTaken = frames.count
        }
        await saveBurst(frames)
    }

    private func saveBurst(_ frames: [(StillCapture, Double)]) async {
        guard let bestIndex = BurstPolicy.sharpestIndex(in: frames.map(\.1)) else {
            banner = "The burst did not return a frame."
            return
        }
        let best = frames[bestIndex].0
        do {
            let profile = activeProfile == .interview ? CaptureProfile.master : activeProfile
            var sidecar = try store.createStill(
                profile: profile,
                genre: tool == nil ? genre : nil,
                zoom: currentZoom(),
                still: best,
                location: profile == .evidence ? locator.currentMark() : nil,
                note: nightNote("Sharpest frame of a \(frames.count)-frame burst.")
            )
            for (index, frame) in frames.enumerated() where index != bestIndex {
                guard let data = frame.0.processed ?? frame.0.raw else { continue }
                let name = "burst-\(index + 1).heic"
                try? store.addDerivative(
                    kind: .burst,
                    filename: name,
                    data: data,
                    note: "Burst frame. The master is the sharpest frame.",
                    to: &sidecar
                )
            }
            attachFramedCopy(of: best, to: &sidecar)
            attachEnhance(of: best, to: &sidecar)
            reload()
            sidecar = await enrich(sidecar, imageData: best.processed ?? best.raw)
            reload()
            banner = "Burst saved. The master is the sharpest of \(frames.count)."
            _ = sidecar
        } catch {
            banner = error.localizedDescription
        }
    }

    private func attachFramedCopy(of still: StillCapture, to sidecar: inout CaptureSidecar) {
        if let portrait = still.portrait {
            try? store.addDerivative(
                kind: .portrait,
                filename: "portrait.jpg",
                data: portrait,
                note: "Portrait at f/\(String(format: "%g", portraitAperture)) with \(portraitLight.title) light. The edit toolkit is included. The master keeps the original pixels and the depth map.",
                to: &sidecar
            )
        } else if let look = still.look {
            try? store.addDerivative(
                kind: .look,
                filename: "look.jpg",
                data: look,
                note: "The edit chosen before the shutter. The master file was not changed.",
                to: &sidecar
            )
        }
    }

    func importStill(_ data: Data) async {
        guard activeProfile != .interview else {
            banner = "Import a still from a photo genre, or use Read, Brief, or Evidence."
            return
        }
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            var sidecar = try store.createStill(
                profile: activeProfile,
                genre: tool == nil ? genre : nil,
                zoom: .imported,
                still: StillCapture(raw: nil, processed: data),
                location: nil,
                note: "Imported still."
            )
            reload()
            sidecar = await enrich(sidecar, imageData: data)
            reload()
            path.append(.capture(sidecar.id))
        } catch {
            banner = error.localizedDescription
        }
    }

    func rewriteBrief(id: UUID) async {
        guard var sidecar = store.sidecar(id: id) else { return }
        guard EvidencePolicy.allowsGenerativeEdits(sidecar.profile) else {
            banner = "Evidence does not write a model brief."
            return
        }
        isBusy = true
        defer { isBusy = false }
        let outcome = await BriefWriter.write(
            profile: sidecar.profile,
            sourceText: sidecar.reading?.sourceText ?? "",
            transcript: sidecar.transcript.map(\.text).joined(separator: "\n")
        )
        sidecar.brief = outcome.brief
        try? store.save(sidecar)
        reload()
        banner = outcome.message
    }

    func beginTranslation(id: UUID) {
        translationCaptureID = id
        translationConfiguration = TranslationSession.Configuration(
            source: nil,
            target: targetLanguage
        )
    }

    func performTranslation(_ session: TranslationSession) async {
        guard let id = translationCaptureID, var sidecar = store.sidecar(id: id) else { return }
        do {
            try await session.prepareTranslation()
            if !sidecar.transcript.isEmpty {
                for index in sidecar.transcript.indices {
                    let response = try await session.translate(sidecar.transcript[index].text)
                    sidecar.transcript[index].translation = response.targetText
                }
                try store.writeSRT(sidecar)
            } else if let text = sidecar.reading?.sourceText, !text.isEmpty {
                let response = try await session.translate(text)
                if sidecar.reading == nil {
                    sidecar.reading = TextReading(sourceText: text)
                }
                sidecar.reading?.translatedText = response.targetText
                sidecar.reading?.sourceLanguage = response.sourceLanguage.minimalIdentifier
                sidecar.reading?.targetLanguage = response.targetLanguage.minimalIdentifier
            }
            try store.save(sidecar)
            reload()
            banner = "Translation saved beside the master."
        } catch {
            banner = error.localizedDescription
        }
        translationConfiguration = nil
        translationCaptureID = nil
    }

    func saveMasterToPhotos(id: UUID) async {
        guard let sidecar = store.sidecar(id: id) else { return }
        do {
            try await PhotoLibrarySaver.save(
                at: store.file(sidecar, sidecar.masterFilename),
                isVideo: sidecar.codec == "mov"
            )
            banner = "A copy of the master was added to Photos. The hashed file stays in Lenscam."
        } catch {
            banner = error.localizedDescription
        }
    }

    private func toggleRecording(cinematic: Bool) async {
        if engine.snapshot.isRecording {
            do {
                let url = try await engine.stopRecording()
                recordingStarted = nil
                syncVoice()
                isBusy = true
                defer { isBusy = false }
                var sidecar = try store.createMovie(
                    from: url,
                    zoom: currentZoom(),
                    genre: cinematic ? .cinematic : nil
                )
                reload()
                banner = cinematic
                    ? "Take saved. The recording stays ungraded."
                    : "Interview saved. Transcribing on this iPhone."
                sidecar = await finishInterview(sidecar)
                reload()
                path.append(.capture(sidecar.id))
            } catch {
                recordingStarted = nil
                syncVoice()
                banner = error.localizedDescription
            }
        } else {
            voice.setEnabled(false)
            let url = store.makeTemporaryMovieURL()
            do {
                try engine.startRecording(to: url, cinematic: cinematic)
                recordingStarted = Date()
                banner = cinematic
                    ? "Recording at 24 fps when the lens allows it. The master stays ungraded."
                    : "Recording. The transcript is written after you stop, so the take stays uninterrupted."
            } catch {
                syncVoice()
                banner = error.localizedDescription
            }
        }
    }

    private func enrich(_ sidecar: CaptureSidecar, imageData: Data?) async -> CaptureSidecar {
        var sidecar = sidecar
        let recipe = sidecar.profile.recipe
        var readable = ""

        if recipe.readsText, let imageData {
            do {
                let read = try TextReader.read(data: imageData)
                readable = read.text
                var reading = TextReading(sourceText: read.text, barcodes: read.barcodes)
                if recipe.translatesText, !read.text.isEmpty {
                    if let translated = try? await OnDeviceTranslator.translate(read.text, to: targetLanguage) {
                        reading.translatedText = translated.text
                        reading.sourceLanguage = translated.source
                        reading.targetLanguage = translated.target
                        banner = "Text read and translated on device."
                    } else {
                        banner = "Text read. Install the language with Translate if you need a second language."
                    }
                } else if recipe.readsText {
                    banner = read.text.isEmpty ? "No text found in the master." : "Text read on device."
                }
                sidecar.reading = reading
            } catch {
                sidecar.note = [sidecar.note, error.localizedDescription].filter { !$0.isEmpty }.joined(separator: " ")
                banner = error.localizedDescription
            }
        }

        if let genre = sidecar.genre, let imageData, EvidencePolicy.allowsGenerativeEdits(sidecar.profile) {
            let measured = GenreFinish.scene(from: imageData)
            scene = measured
            if let copy = GenreFinish.copy(genre: genre, data: imageData, scene: measured),
               !sidecar.derivatives.contains(where: { $0.kind == copy.kind }) {
                do {
                    try store.addDerivative(
                        kind: copy.kind,
                        filename: copy.filename,
                        data: copy.jpeg,
                        note: copy.note,
                        to: &sidecar
                    )
                    banner = "\(genre.title) copy saved beside the master."
                } catch {
                    banner = error.localizedDescription
                }
            }
            let card = """
            Genre: \(genre.title)
            Zoom: \(sidecar.zoom.factorLabel) \(sidecar.zoom.band.title)
            \(measured.measurement)
            """
            if let line = GenreCoach.line(genre: genre, zoom: sidecar.zoom, scene: measured, stops: []) {
                sidecar.note = [sidecar.note, line].filter { !$0.isEmpty }.joined(separator: " ")
            }
            if sidecar.brief == nil {
                let outcome = await BriefWriter.write(profile: sidecar.profile, sourceText: card, transcript: "")
                sidecar.brief = outcome.brief
            }
        } else if recipe.writesClarityDerivative, let imageData, EvidencePolicy.allowsGenerativeEdits(sidecar.profile),
           let jpeg = ClarityDerivative.jpeg(from: imageData) {
            do {
                try store.addDerivative(
                    kind: .clarity,
                    filename: "clarity.jpg",
                    data: jpeg,
                    note: "Sharpened copy for edges and type. The master file was not changed.",
                    to: &sidecar
                )
                banner = "Clarity copy saved beside the master."
            } catch {
                banner = error.localizedDescription
            }
        }

        if recipe.writesBrief, EvidencePolicy.allowsGenerativeEdits(sidecar.profile) {
            let outcome = await BriefWriter.write(profile: sidecar.profile, sourceText: readable, transcript: "")
            sidecar.brief = outcome.brief
            if let message = outcome.message { banner = message }
        }

        try? store.save(sidecar)
        return sidecar
    }

    private func finishInterview(_ sidecar: CaptureSidecar) async -> CaptureSidecar {
        var sidecar = sidecar
        let movie = store.file(sidecar, sidecar.masterFilename)
        do {
            sidecar.transcript = try await SpeechTranscript.transcribe(movieAt: movie, locale: .current)
            try store.writeSRT(sidecar)
            if sidecar.profile.recipe.translatesText {
                for index in sidecar.transcript.indices {
                    guard let translated = try? await OnDeviceTranslator.translate(
                        sidecar.transcript[index].text,
                        to: targetLanguage
                    ) else { continue }
                    sidecar.transcript[index].translation = translated.text
                }
                try store.writeSRT(sidecar)
            }
            let outcome = await BriefWriter.write(
                profile: .interview,
                sourceText: "",
                transcript: sidecar.transcript.map(\.text).joined(separator: "\n")
            )
            sidecar.brief = outcome.brief
            banner = outcome.message ?? "Transcript saved beside the video."
            if sidecar.genre == .cinematic {
                let asset = AVURLAsset(url: movie)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 1600, height: 1600)
                let time = CMTime(seconds: 0.4, preferredTimescale: 600)
                if let frame = try? await generator.image(at: time),
                   let jpeg = GenreFinish.letterboxJPEG(frame.image) {
                    try? store.addDerivative(
                        kind: .letterbox,
                        filename: "letterbox.jpg",
                        data: jpeg,
                        note: "Letterboxed still from the recording. The video master is ungraded.",
                        to: &sidecar
                    )
                }
            }
        } catch {
            sidecar.note = error.localizedDescription
            banner = error.localizedDescription
        }
        try? store.save(sidecar)
        return sidecar
    }

    private func reload() {
        captures = store.load()
    }
}
