import CoreLocation
import Foundation
import LenscamCore

@MainActor
final class LocationMark: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var last: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func arm() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func disarm() {
        manager.stopUpdatingLocation()
    }

    func currentMark() -> GeoMark? {
        guard let last else { return nil }
        return GeoMark(
            latitude: last.coordinate.latitude,
            longitude: last.coordinate.longitude,
            horizontalAccuracy: last.horizontalAccuracy
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.last = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }
}
