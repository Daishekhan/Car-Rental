//
//  Car.swift
//  DriveNow
//
//  Created by STUDENT on 10/15/25.
//

import Foundation

class Car: ObservableObject, Identifiable, Codable {
    // CHANGED: this was `let id = UUID()`. That made a brand-new random id every time a Car was
    // created (every launch, every time HomeTab rebuilt, every time favorites were decoded), so
    // isFavorite() and the duplicate check never matched. The name is unique per car, so use it.
    var id: String { name }
    let name: String
    let pricePerDay: String
    let imageName: String
    let rating: Int
    let category: String
    
    // Computed property to get price as Double for calculations
    var priceAsDouble: Double {
        let cleanedPrice = pricePerDay.replacingOccurrences(of: "₱", with: "").replacingOccurrences(of: ",", with: "")
        return Double(cleanedPrice) ?? 0.0
    }
    
    // Computed property to get formatted price
    var formattedPrice: String {
        return pricePerDay
    }
    
    // Computed property to get clamped rating (max 5.0)
    var clampedRating: Double {
        return min(Double(rating), 5.0)
    }
    
    // Computed property to get specifications
    var specifications: CarSpecification {
        return CarSpecification(car: self)
    }
    
    init(name: String, pricePerDay: String, imageName: String, rating: Int, category: String) {
        self.name = name
        self.pricePerDay = pricePerDay
        self.imageName = imageName
        self.rating = rating
        self.category = category
    }
    
    // Method to get star rating as string
    func getStarRating() -> String {
        return String(repeating: "⭐", count: max(0, min(rating, 5))) // CHANGED: a negative count crashes String(repeating:count:)
    }
    
    // Method to check if car belongs to specific category
    func belongsToCategory(_ category: String) -> Bool {
        return self.category.lowercased() == category.lowercased()
    }
    
    // Method to get car details as formatted string
    func getCarDetails() -> String {
        return "\(name) - \(pricePerDay)/day - Rating: \(getStarRating())"
    }
    
    // Method to get detailed car information
    func getDetailedInfo() -> [String: Any] {
        return [
            "id": id, // CHANGED: id is a String now
            "name": name,
            "category": category,
            "price": priceAsDouble,
            "rating": clampedRating,
            "specifications": specifications.getSpecifications()
        ]
    }
    
    // Method to check if car is premium (rating >= 4)
    func isPremium() -> Bool {
        return clampedRating >= 4.0
    }
    
    // Method to get price tier
    func getPriceTier() -> String {
        let price = priceAsDouble
        switch price {
        case 0..<3000:
            return "Budget"
        case 3000..<6000:
            return "Standard"
        case 6000..<10000:
            return "Premium"
        default:
            return "Luxury"
        }
    }
    
    // Method to check if car is available for long-term rental
    func isAvailableForLongTerm() -> Bool {
        // Long-term rentals typically for cars with good ratings
        return clampedRating >= 3.5
    }
}

// MARK: - Equatable conformance for comparison
extension Car: Equatable {
    static func == (lhs: Car, rhs: Car) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable conformance for use in Sets
extension Car: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// CHANGED: Swift's built-in hashValue is randomly seeded every launch, so anything derived from it
// changes each time the app starts. This small hash gives the same number for the same text forever.
extension String {
    var stableSeed: Int {
        unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
    }
}
