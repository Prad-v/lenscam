import LenscamCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CameraScreen: View {
    @Bindable var model: AppModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var pinchOrigin = 1.0
    @State private var focusMark: CGPoint?
    @State private var focusGeneration = 0
    @State private var exposureDragging = false
    @State private var exposureOverride: Double?
    @State private var previewSize: CGSize = .zero
    @State private var editsOpen = false
    @State private var nightOpen = false
    @State private var proOpen = false
    @State private var assistantOpen = false
    @State private var importingLook = false
    @State private var shutterDown = false
    @State private var screenSize: CGSize = .zero
    @State private var floatDragOrigin: CGPoint?

    var body: some View {
        let snapshot = model.engine.snapshot
        let zoom = model.currentZoom()
        ZStack {
            Theme.background.ignoresSafeArea()
            if snapshot.cameraAvailable {
                PreviewView(
                    session: model.engine.previewSession,
                    mirrored: snapshot.usingFrontCamera,
                    onFocus: { devicePoint, viewPoint in
                        focusMark = viewPoint
                        exposureOverride = nil
                        model.engine.focus(at: devicePoint)
                        scheduleFocusHide()
                        if QuickTap.captures(
                            enabled: model.assistant.quickTapShutter,
                            recording: model.engine.snapshot.isRecording,
                            busy: model.isBusy
                        ) {
                            Task { await model.shutter() }
                        }
                    },
                    onCaptureRotation: { angle in
                        model.engine.setCaptureRotation(angle)
                    }
                )
                .ignoresSafeArea()
                .gesture(pinch)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { previewSize = geo.size }
                            .onChange(of: geo.size) { _, size in previewSize = size }
                    }
                )
                .overlay {
                    if let preview = model.engine.portraitPreview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if let assist = model.engine.assistOverlay {
                        Image(uiImage: assist)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFill()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let focusMark {
                        let showsSun = !snapshot.exposureManual
                        let onLeft = showsSun && previewSize.width > 0 && focusMark.x > previewSize.width - 120
                        let anchor = FocusExposureControl.squareCenter(sliderOnLeft: onLeft, showsSun: showsSun)
                        FocusExposureControl(
                            bias: exposureOverride ?? snapshot.exposureBias,
                            minBias: snapshot.minExposureBias,
                            maxBias: snapshot.maxExposureBias,
                            sliderOnLeft: onLeft,
                            showsSun: showsSun,
                            onBias: { value in
                                exposureOverride = value
                                model.engine.setExposureBias(value)
                            },
                            onDragBegan: {
                                exposureDragging = true
                                focusGeneration += 1
                            },
                            onDragEnded: {
                                exposureDragging = false
                                scheduleFocusHide()
                            }
                        )
                        .offset(x: focusMark.x - anchor.x, y: focusMark.y - anchor.y)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if model.showHistogram, !snapshot.histogram.isEmpty {
                        HistogramBars(bins: snapshot.histogram)
                            .padding(.leading, 12)
                            .padding(.bottom, 220)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.system(size: 42, weight: .light))
                    Text(snapshot.message ?? "Preparing the camera.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 32)
                }
            }

            if model.genre.showsGrid, model.tool == nil, snapshot.cameraAvailable {
                HorizonGuide()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                topBar(snapshot, zoom)
                if model.tool == .read, !model.visualLabels.isEmpty {
                    Text(model.visualLabels)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                controls(snapshot)
            }
        }
        .overlay(alignment: .topLeading) {
            if model.assistant.floatingShutter, screenSize.width > 1 {
                floatingShutter
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { screenSize = geo.size }
                    .onChange(of: geo.size) { _, size in screenSize = size }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(isPresented: $importingLook, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    model.importLooks(data)
                } else {
                    model.banner = "That filter file could not be read."
                }
            case .failure:
                model.banner = "That filter file could not be read."
            }
        }
        .onChange(of: model.visibleSuggestion?.id) { _, _ in
            model.refreshSuggestionPhrase()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let imported = try? await item.loadTransferable(type: ImportedImage.self) {
                    await model.importStill(imported.data)
                } else {
                    model.banner = "That file did not include image data."
                }
                pickerItem = nil
            }
        }
    }

    private func topBar(_ snapshot: CameraSnapshot, _ zoom: ZoomReading) -> some View {
        HStack(spacing: 12) {
            Button {
                model.engine.cycleFlash()
            } label: {
                Image(systemName: model.engine.snapshot.flash.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(model.engine.snapshot.flash == .on ? Theme.accent : .white)
                    .frame(width: 36, height: 36)
            }
            .disabled(!model.engine.snapshot.flashAvailable)
            .opacity(model.engine.snapshot.flashAvailable ? 1 : 0.35)
            .accessibilityLabel(model.engine.snapshot.flash.title)
            Button {
                editsOpen.toggle()
                if editsOpen { assistantOpen = false }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .foregroundStyle(editsOpen || !model.grade.isNeutral ? Theme.accent : .white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(editsOpen ? "Hide exposure and color" : "Exposure and color")
            Button {
                nightOpen.toggle()
                if nightOpen { assistantOpen = false }
            } label: {
                Image(systemName: nightSymbol(snapshot))
                    .font(.body.weight(.medium))
                    .foregroundStyle(nightOpen || snapshot.nightEngaged || snapshot.lowLightBoost ? Theme.accent : .white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(nightOpen ? "Hide night mode" : "Night mode")
            .accessibilityValue(snapshot.nightChoice == .off ? "Off" : snapshot.nightLabel)
            Button {
                proOpen.toggle()
                if proOpen { assistantOpen = false }
            } label: {
                Image(systemName: "dial.medium")
                    .font(.body.weight(.medium))
                    .foregroundStyle(proActive(snapshot) ? Theme.accent : .white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(proOpen ? "Hide manual controls" : "Manual controls, presets, and guides")
            Button {
                assistantOpen.toggle()
                if assistantOpen { proOpen = false; editsOpen = false; nightOpen = false }
            } label: {
                Image(systemName: "camera.aperture")
                    .font(.body.weight(.medium))
                    .foregroundStyle(assistantOpen || model.assistant.quickTapShutter || model.assistant.palmGesture || model.assistant.voiceShutter || model.assistant.floatingShutter ? Theme.accent : .white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(assistantOpen ? "Hide camera assistant" : "Camera assistant")
            Spacer()
            Text(zoomPill(zoom))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())
            if model.engine.snapshot.isRecording, let start = model.recordingStarted {
                TimelineView(.periodic(from: start, by: 0.5)) { context in
                    Text(clock(context.date.timeIntervalSince(start)))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.record)
                }
            }
            if snapshot.canSwitchCamera {
                Button {
                    model.engine.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .disabled(snapshot.isRecording)
                .accessibilityLabel(snapshot.usingFrontCamera ? "Use the back camera" : "Use the front camera")
            }
            Button {
                model.path.append(.library)
            } label: {
                Image(systemName: "square.stack")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Library")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
        )
    }

    private func editControls() -> some View {
        VStack(spacing: 14) {
            dial(
                Array(LookFilter.allCases),
                selected: { model.lookFilter == $0 && model.importedLookID == nil },
                title: { $0.title }
            ) { filter in
                model.selectFilter(filter)
            }
            if !model.importedLooks.isEmpty {
                dial(
                    model.importedLooks,
                    selected: { model.importedLookID == $0.id },
                    title: { $0.title }
                ) { look in
                    model.selectImported(look)
                }
            }
            Button("Import filter") { importingLook = true }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("Import a filter file")
            if model.lookFilter != .none || model.importedLookID != nil {
                amountSlider(title: "\(Int((model.filterIntensity * 100).rounded()))", value: model.filterIntensity, range: 0...1) { value in
                    model.setFilterIntensity(value)
                }
            }
            nightChip(model.enhanceCopy ? "Enhance on" : "Enhance copy", on: model.enhanceCopy) {
                model.setEnhance(!model.enhanceCopy)
            }
            dial(
                Array(EditTool.allCases),
                selected: { model.editTool == $0 },
                title: { $0.title }
            ) { tool in
                model.editTool = tool
            }
            amountSlider(
                title: PhotoGrade.label(tool: model.editTool, value: model.grade.value(for: model.editTool)),
                value: model.grade.value(for: model.editTool),
                range: PhotoGrade.range(for: model.editTool)
            ) { value in
                model.setGrade(tool: model.editTool, value: value)
            }
        }
    }

    private func portraitControls(_ snapshot: CameraSnapshot) -> some View {
        VStack(spacing: 14) {
            dial(
                PortraitLight.allCases,
                selected: { model.portraitLight == $0 },
                title: { $0.title }
            ) { light in
                model.setPortraitLight(light)
            }
            if snapshot.portraitDepthAvailable {
                amountSlider(
                    title: "f/\(Self.apertureLabel(model.portraitAperture))",
                    value: model.portraitAperture,
                    range: 1.4...16
                ) { aperture in
                    model.setPortraitAperture(aperture)
                }
            } else {
                Text("This camera has no depth map, so the background will stay sharp.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }

    private static func apertureLabel(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }

    private func amountSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 72, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: range
            )
            .tint(Theme.accent)
        }
        .padding(.horizontal, 20)
    }

    private func dial<Item: Hashable>(
        _ items: [Item],
        selected: @escaping (Item) -> Bool,
        title: @escaping (Item) -> String,
        disabled: Bool = false,
        action: @escaping (Item) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items, id: \.self) { item in
                    let on = selected(item)
                    Button {
                        action(item)
                    } label: {
                        Text(title(item))
                            .font(.system(size: 13, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.accent : Color.white.opacity(0.78))
                    }
                    .disabled(disabled)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func suggestionCard(_ suggestion: SettingAdjustment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.suggestionPhrase ?? suggestion.sentence)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Apply") {
                    model.acceptSuggestion()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.accent, in: Capsule())
                Button("Not now") {
                    model.dismissSuggestion()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func zoomPill(_ zoom: ZoomReading) -> String {
        if zoom.band == .notMeasured { return "Not measured" }
        return "\(zoom.factorLabel) \(zoom.band.title)"
    }

    @ViewBuilder
    private func controls(_ snapshot: CameraSnapshot) -> some View {
        let recording = snapshot.isRecording
        let cinematic = model.tool == nil && model.genre == .cinematic
        VStack(spacing: 14) {
            if let suggestion = model.visibleSuggestion {
                suggestionCard(suggestion)
            } else if let scene = model.visibleScene {
                sceneCard(scene)
            } else if let banner = model.banner {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 28)
            } else if let line = model.coachLine {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 28)
            }
            if let tool = model.tool {
                Button {
                    model.selectGenre(model.genre)
                } label: {
                    Text(tool.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent, in: Capsule())
                }
                .accessibilityLabel("Leave \(tool.title)")
            }
            if nightOpen {
                nightControls(snapshot)
            }
            if proOpen {
                proControls(snapshot)
            }
            if assistantOpen {
                assistantControls()
            }
            if editsOpen, model.tool == nil {
                editControls()
                if model.genre == .portrait {
                    portraitControls(snapshot)
                }
            }
            GenreDial(
                selected: model.genre,
                armed: model.tool == nil,
                enabled: !recording,
                onSelect: { model.selectGenre($0) }
            )
            if snapshot.cameraAvailable, !snapshot.opticalStops.isEmpty {
                HStack(spacing: 14) {
                    ForEach(snapshot.opticalStops, id: \.self) { stop in
                        let selected = abs(snapshot.zoomFactor - stop) < 0.08
                        Button {
                            model.engine.setZoom(stop)
                        } label: {
                            Text(String(format: "%.0f", stop))
                                .font(.system(size: 13, weight: selected ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(selected ? Theme.accent : Color.white.opacity(0.75))
                        }
                    }
                }
            }
            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Import a still")
                .disabled(model.activeProfile == .interview || model.isBusy)

                Spacer()

                shutterButton(recording: recording, cinematic: cinematic, cameraReady: snapshot.cameraAvailable)

                Spacer()

                Menu {
                    Button("Read") { model.select(.read) }
                    Button("Brief") { model.select(.brief) }
                    Button("Evidence") { model.select(.evidence) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Read, brief, and evidence")
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if value.magnification == 1 || pinchOrigin == 0 {
                    pinchOrigin = model.engine.snapshot.zoomFactor
                }
                model.engine.setZoom(pinchOrigin * value.magnification)
            }
            .onEnded { _ in
                pinchOrigin = model.engine.snapshot.zoomFactor
            }
    }

    private func shutterButton(recording: Bool, cinematic: Bool, cameraReady: Bool) -> some View {
        let blocked = (model.isBusy && !model.isBursting) || (!recording && model.activeProfile != .interview && !cameraReady)
        return ZStack {
            Circle()
                .strokeBorder(recording || cinematic ? Theme.record : Color.white, lineWidth: 3)
                .frame(width: 74, height: 74)
            if recording {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.record)
                    .frame(width: 26, height: 26)
            } else if cinematic {
                Circle().fill(Theme.record).frame(width: 58, height: 58)
            }
            if model.isBursting {
                Text(model.burstTaken > 0 ? "\(model.burstTaken)" : " ")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            } else if model.isBusy {
                ProgressView().tint(.white)
            }
        }
        .contentShape(Circle())
        .opacity(blocked ? 0.4 : 1)
        .overlay {
            if !blocked {
                ShutterPress(onDown: shutterDownAction, onUp: shutterUpAction)
            }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(shutterLabel(recording: recording, cinematic: cinematic))
        .accessibilityAction {
            Task { await model.shutter() }
        }
    }

    private func shutterDownAction() {
        guard !shutterDown else { return }
        shutterDown = true
        guard BurstPolicy.allowsHold(profile: model.activeProfile) else { return }
        Task {
            try? await Task.sleep(for: .seconds(BurstPolicy.holdDelaySeconds))
            guard shutterDown else { return }
            guard model.armHoldBurst() else { return }
            await model.holdBurst()
        }
    }

    private func shutterUpAction() {
        let bursting = model.isBursting
        shutterDown = false
        if bursting {
            model.stopHoldBurst()
        } else if !model.isBusy {
            Task { await model.shutter() }
        }
    }

    private func shutterLabel(recording: Bool, cinematic: Bool) -> String {
        if recording { return "Stop recording" }
        if cinematic { return "Record cinematic" }
        return "Take photo. Hold for a burst."
    }

    private func scheduleFocusHide() {
        focusGeneration += 1
        let generation = focusGeneration
        Task {
            try? await Task.sleep(for: .seconds(6))
            guard generation == focusGeneration, !exposureDragging else { return }
            focusMark = nil
            exposureOverride = nil
        }
    }

    private func nightSymbol(_ snapshot: CameraSnapshot) -> String {
        if snapshot.nightChoice == .off { return "moon.slash" }
        return snapshot.nightEngaged ? "moon.fill" : "moon"
    }

    private func nightControls(_ snapshot: CameraSnapshot) -> some View {
        let plan = NightPlan(
            longExposure: snapshot.nightEngaged,
            seconds: snapshot.nightSeconds,
            boost: snapshot.lowLightBoost
        )
        let duration = snapshot.nightChoice == .manual ? snapshot.nightManualSeconds : max(snapshot.nightSeconds, NightMode.minimumSeconds)
        return VStack(spacing: 8) {
            HStack(spacing: 16) {
                nightChip("Off", on: snapshot.nightChoice == .off) {
                    model.engine.setNight(.off)
                }
                nightChip("Auto", on: snapshot.nightChoice == .auto) {
                    model.engine.setNight(.auto)
                }
                nightChip(snapshot.nightChoice == .manual ? snapshot.nightLabel : "Time", on: snapshot.nightChoice == .manual) {
                    model.engine.setNightDuration(duration)
                }
            }
            if snapshot.nightChoice != .off {
                Slider(
                    value: Binding(
                        get: { duration },
                        set: { model.engine.setNightDuration($0) }
                    ),
                    in: NightMode.minimumSeconds...NightMode.maximumSeconds
                )
                .tint(Theme.accent)
                .padding(.horizontal, 20)
                .accessibilityLabel("Night exposure time")
            }
            Text(NightMode.caption(choice: snapshot.nightChoice, plan: plan))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Text("This is a longer shutter and low-light boost, not Apple's Night mode.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func nightChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.accent : Color.white.opacity(0.78))
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func proActive(_ snapshot: CameraSnapshot) -> Bool {
        proOpen || snapshot.exposureManual || snapshot.focusLocked || snapshot.whiteBalanceManual
            || snapshot.rawChoice == .on || model.showHistogram || model.showZebra || model.showPeaking
    }

    private func sceneCard(_ genre: CaptureGenre) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SceneGuide.sentence(for: genre))
                .font(.subheadline)
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Button("Switch") { model.acceptScene() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.accent, in: Capsule())
                Button("Not now") { model.dismissScene() }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func proControls(_ snapshot: CameraSnapshot) -> some View {
        VStack(spacing: 12) {
            Text("ISO \(Int(snapshot.iso.rounded())) · \(ManualExposure.label(seconds: snapshot.shutterSeconds))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            HStack(spacing: 16) {
                nightChip("Auto", on: !snapshot.exposureManual) { model.setExposureManual(false) }
                nightChip("Manual", on: snapshot.exposureManual) { model.setExposureManual(true) }
            }
            if snapshot.exposureManual, snapshot.maxISO > snapshot.minISO, snapshot.maxShutter > snapshot.minShutter {
                logSlider(
                    title: "ISO \(Int(model.manual.iso.rounded()))",
                    value: model.manual.iso,
                    range: snapshot.minISO...snapshot.maxISO
                ) { model.setManualISO($0) }
                logSlider(
                    title: ManualExposure.label(seconds: model.manual.shutterSeconds),
                    value: model.manual.shutterSeconds,
                    range: snapshot.minShutter...snapshot.maxShutter
                ) { model.setManualShutter($0) }
            }
            HStack(spacing: 16) {
                nightChip("AF", on: !snapshot.focusLocked) { model.setFocusLocked(false) }
                nightChip("MF", on: snapshot.focusLocked) { model.setFocusLocked(true) }
            }
            if snapshot.focusLocked {
                amountSlider(title: "Focus", value: model.manual.lensPosition, range: 0...1) { model.setLensPosition($0) }
            }
            HStack(spacing: 16) {
                nightChip("AWB", on: !snapshot.whiteBalanceManual) { model.setWhiteBalanceManual(false) }
                nightChip("Kelvin", on: snapshot.whiteBalanceManual) { model.setWhiteBalanceManual(true) }
            }
            if snapshot.whiteBalanceManual {
                amountSlider(
                    title: WhiteBalanceDial.label(model.manual.temperature),
                    value: model.manual.temperature,
                    range: WhiteBalanceDial.minKelvin...WhiteBalanceDial.maxKelvin
                ) { model.setTemperature($0) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(WhiteBalanceDial.named) { preset in
                            nightChip(preset.title, on: abs(model.manual.temperature - preset.kelvin) < 30) {
                                model.setTemperature(preset.kelvin)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            if snapshot.rawSupported {
                HStack(spacing: 16) {
                    ForEach(RawChoice.allCases, id: \.self) { choice in
                        nightChip("RAW \(choice.title)", on: model.rawChoice == choice) { model.setRawChoice(choice) }
                    }
                }
            } else {
                Text("This camera cannot write ProRAW.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            dial(model.allPresets, selected: { model.activePresetID == $0.id }, title: { $0.name }) { preset in
                model.apply(preset: preset)
            }
            HStack(spacing: 12) {
                TextField("Preset name", text: $model.presetDraft)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Button("Save") { model.savePreset() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                if let id = model.activePresetID, model.userPresets.contains(where: { $0.id == id }) {
                    Button("Remove") { model.deletePreset(id) }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            HStack(spacing: 14) {
                nightChip("Histogram", on: model.showHistogram) { model.setAssist(histogram: !model.showHistogram) }
                nightChip("Zebra", on: model.showZebra) { model.setAssist(zebra: !model.showZebra) }
                nightChip("Peaking", on: model.showPeaking) { model.setAssist(peaking: !model.showPeaking) }
                nightChip("Scene", on: model.showScene) { model.setAssist(scene: !model.showScene) }
            }
            Text("Manual exposure, focus, and white balance lock the sensor. A saved preset recalls them. The enhance copy and filters stay beside the master.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func logSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let lower = log2(max(range.lowerBound, 0.000_000_1))
        let upper = log2(max(range.upperBound, range.lowerBound * 1.01))
        return HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 72, alignment: .leading)
            Slider(
                value: Binding(
                    get: { log2(max(value, range.lowerBound)) },
                    set: { onChange(pow(2, $0)) }
                ),
                in: lower...upper
            )
            .tint(Theme.accent)
        }
        .padding(.horizontal, 20)
    }

    private func assistantControls() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                nightChip("Quick tap", on: model.assistant.quickTapShutter) {
                    model.updateAssistant { $0.quickTapShutter.toggle() }
                }
                nightChip("Palm", on: model.assistant.palmGesture) {
                    model.updateAssistant { $0.palmGesture.toggle() }
                }
                nightChip("Voice", on: model.assistant.voiceShutter) {
                    model.updateAssistant { $0.voiceShutter.toggle() }
                }
                nightChip("Float", on: model.assistant.floatingShutter) {
                    model.updateAssistant { $0.floatingShutter.toggle() }
                }
            }
            dial(
                Array(LensSwitching.allCases),
                selected: { model.assistant.lensSwitching == $0 },
                title: { $0.title }
            ) { mode in
                model.updateAssistant { $0.lensSwitching = mode }
            }
            dial(
                Array(FocusTuning.allCases),
                selected: { model.assistant.focusTuning == $0 },
                title: { $0.title }
            ) { tuning in
                model.updateAssistant { $0.focusTuning = tuning }
            }
            Text("Quick tap shoots from a tap on the picture. Palm works on the front camera. Voice listens for cheese, shoot, capture, or smile. Drag the floating shutter to move it. Hold keeps the lens when the genre changes. Nearest snaps zoom to a lens stop.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var floatingShutter: some View {
        let x = FloatingShutter.clamped(model.assistant.floatX) * screenSize.width - 29
        let y = FloatingShutter.clamped(model.assistant.floatY) * screenSize.height - 29
        return Button {
            Task { await model.shutter() }
        } label: {
            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .background(Circle().fill(.black.opacity(0.35)))
                .frame(width: 58, height: 58)
        }
        .offset(x: max(8, x), y: max(8, y))
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    if floatDragOrigin == nil {
                        floatDragOrigin = CGPoint(x: model.assistant.floatX, y: model.assistant.floatY)
                    }
                    let origin = floatDragOrigin ?? CGPoint(x: model.assistant.floatX, y: model.assistant.floatY)
                    model.moveFloatingShutter(
                        x: origin.x + value.translation.width / max(screenSize.width, 1),
                        y: origin.y + value.translation.height / max(screenSize.height, 1)
                    )
                }
                .onEnded { _ in
                    floatDragOrigin = nil
                }
        )
        .accessibilityLabel("Floating shutter")
    }

    private func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct GenreDial: View {
    let selected: CaptureGenre
    /// False while Read, Brief, or Evidence has replaced the genre.
    let armed: Bool
    let enabled: Bool
    let onSelect: (CaptureGenre) -> Void

    @State private var drag: CGFloat = 0
    @State private var dragging = false

    private let genres = Array(CaptureGenre.allCases)
    private let slot: CGFloat = 108

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let current = genres.firstIndex(of: selected) ?? 0
                let focus = focusIndex(current: current)
                let resting = geo.size.width / 2 - (CGFloat(current) * slot + slot / 2)
                HStack(spacing: 0) {
                    ForEach(Array(genres.enumerated()), id: \.element.id) { offset, genre in
                        slotButton(genre, offset: offset, focus: focus)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: resting + drag)
                .animation(dragging ? .none : .snappy(duration: 0.28), value: drag)
                .animation(dragging ? .none : .snappy(duration: 0.28), value: selected)
            }
            .frame(height: 40)
            .clipped()
            .mask(edgeFade)
            Capsule()
                .fill(armed ? Theme.accent : Color.white.opacity(0.35))
                .frame(width: 16, height: 2)
        }
        .opacity(enabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Swipe sideways to change genre")
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func slotButton(_ genre: CaptureGenre, offset: Int, focus: Double) -> some View {
        let distance = abs(Double(offset) - focus)
        let centered = distance < 0.5
        let emphasized = centered && armed
        return Button {
            guard enabled else { return }
            onSelect(genre)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol(genre))
                    .font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                Text(genre.title)
                    .font(.system(size: 11, weight: emphasized ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(emphasized ? Theme.accent : Color.white.opacity(max(0.28, 0.82 - distance * 0.34)))
            .frame(width: slot)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(genre.title)
        .accessibilityAddTraits(emphasized ? .isSelected : [])
    }

    private func focusIndex(current: Int) -> Double {
        let shifted = Double(current) - Double(drag / slot)
        return min(max(shifted, 0), Double(genres.count - 1))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard enabled else { return }
                dragging = true
                drag = value.translation.width
            }
            .onEnded { value in
                defer {
                    dragging = false
                    drag = 0
                }
                guard enabled else { return }
                let current = genres.firstIndex(of: selected) ?? 0
                let next = GenreDialMotion.index(
                    from: current,
                    translation: Double(value.predictedEndTranslation.width),
                    slot: Double(slot),
                    count: genres.count
                )
                guard next != current else { return }
                onSelect(genres[next])
            }
    }

    private var edgeFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func symbol(_ genre: CaptureGenre) -> String {
        switch genre {
        case .photography: "camera"
        case .portrait: "person.crop.circle"
        case .landscape: "mountain.2"
        case .nature: "leaf"
        case .food: "fork.knife"
        case .wildlife: "binoculars"
        case .sport: "figure.run"
        case .cinematic: "film"
        }
    }
}

private struct HorizonGuide: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: w * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: w * 2 / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: h * 2 / 3))
                path.addLine(to: CGPoint(x: w, y: h * 2 / 3))
                path.move(to: CGPoint(x: 16, y: h / 2))
                path.addLine(to: CGPoint(x: w - 16, y: h / 2))
            }
            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
        }
        .ignoresSafeArea()
    }
}

private struct FocusExposureControl: View {
    var bias: Double
    var minBias: Double
    var maxBias: Double
    var sliderOnLeft: Bool
    var showsSun: Bool = true
    var onBias: (Double) -> Void
    var onDragBegan: () -> Void
    var onDragEnded: () -> Void

    @State private var dragging = false

    static let box: CGFloat = 72
    static let track: CGFloat = 132
    static let sliderWidth: CGFloat = 36
    static let gap: CGFloat = 8

    static func squareCenter(sliderOnLeft: Bool, showsSun: Bool = true) -> CGPoint {
        if !showsSun { return CGPoint(x: box / 2, y: box / 2) }
        let x = sliderOnLeft ? sliderWidth + gap + box / 2 : box / 2
        return CGPoint(x: x, y: track / 2)
    }

    var body: some View {
        if showsSun {
            HStack(spacing: Self.gap) {
                if sliderOnLeft { sun }
                focusBox
                if !sliderOnLeft { sun }
            }
            .frame(height: Self.track)
        } else {
            focusBox
        }
    }

    private var focusBox: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .stroke(Theme.accent, lineWidth: 1.5)
            .frame(width: Self.box, height: Self.box)
            .allowsHitTesting(false)
    }

    private var sun: some View {
        let fraction = ExposureDial.fraction(bias: bias, min: minBias, max: maxBias)
        return ZStack(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: 1.5, height: Self.track)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .offset(y: (1 - fraction) * (Self.track - 18))
        }
        .frame(width: Self.sliderWidth, height: Self.track)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !dragging {
                        dragging = true
                        onDragBegan()
                    }
                    let y = min(Self.track, max(0, value.location.y))
                    onBias(ExposureDial.bias(fraction: 1 - (y / Self.track), min: minBias, max: maxBias))
                }
                .onEnded { _ in
                    dragging = false
                    onDragEnded()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Exposure")
        .accessibilityValue(ExposureDial.label(bias))
        .accessibilityAdjustableAction { direction in
            let step = (maxBias - minBias) / 16
            let next = direction == .increment ? bias + step : bias - step
            onBias(min(maxBias, max(minBias, next)))
        }
    }
}

private struct HistogramBars: View {
    var bins: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(bins.enumerated()), id: \.offset) { _, bin in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.white.opacity(0.9))
                    .frame(width: 4, height: max(2, 32 * bin))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("Histogram")
    }
}

private struct ShutterPress: UIViewRepresentable {
    var onDown: () -> Void
    var onUp: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.press(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = true
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDown = onDown
        context.coordinator.onUp = onUp
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onDown: () -> Void = {}
        var onUp: () -> Void = {}
        private var down = false

        @objc func press(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                guard !down else { return }
                down = true
                onDown()
            case .ended, .cancelled, .failed:
                guard down else { return }
                down = false
                onUp()
            default:
                break
            }
        }
    }
}

private struct ImportedImage: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedImage(data: data)
        }
    }
}
