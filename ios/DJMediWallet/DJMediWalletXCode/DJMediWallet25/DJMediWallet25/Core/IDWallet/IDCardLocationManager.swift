import Foundation
import CoreLocation
import Combine
import MapKit

final class IDCardLocationManager: NSObject, ObservableObject {
    enum Region: String {
        case unitedKingdom = "GB"
        case jersey = "JE"
        case guernsey = "GG"
    }

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var detectedRegionCode: String?

    private let manager = CLLocationManager()
    private var activeReverseGeocode: Task<Void, Never>?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAccess() {
        if CLLocationManager.locationServicesEnabled() {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdating() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        activeReverseGeocode?.cancel()
        activeReverseGeocode = nil
    }

    deinit {
        stopUpdating()
    }
}

extension IDCardLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startUpdating()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            detectedRegionCode = nil
            stopUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        activeReverseGeocode?.cancel()
        activeReverseGeocode = Task { [weak self] in
            guard let self else { return }
            do {
                guard #available(iOS 26.0, *),
                      let request = MKReverseGeocodingRequest(location: location) else {
                    await MainActor.run { self.detectedRegionCode = nil }
                    return
                }

                let mapItems = try await request.mapItems
                let countryCode = mapItems.lazy.compactMap { item -> String? in
                    guard let region = item.addressRepresentations?.region else { return nil }
                    let identifier = region.identifier
                    return identifier.isEmpty ? nil : identifier.uppercased()
                }.first

                await MainActor.run {
                    self.detectedRegionCode = countryCode
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { self.detectedRegionCode = nil }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        detectedRegionCode = nil
    }
}
