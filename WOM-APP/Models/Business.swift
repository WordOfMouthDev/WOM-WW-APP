import Foundation
import CoreLocation

struct Business: Identifiable, Codable {
    let womId: String
    let externalIds: BusinessExternalIds
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let category: String
    let rating: Double?
    let reviewCount: Int?
    let imageURL: URL?
    let phoneNumber: String?
    let website: String?
    let isVerified: Bool
    let likeCount: Int
    let dislikeCount: Int

    var id: String { womId }
    var googlePlaceId: String? { externalIds.currentGooglePlaceId }

    init(
        womId: String = Business.makeWomIdentifier(),
        externalIds: BusinessExternalIds = .init(),
        name: String,
        address: String?,
        coordinate: CLLocationCoordinate2D,
        category: String,
        rating: Double? = nil,
        reviewCount: Int? = nil,
        imageURL: URL? = nil,
        phoneNumber: String? = nil,
        website: String? = nil,
        isVerified: Bool = false,
        likeCount: Int = 0,
        dislikeCount: Int = 0
    ) {
        self.womId = womId
        self.externalIds = externalIds
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.category = category
        self.rating = rating
        self.reviewCount = reviewCount
        self.imageURL = imageURL
        self.phoneNumber = phoneNumber
        self.website = website
        self.isVerified = isVerified
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
    }

    // Custom coding to handle CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case womId, externalIds, name, address, category, rating, reviewCount, imageURL, phoneNumber, website, isVerified, likeCount, dislikeCount
        case latitude, longitude
        case legacyId = "id"
        case legacyGooglePlaceId = "googlePlaceId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backwards compatibility: fall back to "id" if "womId" is missing.
        if let womId = try container.decodeIfPresent(String.self, forKey: .womId) {
            self.womId = womId
        } else if let legacyId = try container.decodeIfPresent(String.self, forKey: .legacyId) {
            self.womId = legacyId
        } else {
            self.womId = Business.makeWomIdentifier()
        }

