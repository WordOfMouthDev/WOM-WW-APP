import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var placemark: CLPlacemark?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }
        
        isLoading = true
        errorMessage = nil
        manager.requestLocation()
    }
    
    func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to get location details: \(error.localizedDescription)"
                } else if let placemark = placemarks?.first {
                    self?.placemark = placemark
                }
            }
        }
    }
    
    func createUserLocation(from coordinate: CLLocationCoordinate2D? = nil) -> UserLocation? {
        let finalCoordinate = coordinate ?? location?.coordinate
        guard let coord = finalCoordinate else { return nil }
        
        return UserLocation(
            coordinate: coord,
            placemark: placemark,
            isPermissionGranted: authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        )
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.isLoading = false
            self.reverseGeocode(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Failed to get location: \(error.localizedDescription)"
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch self.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.requestLocation()
            case .denied, .restricted:
                self.errorMessage = "Location access denied"
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
