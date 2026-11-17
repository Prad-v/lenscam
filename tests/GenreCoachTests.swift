import XCTest
@testable import LenscamCore

final class GenreCoachTests: XCTestCase {
    private let stops = [1.0, 2.0, 5.0]

    func testWildlifeOpticalIsReady() {
        let zoom = ZoomMeter.reading(zoomFactor: 5, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        XCTAssertEqual(zoom.band, .optical)
        XCTAssertNil(GenreCoach.line(genre: .wildlife, zoom: zoom, stops: stops))
    }

    func testWildlifePastTheSharpCropAsksToMoveCloser() {
        let zoom = ZoomMeter.reading(zoomFactor: 12, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        XCTAssertEqual(zoom.band, .pastSharpCrop)
        let line = GenreCoach.line(genre: .wildlife, zoom: zoom, stops: stops)
        XCTAssertEqual(line, "Wildlife stays on the telephoto. Move closer.")
    }

    func testPortraitAsksForTheTwoTimesLens() {
        let zoom = ZoomMeter.reading(zoomFactor: 1, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: false)
        XCTAssertEqual(
            GenreCoach.line(genre: .portrait, zoom: zoom, stops: stops),
            "Portrait wants the 2× lens."
        )
    }

    func testPortraitOnTwoTimesIsReady() {
        let zoom = ZoomMeter.reading(zoomFactor: 2, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: false)
        XCTAssertNil(GenreCoach.line(genre: .portrait, zoom: zoom, stops: stops))
    }

    func testLandscapeReportsATiltedHorizon() {
        let zoom = ZoomMeter.reading(zoomFactor: 1, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: false)
        let scene = SceneReading(horizonDegrees: 3.2)
        XCTAssertEqual(
            GenreCoach.line(genre: .landscape, zoom: zoom, scene: scene, stops: stops),
            "Horizon is 3° off."
        )
    }

    func testLandscapeLevelHorizonIsReady() {
        let zoom = ZoomMeter.reading(zoomFactor: 1, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: false)
        let scene = SceneReading(horizonDegrees: 0.4)
        XCTAssertNil(GenreCoach.line(genre: .landscape, zoom: zoom, scene: scene, stops: stops))
    }

    func testSportDigitalZoomIsCalledOut() {
        let zoom = ZoomMeter.reading(zoomFactor: 3.2, opticalStops: [1, 2], highResolutionCrop: false, pastSharpCrop: false)
        XCTAssertEqual(zoom.band, .digital)
        XCTAssertNotNil(GenreCoach.line(genre: .sport, zoom: zoom, stops: [1, 2]))
    }

    func testFoodStaysOnTheWideLens() {
        XCTAssertEqual(CaptureGenre.food.preferredZoom(among: stops), 1)
        XCTAssertEqual(CaptureGenre.food.title, "Food")
        let tele = ZoomMeter.reading(zoomFactor: 5, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        XCTAssertEqual(GenreCoach.line(genre: .food, zoom: tele, stops: stops), "Food stays on the wide lens.")
        let digital = ZoomMeter.reading(zoomFactor: 12, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        XCTAssertEqual(
            GenreCoach.line(genre: .food, zoom: digital, stops: stops),
            "Food wants the plate closer, on the wide lens."
        )
        let wide = ZoomMeter.reading(zoomFactor: 1, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        XCTAssertNil(GenreCoach.line(genre: .food, zoom: wide, stops: stops))
    }

    func testPreferredStops() {
        XCTAssertEqual(CaptureGenre.landscape.preferredZoom(among: stops), 1)
        XCTAssertEqual(CaptureGenre.food.preferredZoom(among: stops), 1)
        XCTAssertEqual(CaptureGenre.portrait.preferredZoom(among: stops), 2)
        XCTAssertEqual(CaptureGenre.wildlife.preferredZoom(among: stops), 5)
        XCTAssertNil(CaptureGenre.photography.preferredZoom(among: stops))
        XCTAssertEqual(CaptureGenre.sport.burstCount, 4)
        XCTAssertEqual(CaptureGenre.photography.burstCount, 1)
    }

    func testDialSwipeMovesBySlotsAndStopsAtTheEnds() {
        XCTAssertEqual(GenreDialMotion.index(from: 2, translation: 0, slot: 108, count: 7), 2)
        XCTAssertEqual(GenreDialMotion.index(from: 2, translation: -30, slot: 108, count: 7), 2)
        XCTAssertEqual(GenreDialMotion.index(from: 2, translation: -108, slot: 108, count: 7), 3)
        XCTAssertEqual(GenreDialMotion.index(from: 2, translation: 108, slot: 108, count: 7), 1)
        XCTAssertEqual(GenreDialMotion.index(from: 0, translation: 400, slot: 108, count: 7), 0)
        XCTAssertEqual(GenreDialMotion.index(from: 1, translation: -800, slot: 108, count: 7), 6)
        XCTAssertEqual(GenreDialMotion.index(from: 3, translation: 50, slot: 0, count: 7), 3)
        XCTAssertEqual(GenreDialMotion.index(from: 0, translation: -10, slot: 108, count: 0), 0)
    }

    func testUnmeasuredZoomStaysQuiet() {
        let zoom = ZoomReading(factor: 1, band: .notMeasured, coach: "waiting")
        XCTAssertNil(GenreCoach.line(genre: .wildlife, zoom: zoom, stops: stops))
    }
}
