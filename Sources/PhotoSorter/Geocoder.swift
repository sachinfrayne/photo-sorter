import CoreLocation

/// Reverse-geocodes GPS coordinates to a country name using Apple's built-in
/// geocoding service. Calls must be made one at a time (CLGeocoder cancels an
/// in-flight request if a new one starts), which the sequential sort loop
/// already guarantees. Results are cached by rounded coordinate so photos
/// from the same trip only trigger one network lookup.
actor GeocodeCache {
    private var cache: [String: String?] = [:]
    private let geocoder = CLGeocoder()

    func country(for lat: Double, _ lon: Double) async -> String? {
        let key = String(format: "%.2f,%.2f", lat, lon)
        if let cached = cache[key] {
            return cached
        }
        let location = CLLocation(latitude: lat, longitude: lon)
        let country: String?
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            country = placemarks.first?.country
        } catch {
            country = nil
        }
        cache[key] = country
        return country
    }
}
