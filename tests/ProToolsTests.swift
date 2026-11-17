import XCTest
@testable import LenscamCore

final class ProToolsTests: XCTestCase {
    func testRawStaysOffWithoutSupportOrWithFlash() {
        XCTAssertFalse(RawChoice.wantsRaw(choice: .on, profilePrefers: true, deviceSupports: false, flashOff: true))
        XCTAssertFalse(RawChoice.wantsRaw(choice: .on, profilePrefers: true, deviceSupports: true, flashOff: false))
        XCTAssertFalse(RawChoice.wantsRaw(choice: .off, profilePrefers: true, deviceSupports: true, flashOff: true))
        XCTAssertTrue(RawChoice.wantsRaw(choice: .on, profilePrefers: false, deviceSupports: true, flashOff: true))
        XCTAssertTrue(RawChoice.wantsRaw(choice: .auto, profilePrefers: true, deviceSupports: true, flashOff: true))
        XCTAssertFalse(RawChoice.wantsRaw(choice: .auto, profilePrefers: false, deviceSupports: true, flashOff: true))
    }

    func testManualClampsToTheLens() {
        XCTAssertEqual(ManualExposure.clampISO(50, min: 64, max: 2000), 64, accuracy: 0.1)
        XCTAssertEqual(ManualExposure.clampShutter(2, min: 1.0 / 8000, max: 1), 1, accuracy: 0.001)
        XCTAssertEqual(ManualExposure.label(seconds: 1.0 / 125), "1/125")
        XCTAssertEqual(FocusDial.clamp(1.4), 1, accuracy: 0.001)
        XCTAssertEqual(WhiteBalanceDial.clamp(2000), 3000, accuracy: 0.1)
        XCTAssertEqual(WhiteBalanceDial.label(5600), "5600K")
        XCTAssertEqual(WhiteBalanceDial.named.map(\.title), ["Day", "Cloud", "Shade", "Tungsten", "Fluor"])
    }

    func testGrainFilterAndImportedLooks() {
        let grain = LookFilters.recipe(.grain, intensity: 1)
        XCTAssertGreaterThan(grain.grain, 0.5)
        XCTAssertTrue(LookFilters.recipe(.grain, intensity: 0).isNeutral)
        let file = Data(#"{"title":"Plate","saturation":1.4,"contrast":0.2,"temperature":-0.3,"grain":0.4}"#.utf8)
        let looks = try? LookImport.decode(file)
        XCTAssertEqual(looks?.first?.title, "Plate")
        XCTAssertEqual(looks?.first?.saturation ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(looks?.first?.grain ?? 0, 0.4, accuracy: 0.001)
        let recipe = looks?.first?.recipe(intensity: 0.5)
        XCTAssertEqual(recipe?.color ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(recipe?.grain ?? 0, 0.2, accuracy: 0.001)
        XCTAssertThrowsError(try LookImport.decode(Data("{}".utf8)))
    }

    func testFilterIntensityDoesNotInventALookAtZero() {
        let vivid = LookFilters.recipe(.vivid, intensity: 0)
        XCTAssertTrue(vivid.isNeutral)
        let full = LookFilters.recipe(.vivid, intensity: 1)
        XCTAssertEqual(full.contrast, 0.45, accuracy: 0.001)
        XCTAssertFalse(LookFilters.recipe(.mono, intensity: 0.4).mono)
        XCTAssertTrue(LookFilters.recipe(.mono, intensity: 1).mono)
    }

    func testEnhanceCopyStaysOffTheMasterAndOffEvidence() {
        XCTAssertFalse(EnhanceCopy.shouldWrite(enabled: true, allowsEdits: false, gradeIsNeutral: true, hasFramedCopy: false))
        XCTAssertFalse(EnhanceCopy.shouldWrite(enabled: true, allowsEdits: true, gradeIsNeutral: false, hasFramedCopy: false))
        XCTAssertFalse(EnhanceCopy.shouldWrite(enabled: false, allowsEdits: true, gradeIsNeutral: true, hasFramedCopy: false))
        XCTAssertFalse(EnhanceCopy.shouldWrite(enabled: true, allowsEdits: true, gradeIsNeutral: true, hasFramedCopy: true))
        XCTAssertTrue(EnhanceCopy.shouldWrite(enabled: true, allowsEdits: true, gradeIsNeutral: true, hasFramedCopy: false))
        XCTAssertFalse(EnhanceCopy.recipe.isNeutral)
    }

    func testSceneGuidePrefersAPersonOverTheHorizon() {
        XCTAssertEqual(SceneGuide.suggestion(face: true, animal: false, horizon: 1, current: .photography), .portrait)
        XCTAssertNil(SceneGuide.suggestion(face: true, animal: false, horizon: nil, current: .portrait))
        XCTAssertEqual(SceneGuide.suggestion(face: false, animal: true, horizon: nil, current: .photography), .wildlife)
        XCTAssertNil(SceneGuide.suggestion(face: false, animal: true, horizon: nil, current: .nature))
        XCTAssertEqual(SceneGuide.suggestion(face: nil, animal: nil, horizon: 2, current: .photography), .landscape)
        XCTAssertNil(SceneGuide.suggestion(face: nil, animal: nil, horizon: nil, current: .photography))
    }

    func testBuiltInPresetsCoverActionAndIndoor() {
        let names = PresetLibrary.builtIn.map(\.name)
        XCTAssertEqual(names, ["Daylight", "Indoor", "Action", "Vivid", "Mono"])
        let action = PresetLibrary.builtIn.first { $0.id == PresetLibrary.action }
        XCTAssertEqual(action?.genre, .sport)
        XCTAssertFalse(action?.manual.exposureManual ?? true)
        XCTAssertEqual(PresetLibrary.builtIn.first { $0.id == PresetLibrary.indoor }?.manual.temperature ?? 0, 3800, accuracy: 0.1)
        XCTAssertTrue(PresetLibrary.builtIn.allSatisfy(\.builtIn))
    }
}
