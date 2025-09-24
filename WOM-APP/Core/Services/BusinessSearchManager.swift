import Foundation
import MapKit
import CoreLocation
import CryptoKit

@MainActor
class BusinessSearchManager: ObservableObject {
    @Published var businesses: [Business] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoadingMore = false
    
    private var allBusinesses: [Business] = []
    private let pageSize = 10
    
    // Search configuration
    private let maxDistanceMeters: Double = 8000 // 8km (5 miles) maximum distance
    private let requireWebsite = false // Allow businesses without websites to get more results
    
    // Google Places API configuration - now primary search source
    private let googlePlacesAPIKey = "AIzaSyABz-2T8RBzsORMAQjjoT0UTKO4558YBO0"
    private let placesBaseURL = "https://maps.googleapis.com/maps/api/place"
    
    // Cache for place details to avoid repeated API calls
    private var placeDetailsCache: [String: GooglePlaceDetails] = [:]
    
    // Efficient place details fetching with caching
    private func getPlaceDetails(placeId: String) async -> GooglePlaceDetails? {
        // Check cache first
        if let cached = placeDetailsCache[placeId] {
            return cached
        }
        
        do {
            let fields = "name,formatted_address,formatted_phone_number,website,permanently_closed,opening_hours,price_level,rating,user_ratings_total,photos"
            guard let url = URL(string: "\(placesBaseURL)/details/json?place_id=\(placeId)&fields=\(fields)&key=\(googlePlacesAPIKey)") else {
                return nil
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
            
            // Cache the result
            if let result = response.result {
                placeDetailsCache[placeId] = result
                return result
            }
        } catch {
            print("Error fetching place details for \(placeId): \(error)")
        }
        
        return nil
    }
    
    func searchBusinesses(near coordinate: CLLocationCoordinate2D, categories: [BusinessCategory]) async throws {
        isLoading = true
        errorMessage = nil
        businesses = []
        allBusinesses = []
        
        var searchResults: [Business] = []
        
        // Search using Google Places API for each category
        for category in categories {
            for query in category.queries {
                do {
                    let categoryBusinesses = try await searchBusinessesViaGooglePlaces(
                        query: query,
                        near: coordinate,
                        category: category.slug
                    )
                    searchResults.append(contentsOf: categoryBusinesses)
                } catch {
                    print("Error searching Google Places for \(query): \(error)")
                    // Continue with other queries even if one fails
                }
            }
            
            // Also search with just the category label for broader results
            do {
                let labelBusinesses = try await searchBusinessesViaGooglePlaces(
                    query: category.label,
                    near: coordinate,
                    category: category.slug
                )
                searchResults.append(contentsOf: labelBusinesses)
            } catch {
                print("Error searching Google Places for category label \(category.label): \(error)")
            }
        }
        
        // Resolve canonical WOM IDs using stored aliases before deduplication
        let resolvedBusinesses = await BusinessResolver.shared.resolve(searchResults)

        // Remove duplicates with improved address-based deduplication
        let uniqueBusinesses = removeDuplicatesAdvanced(from: resolvedBusinesses)
        
        // Sort by distance from user location
        let sortedBusinesses = uniqueBusinesses.sorted { business1, business2 in
            let distance1 = CLLocation(latitude: business1.coordinate.latitude, longitude: business1.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            let distance2 = CLLocation(latitude: business2.coordinate.latitude, longitude: business2.coordinate.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return distance1 < distance2
        }
        
        // Store all businesses for pagination
        allBusinesses = Array(sortedBusinesses.prefix(100)) // Limit to 100 total
        
        // Load first page
        await loadInitialPage()
        
        isLoading = false
    }
    
    func loadMoreBusinesses() async {
        guard !isLoadingMore, businesses.count < allBusinesses.count else { return }
        
        isLoadingMore = true
        
        let startIndex = businesses.count
        let endIndex = min(startIndex + pageSize, allBusinesses.count)
        let nextBatch = Array(allBusinesses[startIndex..<endIndex])
        
        // Fetch images for next batch
        let businessesWithImages = await fetchImagesForBusinesses(nextBatch)
        
        businesses.append(contentsOf: businessesWithImages)
        
        isLoadingMore = false
    }
    
    private func loadInitialPage() async {
        let initialBatch = Array(allBusinesses.prefix(pageSize))
        let businessesWithImages = await fetchImagesForBusinesses(initialBatch)
        businesses = businessesWithImages
    }
    
    // New Google Places-based search method
    private func searchBusinessesViaGooglePlaces(query: String, near coordinate: CLLocationCoordinate2D, category: String) async throws -> [Business] {
        let radius = Int(maxDistanceMeters) // Convert to meters for Google Places
        let location = "\(coordinate.latitude),\(coordinate.longitude)"
        
        guard let url = URL(string: "\(placesBaseURL)/nearbysearch/json?location=\(location)&radius=\(radius)&keyword=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(googlePlacesAPIKey)") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: nil)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GooglePlacesNearbyResponse.self, from: data)
        
        var businesses: [Business] = []
        
        for place in response.results {
            // Skip if permanently closed
            if place.permanently_closed == true {
                print("Skipping permanently closed: \(place.name)")
                continue
            }
            
            // Skip if no location data
            guard let location = place.geometry?.location else { continue }
            
            // Verify distance (Google's radius isn't always precise)
            let placeLocation = CLLocation(latitude: location.lat, longitude: location.lng)
            let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = placeLocation.distance(from: userLocation)
            
            guard distance <= maxDistanceMeters else { continue }
            
            // Get detailed place information
            let placeDetails = await getPlaceDetails(placeId: place.place_id)
            
            // Skip if detailed check shows it's closed
            if placeDetails?.permanently_closed == true {
                print("Skipping permanently closed (from details): \(place.name)")
                continue
            }
            
            // Create business object with rich Google Places data
            var externalIds = BusinessExternalIds()
            externalIds.addGooglePlaceId(place.place_id)

            let business = Business(
                externalIds: externalIds,
                name: place.name,
                address: placeDetails?.formatted_address ?? place.vicinity,
                coordinate: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng),
                category: category,
                rating: place.rating,
                reviewCount: place.user_ratings_total,
                imageURL: nil, // Will be populated later
                phoneNumber: placeDetails?.formatted_phone_number,
                website: placeDetails?.website
            )
            
            businesses.append(business)
        }
        
        return businesses
    }
    
