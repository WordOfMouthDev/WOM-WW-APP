import Foundation

struct Service: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: ServiceCategory
    
    enum ServiceCategory: String, Codable, CaseIterable {
        case beauty = "Beauty"
        case fitness = "Fitness"
        case wellness = "Wellness"
    }
    
    // Predefined services matching your design
    static let allServices: [Service] = [
        // Beauty Services
        Service(id: "hair_salon", name: "Hair Salon", category: .beauty),
        Service(id: "nail_salon", name: "Nail Salon", category: .beauty),
        Service(id: "spa_massage", name: "Spa/Massage", category: .beauty),
        Service(id: "lashes", name: "Lashes", category: .beauty),
        Service(id: "brows", name: "Brows", category: .beauty),
        Service(id: "skincare_facials", name: "Skincare/Facials", category: .beauty),
        Service(id: "spray_tan", name: "Spray Tan", category: .beauty),
        Service(id: "waxing_sugaring", name: "Waxing/Sugaring", category: .beauty),
        Service(id: "med_spa", name: "Med Spa (Botox/Fillers)", category: .beauty),
        
        // Fitness Services
        Service(id: "gym", name: "Gym", category: .fitness),
        Service(id: "yoga_studio", name: "Yoga Studio", category: .fitness),
        Service(id: "pilates_studio", name: "Pilates Studio", category: .fitness),
        Service(id: "barre", name: "Barre", category: .fitness),
        Service(id: "cycling_spin", name: "Cycling/Spin", category: .fitness),
        Service(id: "boxing_kickboxing", name: "Boxing/Kickboxing", category: .fitness),
        
        // Wellness Services
        Service(id: "acupuncture", name: "Acupuncture", category: .wellness),
        Service(id: "chiropractor", name: "Chiropractor", category: .wellness),
        Service(id: "physical_therapy", name: "Physical Therapy", category: .wellness)
    ]
    
    static func service(withId id: String) -> Service? {
        return allServices.first { $0.id == id }
    }
}
