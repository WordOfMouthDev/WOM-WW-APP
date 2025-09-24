import Foundation
import CoreLocation

struct UserLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let country: String?
    let isPermissionGranted: Bool
    let timestamp: Date
    
    init(coordinate: CLLocationCoordinate2D, placemark: CLPlacemark? = nil, isPermissionGranted: Bool = true) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.city = placemark?.locality
        self.state = placemark?.administrativeArea
        self.country = placemark?.country
        self.isPermissionGranted = isPermissionGranted
        self.timestamp = Date()
    }
    
    init(latitude: Double, longitude: Double, city: String? = nil, state: String? = nil, country: String? = nil, isPermissionGranted: Bool = false) {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
        self.country = country
        self.isPermissionGranted = isPermissionGranted
        self.timestamp = Date()
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayString: String {
        var components: [String] = []
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        if let country = country { components.append(country) }
        return components.joined(separator: ", ")
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "isPermissionGranted": isPermissionGranted,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        if let city = city { dict["city"] = city }
        if let state = state { dict["state"] = state }
        if let country = country { dict["country"] = country }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> UserLocation? {
        guard let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double else {
            return nil
        }
        
        let city = dict["city"] as? String
        let state = dict["state"] as? String
        let country = dict["country"] as? String
        let isPermissionGranted = dict["isPermissionGranted"] as? Bool ?? false
        
        return UserLocation(
            latitude: latitude,
            longitude: longitude,
            city: city,
            state: state,
            country: country,
            isPermissionGranted: isPermissionGranted
        )
    }
}
