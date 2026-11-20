import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Purchase History Model
struct PurchaseHistoryItem: Identifiable, Codable {
    let id: UUID
    let paymentMethod: String
    let date: Date
    let carName: String
    let totalAmount: String
    let transactionID: String
    
    // CHANGED: the id can now be passed in (default = new one) so an item loaded from Firestore keeps its saved id
    init(id: UUID = UUID(), paymentMethod: String, date: Date, carName: String, totalAmount: String, transactionID: String) {
        self.id = id
        self.paymentMethod = paymentMethod
        self.date = date
        self.carName = carName
        self.totalAmount = totalAmount
        self.transactionID = transactionID
    }
}

// MARK: - Purchase History Manager
class PurchaseHistoryManager: ObservableObject {
    @Published var purchaseHistory: [PurchaseHistoryItem] = []
    // CHANGED: computed instead of stored, so Firestore.firestore() only runs when it is needed
    // (a stored one crashes previews that run before Firebase is configured)
    private var db: Firestore { Firestore.firestore() }
    
    static let shared = PurchaseHistoryManager()
    
    private init() {
        loadPurchaseHistory()
    }
    
    // Get the current user's unique key for storing purchase history
    private var currentUserKey: String {
        // CHANGED: key the saved data by the Firebase user id instead of the email. The saved email was only
        // updated at sign-up, never at login, so a second account on the device saw the first account's data.
        let currentUserID = UserProfileManager.shared.currentUserID
        if currentUserID.isEmpty {
            // Fallback to a default key if no user is logged in
            return "PurchaseHistory_default"
        }
        return "PurchaseHistory_\(currentUserID)"
    }
    
    // CHANGED: optional transactionID, so the ID shown on the payment success card is the one saved in history
    func addPurchase(paymentMethod: String, carName: String, totalAmount: String, transactionID: String? = nil) {
        let newPurchase = PurchaseHistoryItem(
            paymentMethod: paymentMethod,
            date: Date(),
            carName: carName,
            totalAmount: totalAmount,
            transactionID: transactionID ?? generateTransactionID(for: paymentMethod)
        )
        purchaseHistory.insert(newPurchase, at: 0) // Add to beginning for newest first
        savePurchaseHistory()
        saveToFirestore(newPurchase) // Sync to Firestore
    }
    
    // CHANGED: no longer private, so the payment screens can create the ID they show
    func generateTransactionID(for paymentMethod: String) -> String {
        let prefix = paymentMethod == "Credit Card" ? "CC" : paymentMethod == "GCash" ? "GC" : "CS"
        let randomNumber = Int.random(in: 100000...999999)
        return "\(prefix)\(randomNumber)"
    }
    
    private func savePurchaseHistory() {
        if let encoded = try? JSONEncoder().encode(purchaseHistory) {
            UserDefaults.standard.set(encoded, forKey: currentUserKey)
        }
    }
    
    private func loadPurchaseHistory() {
        if let data = UserDefaults.standard.data(forKey: currentUserKey),
           let decoded = try? JSONDecoder().decode([PurchaseHistoryItem].self, from: data) {
            purchaseHistory = decoded
        } else {
            // Initialize with empty array for new users
            purchaseHistory = []
        }
    }
    
    // Function to reload purchase history when user changes (e.g., login/logout)
    func reloadPurchaseHistoryForCurrentUser() {
        loadPurchaseHistory()
    }
    
    // Function to clear purchase history for current user (useful for account deletion)
    func clearPurchaseHistory() {
        purchaseHistory = []
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }
    
    // Function to get purchase history for a specific user (admin function)
    func getPurchaseHistoryForUser(userID: String) -> [PurchaseHistoryItem] {
        let userKey = "PurchaseHistory_\(userID)" // CHANGED: keys use the user id now
        if let data = UserDefaults.standard.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode([PurchaseHistoryItem].self, from: data) {
            return decoded
        }
        return []
    }
    
    // MARK: - Firestore Sync Methods
    
    /// Save a purchase to Firestore
    private func saveToFirestore(_ purchase: PurchaseHistoryItem) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, skipping Firestore sync")
            return
        }
        
        let purchaseData: [String: Any] = [
            "id": purchase.id.uuidString,
            "paymentMethod": purchase.paymentMethod,
            "date": Timestamp(date: purchase.date),
            "carName": purchase.carName,
            "totalAmount": purchase.totalAmount,
            "transactionID": purchase.transactionID
        ]
        
        db.collection("users").document(userId).collection("purchaseHistory").document(purchase.id.uuidString).setData(purchaseData) { error in
            if let error = error {
                print("Error saving purchase to Firestore: \(error.localizedDescription)")
            } else {
                print("Purchase successfully saved to Firestore")
            }
        }
    }
    
    // Load purchase history from Firestore for current user
    func loadFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, loading from UserDefaults only")
            loadPurchaseHistory()
            return
        }
        
        db.collection("users").document(userId).collection("purchaseHistory")
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading purchase history from Firestore: \(error.localizedDescription)")
                    self?.loadPurchaseHistory() // Fallback to UserDefaults
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No purchase history found in Firestore, loading from UserDefaults")
                    self?.loadPurchaseHistory()
                    return
                }
                
                let purchases = documents.compactMap { doc -> PurchaseHistoryItem? in
                    let data = doc.data()
                    guard let idString = data["id"] as? String,
                          let id = UUID(uuidString: idString), // CHANGED: was commented out, so the saved id was checked and then thrown away
                          let paymentMethod = data["paymentMethod"] as? String,
                          let timestamp = data["date"] as? Timestamp,
                          let carName = data["carName"] as? String,
                          let totalAmount = data["totalAmount"] as? String,
                          let transactionID = data["transactionID"] as? String else {
                        return nil
                    }
                    
                    return PurchaseHistoryItem(
                        id: id, // CHANGED: keep the saved id
                        paymentMethod: paymentMethod,
                        date: timestamp.dateValue(),
                        carName: carName,
                        totalAmount: totalAmount,
                        transactionID: transactionID
                    )
                }
                
                DispatchQueue.main.async {
                    self?.purchaseHistory = purchases
                    self?.savePurchaseHistory() // Save to UserDefaults as backup
                    print("Purchase history loaded from Firestore: \(purchases.count) items")
                }
            }
    }
}