        if let externalIds = try container.decodeIfPresent(BusinessExternalIds.self, forKey: .externalIds) {
            self.externalIds = externalIds
        } else {
            var ids = BusinessExternalIds()
            if let legacyGooglePlaceId = try container.decodeIfPresent(String.self, forKey: .legacyGooglePlaceId) {
                ids.addGooglePlaceId(legacyGooglePlaceId)
            }
            self.externalIds = ids
        }

        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        category = try container.decode(String.self, forKey: .category)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        dislikeCount = try container.decodeIfPresent(Int.self, forKey: .dislikeCount) ?? 0

        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(womId, forKey: .womId)
        try container.encode(externalIds, forKey: .externalIds)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(reviewCount, forKey: .reviewCount)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(dislikeCount, forKey: .dislikeCount)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "womId": womId,
            "id": womId,
            "name": name,
            "category": category,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]

        if let address = address { dict["address"] = address }
        if let rating = rating { dict["rating"] = rating }
        if let reviewCount = reviewCount { dict["reviewCount"] = reviewCount }
        if let imageURL = imageURL { dict["imageURL"] = imageURL.absoluteString }
        if let phoneNumber = phoneNumber { dict["phoneNumber"] = phoneNumber }
        if let website = website { dict["website"] = website }
        dict["isVerified"] = isVerified
        dict["likeCount"] = likeCount
        dict["dislikeCount"] = dislikeCount

        let externalIdsDict = externalIds.toDictionary()
        if !externalIdsDict.isEmpty {
            dict["externalIds"] = externalIdsDict
        }

        if let legacyGooglePlaceId = googlePlaceId {
            dict["googlePlaceId"] = legacyGooglePlaceId
        }

        return dict
    }

    static func fromDictionary(_ dict: [String: Any]) -> Business? {
        let womId = dict["womId"] as? String ?? dict["id"] as? String ?? Business.makeWomIdentifier()

        guard let name = dict["name"] as? String,
              let category = dict["category"] as? String,
              let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let address = dict["address"] as? String
        let rating = dict["rating"] as? Double
        let reviewCount = dict["reviewCount"] as? Int
        let phoneNumber = dict["phoneNumber"] as? String
        let website = dict["website"] as? String
        let isVerified = dict["isVerified"] as? Bool ?? false
        let likeCount = dict["likeCount"] as? Int ?? 0
        let dislikeCount = dict["dislikeCount"] as? Int ?? 0

        var imageURL: URL?
        if let imageURLString = dict["imageURL"] as? String {
            imageURL = URL(string: imageURLString)
        }

        let externalIds = BusinessExternalIds.fromDictionary(dict["externalIds"] as? [String: Any], fallbackGooglePlaceId: dict["googlePlaceId"] as? String)

        return Business(
            womId: womId,
            externalIds: externalIds,
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            phoneNumber: phoneNumber,
            website: website,
            isVerified: isVerified,
            likeCount: likeCount,
            dislikeCount: dislikeCount
        )
    }

    func updating(womId: String, externalIds: BusinessExternalIds? = nil) -> Business {
        Business(
            womId: womId,
            externalIds: externalIds ?? self.externalIds,
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            phoneNumber: phoneNumber,
            website: website,
            isVerified: isVerified,
            likeCount: likeCount,
            dislikeCount: dislikeCount
        )
    }

    func updating(imageURL: URL?) -> Business {
        Business(
            womId: womId,
            externalIds: externalIds,
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            phoneNumber: phoneNumber,
            website: website,
            isVerified: isVerified,
            likeCount: likeCount,
            dislikeCount: dislikeCount
        )
    }

    func updating(isVerified: Bool) -> Business {
        Business(
            womId: womId,
            externalIds: externalIds,
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            phoneNumber: phoneNumber,
            website: website,
            isVerified: isVerified,
            likeCount: likeCount,
            dislikeCount: dislikeCount
        )
    }

    func updatingFeedbackCounts(likeCount: Int, dislikeCount: Int) -> Business {
        Business(
            womId: womId,
            externalIds: externalIds,
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            phoneNumber: phoneNumber,
            website: website,
            isVerified: isVerified,
            likeCount: likeCount,
            dislikeCount: dislikeCount
        )
    }

    static func makeWomIdentifier() -> String {
        UUID().uuidString
    }
}

struct BusinessExternalIds: Codable {
    private enum CodingKeys: String, CodingKey {
        case googlePlaceIds
        case yelpBusinessIds
        case phoneNumbers
        case websiteHosts
    }

    private(set) var googlePlaceIds: [String]
    private(set) var yelpBusinessIds: [String]
    private(set) var phoneNumbers: [String]
    private(set) var websiteHosts: [String]

    init(
        googlePlaceIds: [String] = [],
        yelpBusinessIds: [String] = [],
        phoneNumbers: [String] = [],
        websiteHosts: [String] = []
    ) {
        self.googlePlaceIds = googlePlaceIds
        self.yelpBusinessIds = yelpBusinessIds
        self.phoneNumbers = phoneNumbers
        self.websiteHosts = websiteHosts
    }

    var currentGooglePlaceId: String? { googlePlaceIds.last }

