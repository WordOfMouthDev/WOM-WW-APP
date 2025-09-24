import Foundation
import CoreLocation

enum PreviewData {
    static let placeVerified = Business(
        womId: "wom-blush-and-barre",
        externalIds: BusinessExternalIds(googlePlaceIds: ["preview-blush"]),
        name: "Blush & Barre Studio",
        address: "123 Market Street, San Francisco, CA",
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        category: "fitness and wellness",
        rating: 4.8,
        reviewCount: 128,
        imageURL: URL(string: "https://source.unsplash.com/featured/?studio"),
        phoneNumber: "+14155552671",
        website: "https://blushbarrestudio.com",
        isVerified: true,
        likeCount: 82,
        dislikeCount: 4
    )

    static let placeUnverified = Business(
        womId: "wom-skin-love",
        externalIds: BusinessExternalIds(googlePlaceIds: ["preview-skinlove"]),
        name: "Skin Love Beauty & Body Bar",
        address: "Atlantic Highlands, NJ 07716",
        coordinate: CLLocationCoordinate2D(latitude: 40.4070, longitude: -74.0365),
        category: "skincare",
        rating: nil,
        reviewCount: nil,
        imageURL: URL(string: "https://source.unsplash.com/featured/?spa"),
        phoneNumber: "+17327735542",
        website: "skinlovebeautybar.com",
        isVerified: false,
        likeCount: 23,
        dislikeCount: 5
    )
}