    // Legacy MapKit search method (kept as fallback)
    private func searchBusinessesForQuery(query: String, near coordinate: CLLocationCoordinate2D, category: String) async throws -> [Business] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035) // ~2km radius - much more focused
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        let businesses = response.mapItems.compactMap { item -> Business? in
            guard let placemark = item.placemark.location?.coordinate else { return nil }

            // Strict distance filtering - must be within 5km (3.1 miles)
            let businessLocation = CLLocation(latitude: placemark.latitude, longitude: placemark.longitude)
            let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = businessLocation.distance(from: userLocation)

            // Filter out businesses too far away
            guard distance <= self.maxDistanceMeters else { return nil }

            // Filter out permanently closed businesses
            let businessName = (item.name ?? "").lowercased()
            let closureKeywords = ["permanently closed", "closed permanently", "permanently close", "closed", "former", "old", "out of business", "defunct", "shuttered", "no longer", "moved out"]
            let isClosed = closureKeywords.contains { keyword in
                businessName.contains(keyword)
            }
            guard !isClosed else { return nil }

            // Filter out generic or low-quality names
            let invalidKeywords = ["untitled", "no name", "unknown", "temp", "temporary"]
            let isInvalid = invalidKeywords.contains { keyword in
                businessName.contains(keyword)
            }
            guard !isInvalid else { return nil }

            // Require website - filter out businesses without websites (if enabled)
            if self.requireWebsite {
                guard let website = item.url?.absoluteString, !website.isEmpty else { return nil }
            }

            // Format address
            var addressComponents: [String] = []
            if let thoroughfare = item.placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            if let locality = item.placemark.locality {
                addressComponents.append(locality)
            }
            if let administrativeArea = item.placemark.administrativeArea {
                addressComponents.append(administrativeArea)
            }
            let address = addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")

            return Business(
                name: item.name ?? "Unknown Business",
                address: address,
                coordinate: placemark,
                category: category,
                rating: nil, // MapKit doesn't provide ratings
                reviewCount: nil,
                imageURL: nil,
                phoneNumber: item.phoneNumber,
                website: item.url?.absoluteString
            )
        }

        return await enrichBusinessesWithGooglePlaceIds(businesses)
    }

    private func enrichBusinessesWithGooglePlaceIds(_ businesses: [Business]) async -> [Business] {
        guard !businesses.isEmpty else { return businesses }

        var enriched: [Business] = []
        enriched.reserveCapacity(businesses.count)

        for business in businesses {
            if business.googlePlaceId != nil {
                enriched.append(business)
                continue
            }

            if let resolvedPlaceId = await findPlaceId(for: business) {
                var externalIds = business.externalIds
                externalIds.addGooglePlaceId(resolvedPlaceId)
                let updatedBusiness = business.updating(womId: business.womId, externalIds: externalIds)
                enriched.append(updatedBusiness)
            } else {
                enriched.append(business)
            }
        }

        return enriched
    }

    private func removeDuplicatesAdvanced(from businesses: [Business]) -> [Business] {
        var uniqueBusinesses: [Business] = []
        var addressGroups: [String: [Business]] = [:]
        
        // Group businesses by normalized address
        for business in businesses {
            let normalizedAddress = normalizeAddress(business.address)
            if addressGroups[normalizedAddress] == nil {
                addressGroups[normalizedAddress] = []
            }
            addressGroups[normalizedAddress]?.append(business)
        }
        
        // Process each address group
        for (_, businessGroup) in addressGroups {
            if businessGroup.count == 1 {
                // Only one business at this address, add it
                uniqueBusinesses.append(businessGroup[0])
            } else {
                // Multiple businesses at same address, pick the most recent/relevant one
                let bestBusiness = selectBestBusiness(from: businessGroup)
                uniqueBusinesses.append(bestBusiness)
            }
        }
        
        // Additional name-based deduplication for businesses without addresses
        let finalBusinesses = removeNameDuplicates(from: uniqueBusinesses)
        
        return finalBusinesses
    }
    
    private func normalizeAddress(_ address: String?) -> String {
        guard let address = address else { return "no_address_\(UUID().uuidString)" }
        
        // Normalize address by removing common variations
        var normalized = address.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove suite/unit numbers that might change
        normalized = normalized.replacingOccurrences(of: #"\s*(suite|ste|unit|apt|#)\s*\d+.*"#, with: "", options: .regularExpression)
        
        // Normalize street abbreviations
        let streetAbbreviations = [
            ("street", "st"), ("avenue", "ave"), ("boulevard", "blvd"),
            ("drive", "dr"), ("lane", "ln"), ("road", "rd"),
            ("place", "pl"), ("court", "ct"), ("circle", "cir")
        ]
        
        for (full, abbrev) in streetAbbreviations {
            normalized = normalized.replacingOccurrences(of: " \(full)", with: " \(abbrev)")
            normalized = normalized.replacingOccurrences(of: " \(abbrev)", with: " \(abbrev)")
        }
        
        // Remove extra spaces
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return normalized
    }
    
    private func selectBestBusiness(from businesses: [Business]) -> Business {
        // Prioritize businesses with more complete information
        let scored = businesses.map { business -> (business: Business, score: Int) in
            var score = 0
            
            // Prefer businesses with phone numbers (indicates more recent/complete data)
            if business.phoneNumber != nil { score += 10 }
            
            // Strongly prefer businesses with websites (now required)
            if let website = business.website, !website.isEmpty { 
                score += 15
                
                // Prefer businesses with professional domains
                if website.contains(".com") || website.contains(".org") || website.contains(".net") {
                    score += 3
                }
                
                // Prefer businesses with their own domain (not social media)
                if !website.contains("facebook") && !website.contains("instagram") && !website.contains("yelp") {
                    score += 5
                }
            }
            
            // Prefer businesses with ratings
            if business.rating != nil { score += 3 }
            
            // Prefer longer names (often more descriptive/current)
            score += min(business.name.count / 5, 5)
            
            // Heavily penalize names that look like old/closed businesses
            let name = business.name.lowercased()
            let negativeKeywords = ["closed", "former", "old", "permanently", "out of business", "defunct", "shuttered", "no longer", "moved out"]
            for keyword in negativeKeywords {
                if name.contains(keyword) {
                    score -= 50 // Heavy penalty for closure indicators
                }
            }
            
            // Prefer names with more specific business indicators
            if name.contains("llc") || name.contains("inc") || name.contains("&") {
                score += 2
            }
            
            return (business: business, score: score)
        }
        
        // Return the highest scored business
        return scored.max(by: { $0.score < $1.score })?.business ?? businesses[0]
    }
    
    private func removeNameDuplicates(from businesses: [Business]) -> [Business] {
        var uniqueBusinesses: [Business] = []
        var processedNames: Set<String> = []
        
        for business in businesses {
            let normalizedName = business.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if we've already processed a business with similar name
            let isDuplicate = processedNames.contains { existingName in
                // Check for exact match or if names are very similar
                return existingName == normalizedName || 
                       normalizedName.contains(existingName) || 
                       existingName.contains(normalizedName)
            }
            
            if !isDuplicate {
                // Also check for location proximity (within 100 meters)
                let isLocationDuplicate = uniqueBusinesses.contains { existingBusiness in
                    let distance = CLLocation(latitude: business.coordinate.latitude, longitude: business.coordinate.longitude)
                        .distance(from: CLLocation(latitude: existingBusiness.coordinate.latitude, longitude: existingBusiness.coordinate.longitude))
                    
                    let existingName = existingBusiness.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let isSimilarName = normalizedName == existingName || 
                                       normalizedName.contains(existingName) || 
                                       existingName.contains(normalizedName)
                    
                    return distance < 100 && isSimilarName
                }
                
                if !isLocationDuplicate {
                    uniqueBusinesses.append(business)
                    processedNames.insert(normalizedName)
                }
            }
        }
        
        return uniqueBusinesses
    }
    
    // MARK: - Image Fetching
    
    private func fetchImagesForBusinesses(_ businesses: [Business]) async -> [Business] {
        // Process businesses in batches to avoid overwhelming the API
        let batchSize = 10
        var updatedBusinesses: [Business] = []
        
        for i in stride(from: 0, to: businesses.count, by: batchSize) {
            let endIndex = min(i + batchSize, businesses.count)
            let batch = Array(businesses[i..<endIndex])
            
            // Fetch images for this batch concurrently
            let batchResults = await withTaskGroup(of: Business.self) { group in
                for business in batch {
                    group.addTask {
                        await self.fetchImageForBusiness(business)
                    }
                }
                
                var results: [Business] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            updatedBusinesses.append(contentsOf: batchResults)
            
            // Small delay between batches to be respectful to the API
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return updatedBusinesses
    }
    
    private func fetchImageForBusiness(_ business: Business) async -> Business {
        // Try different image sources in order of preference
        
        // 1. Try Google Places API (most reliable)
        if let imageURL = await fetchGooglePlacesImage(for: business) {
            return business.updating(imageURL: imageURL)
        }
        
        // 2. Try generating a placeholder image URL
        let placeholderURL = generatePlaceholderImageURL(for: business)
        
        return business.updating(imageURL: placeholderURL)
    }
    
    private func fetchGooglePlacesImage(for business: Business) async -> URL? {
        // Skip if no API key configured
        guard googlePlacesAPIKey != "YOUR_GOOGLE_PLACES_API_KEY" else {
            return nil
        }
        
        // Step 1: Find place using Nearby Search
        let placeId = await findPlaceId(for: business)
        
        guard let placeId = placeId else {
            return nil
        }
        
        // Step 2: Get place details with photo reference
        let photoReference = await getPhotoReference(for: placeId)
        
        guard let photoReference = photoReference else {
            return nil
        }
        
        // Step 3: Generate photo URL
        let photoURL = "\(placesBaseURL)/photo?maxwidth=400&photo_reference=\(photoReference)&key=\(googlePlacesAPIKey)"
        return URL(string: photoURL)
    }
    
    private func findPlaceId(for business: Business) async -> String? {
        let urlString = "\(placesBaseURL)/nearbysearch/json?location=\(business.coordinate.latitude),\(business.coordinate.longitude)&radius=50&name=\(business.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(googlePlacesAPIKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            return response.results.first?.place_id
        } catch {
            print("Error finding place ID: \(error)")
            return nil
        }
    }
    
    private func getPhotoReference(for placeId: String) async -> String? {
        let urlString = "\(placesBaseURL)/details/json?place_id=\(placeId)&fields=photos&key=\(googlePlacesAPIKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
            return response.result?.photos?.first?.photo_reference
        } catch {
            print("Error getting photo reference: \(error)")
            return nil
        }
    }
    
    private func generatePlaceholderImageURL(for business: Business) -> URL? {
        // Generate a deterministic placeholder image based on business name
        let businessNameHash = business.name.data(using: .utf8)?.sha256 ?? ""
        let colorIndex = abs(businessNameHash.hashValue) % 6
        
        let colors = ["FF6B6B", "4ECDC4", "45B7D1", "96CEB4", "FFEAA7", "DDA0DD"]
        let color = colors[colorIndex]
        
        // Using a placeholder service that generates images based on text and color
        let encodedName = business.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Business"
        let urlString = "https://via.placeholder.com/400x300/\(color)/FFFFFF?text=\(encodedName)"
        
        return URL(string: urlString)
    }
}