    mutating func addGooglePlaceId(_ placeId: String) {
        guard !placeId.isEmpty else { return }
        if !googlePlaceIds.contains(placeId) {
            googlePlaceIds.append(placeId)
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if !googlePlaceIds.isEmpty { dict["googlePlaceIds"] = googlePlaceIds }
        if !yelpBusinessIds.isEmpty { dict["yelpBusinessIds"] = yelpBusinessIds }
        if !phoneNumbers.isEmpty { dict["phoneNumbers"] = phoneNumbers }
        if !websiteHosts.isEmpty { dict["websiteHosts"] = websiteHosts }
        return dict
    }

    static func fromDictionary(_ dict: [String: Any]?, fallbackGooglePlaceId: String?) -> BusinessExternalIds {
        guard let dict = dict else {
            if let fallbackGooglePlaceId {
                return BusinessExternalIds(googlePlaceIds: [fallbackGooglePlaceId])
            }
            return BusinessExternalIds()
        }

        let googlePlaceIds = dict["googlePlaceIds"] as? [String] ?? (fallbackGooglePlaceId.map { [$0] } ?? [])
        let yelpBusinessIds = dict["yelpBusinessIds"] as? [String] ?? []
        let phoneNumbers = dict["phoneNumbers"] as? [String] ?? []
        let websiteHosts = dict["websiteHosts"] as? [String] ?? []

        return BusinessExternalIds(
            googlePlaceIds: googlePlaceIds,
            yelpBusinessIds: yelpBusinessIds,
            phoneNumbers: phoneNumbers,
            websiteHosts: websiteHosts
        )
    }
}

struct BusinessCategory {
    let slug: String
    let label: String
    let queries: [String]
    
    func matchesService(_ serviceName: String) -> Bool {
        let lowercaseService = serviceName.lowercased()
        let lowercaseLabel = label.lowercased()
        
        // Check if service name contains any part of the category label
        return lowercaseLabel.contains(lowercaseService) || 
               lowercaseService.contains(lowercaseLabel) ||
               queries.contains { query in
                   lowercaseService.contains(query.lowercased()) ||
                   query.lowercased().contains(lowercaseService)
               }
    }
    
    static let allCategories: [BusinessCategory] = [
        BusinessCategory(slug: "hair-salon", label: "Hair Salon", queries: ["hair salon", "haircut", "blowout", "hair color"]),
        BusinessCategory(slug: "nail-salon", label: "Nail Salon", queries: ["nail salon", "manicure", "pedicure", "gel nails"]),
        BusinessCategory(slug: "spa", label: "Spa/Massage", queries: ["spa", "massage", "lymphatic massage", "prenatal massage"]),
        BusinessCategory(slug: "lashes", label: "Lashes", queries: ["eyelash extensions", "lash lift", "lash tint"]),
        BusinessCategory(slug: "brows", label: "Brows", queries: ["brow bar", "brow lamination", "brow tint", "threading"]),
        BusinessCategory(slug: "skincare", label: "Skincare/Facials", queries: ["facial", "hydrafacial", "dermaplaning", "skin care clinic"]),
        BusinessCategory(slug: "med-spa", label: "Med Spa (Botox/Fillers)", queries: ["med spa", "botox", "filler", "microneedling", "laser"]),
        BusinessCategory(slug: "waxing", label: "Waxing/Sugaring", queries: ["waxing", "sugaring", "bikini wax", "brow wax"]),
        BusinessCategory(slug: "spray-tan", label: "Spray Tan", queries: ["spray tan", "airbrush tan"]),
        BusinessCategory(slug: "gym", label: "Gym", queries: ["gym", "fitness center"]),
        BusinessCategory(slug: "yoga", label: "Yoga Studio", queries: ["yoga studio", "hot yoga", "vinyasa"]),
        BusinessCategory(slug: "pilates", label: "Pilates Studio", queries: ["pilates studio", "reformer pilates", "megaformer"]),
        BusinessCategory(slug: "barre", label: "Barre", queries: ["barre studio", "barre class"]),
        BusinessCategory(slug: "spin", label: "Cycling/Spin", queries: ["spin studio", "indoor cycling"]),
        BusinessCategory(slug: "boxing", label: "Boxing/Kickboxing", queries: ["boxing gym", "kickboxing class", "muay thai"]),
        BusinessCategory(slug: "chiro", label: "Chiropractor", queries: ["chiropractor", "chiropractic clinic"]),
        BusinessCategory(slug: "acupuncture", label: "Acupuncture", queries: ["acupuncture", "acupuncturist"]),
        BusinessCategory(slug: "pt", label: "Physical Therapy", queries: ["physical therapy", "pelvic floor physical therapy"])
    ]
}
