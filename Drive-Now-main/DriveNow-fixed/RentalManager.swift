import Foundation
import SwiftUI
import FirebaseAuth // CHANGED: for deleting a cancelled booking from Firestore
import FirebaseFirestore

// MARK: - Shared Rental Manager
class RentalManager: ObservableObject {
    static let shared = RentalManager()
    
    @Published var bookings: [CarBooking] = []
    
    private init() {
        loadBookingsForCurrentUser()
    }
    
    private var currentUserKey: String {
        // CHANGED: key the saved data by the Firebase user id instead of the email. The saved email was only
        // updated at sign-up, never at login, so a second account on the device saw the first account's data.
        let currentUserID = UserProfileManager.shared.currentUserID
        if !currentUserID.isEmpty {
            return "RentalBookings_\(currentUserID)"
        }
        return "RentalBookings_default"
    }
    
    private func loadBookingsForCurrentUser() {
        if let data = UserDefaults.standard.data(forKey: currentUserKey),
           let decodedBookings = try? JSONDecoder().decode([CarBooking].self, from: data) {
            self.bookings = decodedBookings
        } else {
            self.bookings = []
        }
    }
    
    private func saveBookings() {
        if let encoded = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(encoded, forKey: currentUserKey)
        }
    }
    
    // CHANGED: now returns the booking it created, so BookingScreen can use its id as the Firestore document id
    // (with an auto-generated Firestore id there was no way to find and delete the document on cancel).
    @discardableResult
    func addBooking(car: Car, pickUpDate: Date, returnDate: Date, location: String) -> CarBooking {
        let booking = CarBooking(
            carName: car.name,
            imageName: car.imageName,
            pricePerDay: car.pricePerDay,
            pickUpDate: pickUpDate,
            returnDate: returnDate,
            location: location,
            createdAt: Date()
        )
        bookings.append(booking)
        saveBookings()
        return booking
    }
    
    func cancelBooking(_ booking: CarBooking) {
        bookings.removeAll { $0.id == booking.id }
        saveBookings()
        deleteBookingFromFirestore(booking) // CHANGED: cancelling only removed it from the phone before
    }
    
    // CHANGED: new. A cancelled booking stayed in Firestore forever (and kept showing in UserDataMonitor).
    private func deleteBookingFromFirestore(_ booking: CarBooking) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(userId)
            .collection("bookings").document(booking.id.uuidString).delete { error in
                if let error = error {
                    print("Error deleting booking from Firestore: \(error.localizedDescription)")
                }
            }
    }

    // Reload bookings for current user (useful when switching accounts)
    func reloadBookingsForCurrentUser() {
        loadBookingsForCurrentUser()
    }
    
    // Clear all bookings for current user
    func clearBookings() {
        bookings = []
        saveBookings()
    }
    
    // Admin function: Get bookings for a specific user
    func getBookingsForUser(userID: String) -> [CarBooking] {
        let key = "RentalBookings_\(userID)" // CHANGED: keys use the user id now
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedBookings = try? JSONDecoder().decode([CarBooking].self, from: data) {
            return decodedBookings
        }
        return []
    }
    
    // Get upcoming bookings
    func getUpcomingBookings() -> [CarBooking] {
        return bookings.filter { $0.getBookingStatus() == "Upcoming" }
    }
    
    // Get active bookings
    func getActiveBookings() -> [CarBooking] {
        return bookings.filter { $0.getBookingStatus() == "Active" }
    }
    
    // Get completed bookings
    func getCompletedBookings() -> [CarBooking] {
        return bookings.filter { $0.getBookingStatus() == "Completed" }
    }
}
