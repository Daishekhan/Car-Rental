import Foundation
import SwiftUI
import FirebaseCore // CHANGED: for FirebaseApp
import FirebaseAuth // CHANGED: for the user id used in the per-user keys

// MARK: - Shared User Profile Manager
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var fullName: String = "" { // CHANGED: no hardcoded personal defaults (every new user used to see them)
        didSet {
            UserDefaults.standard.set(fullName, forKey: "userFullName")
        }
    }
    
    @Published var email: String = "" { // CHANGED: no hardcoded personal defaults
        didSet {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }
    }
    
    @Published var phoneNumber: String = "" {
        didSet {
            UserDefaults.standard.set(phoneNumber, forKey: userKey("userPhoneNumber"))
        }
    }
    
    @Published var licenseInfo: String = "" {
        didSet {
            UserDefaults.standard.set(licenseInfo, forKey: userKey("userLicenseInfo"))
        }
    }
    
    @Published var joinedDate: String = "" { // CHANGED: no hardcoded default
        didSet {
            UserDefaults.standard.set(joinedDate, forKey: "userJoinedDate")
        }
    }

    // CHANGED: removed `currentUserPassword`. It stored the password in plain text in UserDefaults,
    // and nothing used it (Firebase already handles passwords). init() below also wipes any old copy.

    // CHANGED: the Firebase user id ("" when nobody is logged in, or Firebase isn't configured e.g. in previews).
    // The managers use this to name their saved data, because an id never changes (an email can).
ç
    
    var currentUserEmail: String {
        get {
            return UserDefaults.standard.string(forKey: "savedEmail") ?? ""
        }
    }
    
    private init() {
        // CHANGED: delete any plain-text password saved by older versions of the app
        UserDefaults.standard.removeObject(forKey: "savedPassword")
        loadUserData()
    }

    // CHANGED: phone number and license were saved under ONE shared key, so every account on the
    // device shared them. This adds the user id to the key so each account has its own.
    private func userKey(_ base: String) -> String {
        let id = currentUserID
        return "\(base)_\(id.isEmpty ? "guest" : id)"
    }
    
    private func loadUserData() {
        // Load data from the currently logged-in user's saved information
        let savedEmail = UserDefaults.standard.string(forKey: "savedEmail") ?? ""
        let savedFullName = UserDefaults.standard.string(forKey: "savedFullName") ?? ""
        let savedJoinedDate = UserDefaults.standard.string(forKey: "savedJoinedDate") ?? ""
        
        // Update the published properties with the actual logged-in user's data
        if !savedEmail.isEmpty {
            email = savedEmail
        }
        if !savedFullName.isEmpty {
            fullName = savedFullName
        }
        if !savedJoinedDate.isEmpty {
            joinedDate = savedJoinedDate
        }
        
        // Load other profile data or default to blank for new accounts
        phoneNumber = UserDefaults.standard.string(forKey: userKey("userPhoneNumber")) ?? ""
        licenseInfo = UserDefaults.standard.string(forKey: userKey("userLicenseInfo")) ?? ""
    }
    
    // Add a function to update user data when user logs in
    func loadCurrentUserData() {
        loadUserData()
    }
    
    func updateFullName(_ newName: String) {
        fullName = newName
    }
    
    func updateEmail(_ newEmail: String) {
        email = newEmail
    }
    
    func updatePhoneNumber(_ newPhone: String) {
        phoneNumber = newPhone
    }
    
    func updateLicenseInfo(_ newLicense: String) {
        licenseInfo = newLicense
    }
    
    func updateJoinedDate(_ newDate: String) {
        joinedDate = newDate
    }
    
    // MARK: - Settings Save Functions
    func saveProfileSettingsToLogin() {
        // Update the login credentials with the new profile information
        // This ensures that when the user logs in next time, the updated info is reflected
        UserDefaults.standard.set(email, forKey: "savedEmail")
        UserDefaults.standard.set(fullName, forKey: "savedFullName")
        
        // Also update the user profile keys including phone number and license info
        UserDefaults.standard.set(fullName, forKey: "userFullName")
        UserDefaults.standard.set(email, forKey: "userEmail")
        UserDefaults.standard.set(phoneNumber, forKey: userKey("userPhoneNumber"))
        UserDefaults.standard.set(licenseInfo, forKey: userKey("userLicenseInfo"))
    }
    
    // MARK: - Account Deletion Functions
    // CHANGED: takes the uid as a parameter. AccountSettingsScreen now deletes the server account FIRST,
    // and after that Firebase no longer knows who the user was, so the caller passes the uid in.
    func deleteAccount(forUID uid: String) {
        let uidForCleanup = uid
        
        // Clear all user-specific data from the managers BEFORE clearing profile data
        if !uidForCleanup.isEmpty {
            // Clear favorites for this specific user
            let favoritesKey = "FavoriteCars_\(uidForCleanup)"
            UserDefaults.standard.removeObject(forKey: favoritesKey)
            
            // Clear purchase history for this specific user
            let purchaseHistoryKey = "PurchaseHistory_\(uidForCleanup)"
            UserDefaults.standard.removeObject(forKey: purchaseHistoryKey)
            
            // Clear rental bookings for this specific user
            let rentalBookingsKey = "RentalBookings_\(uidForCleanup)"
            UserDefaults.standard.removeObject(forKey: rentalBookingsKey)
        }
        
        // Clear all user profile data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedEmail")
        UserDefaults.standard.removeObject(forKey: "savedPassword")
        UserDefaults.standard.removeObject(forKey: "savedFullName")
        UserDefaults.standard.removeObject(forKey: "savedJoinedDate")
        UserDefaults.standard.removeObject(forKey: "userFullName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userPhoneNumber_\(uid)")
        UserDefaults.standard.removeObject(forKey: "userLicenseInfo_\(uid)")
        UserDefaults.standard.removeObject(forKey: "userJoinedDate")
        UserDefaults.standard.removeObject(forKey: "profileImage_\(uid)")
        UserDefaults.standard.removeObject(forKey: "hasCustomProfileImage_\(uid)")
        
        // Reset the published properties to default values
        fullName = ""
        email = ""
        phoneNumber = ""
        licenseInfo = ""
        joinedDate = ""
        
        // Clear the managers' in-memory data immediately
        DispatchQueue.main.async {
            FavoritesManager.shared.reloadFavoritesForCurrentUser()
            PurchaseHistoryManager.shared.reloadPurchaseHistoryForCurrentUser()
            RentalManager.shared.reloadBookingsForCurrentUser()
        }
    }
    
    // MARK: - Password Management Functions
    // Note: Firebase Authentication handles actual password storage and validation.
    // These methods are kept for backwards compatibility but should not be used for real authentication.
    
    // CHANGED: removed validateCurrentPassword(_:) and updatePassword(_:). They compared/saved the password in
    // plain text in UserDefaults and nothing called them. Firebase checks passwords for you.
    
    /// Validates password strength requirements
    /// - Parameter password: The password to validate
    /// - Returns: true if password meets all requirements (8+ chars, uppercase, lowercase, number)
    func isValidPassword(_ password: String) -> Bool {
        let hasMinimumLength = password.count >= 8
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        
        return hasMinimumLength && hasUppercase && hasLowercase && hasNumbers
    }
}