// MARK: - Google Places API Models

// Nearby Search Response
struct GooglePlacesNearbyResponse: Codable {
    let results: [GooglePlaceNearby]
    let status: String
}

struct GooglePlaceNearby: Codable {
    let place_id: String
    let name: String
    let vicinity: String?
    let geometry: GoogleGeometry?
    let rating: Double?
    let user_ratings_total: Int?
    let permanently_closed: Bool?
    let business_status: String?
    let price_level: Int?
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

// Place Details Response
struct GooglePlaceDetailsResponse: Codable {
    let result: GooglePlaceDetails?
    let status: String
}

struct GooglePlaceDetails: Codable {
    let name: String?
    let formatted_address: String?
    let formatted_phone_number: String?
    let website: String?
    let permanently_closed: Bool?
    let business_status: String?
    let opening_hours: GoogleOpeningHours?
    let price_level: Int?
    let rating: Double?
    let user_ratings_total: Int?
    let photos: [GooglePhoto]?
}

struct GoogleOpeningHours: Codable {
    let open_now: Bool?
    let weekday_text: [String]?
}

struct GooglePhoto: Codable {
    let photo_reference: String
    let height: Int
    let width: Int
}

// Legacy Text Search Response (kept for compatibility)
struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
    let status: String
}

struct GooglePlace: Codable {
    let place_id: String
    let name: String
    let geometry: GoogleGeometry
}

// Extension for SHA256 hashing
extension Data {
    var sha256: String {
        let hashed = SHA256.hash(data: self)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
