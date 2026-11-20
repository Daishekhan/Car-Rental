import Foundation
@preconcurrency import FirebaseAuth
import Firebase
import Combine
import FirebaseFirestore // CHANGED: needed to delete the user's data on account deletion

final class AuthViewModel: ObservableObject, @unchecked Sendable {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Only attach listener if Firebase configured
        if FirebaseApp.app() != nil {
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
                DispatchQueue.main.async {
                    self?.currentUser = user
                    self?.isAuthenticated = (user != nil)
                }
            }
        } else {
            // For preview/development when Firebase not configured
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // Async sign in using Firebase
    func signIn(email: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                DispatchQueue.main.async {
                    self?.currentUser = result?.user
                    self?.isAuthenticated = result?.user != nil
                }
                continuation.resume(returning: ())
            }
        }
    }

    // Async sign up using Firebase
    func signUp(fullName: String, email: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    // Log detailed error information
                    print("Firebase sign-up error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                // Optionally set display name
                if let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
                    changeRequest.displayName = fullName
                    changeRequest.commitChanges { _ in
                        DispatchQueue.main.async {
                            self?.currentUser = Auth.auth().currentUser
                            self?.isAuthenticated = Auth.auth().currentUser != nil
                        }
                        continuation.resume(returning: ())
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.currentUser = result?.user
                        self?.isAuthenticated = result?.user != nil
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }
        
    // Sign out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isAuthenticated = false
                // Notify the app to present the LoginSignUpScreen after sign out.
                // ContentView listens for "AccountDeleted" and will show LoginSignUpScreen.
                NotificationCenter.default.post(name: NSNotification.Name("AccountDeleted"), object: nil)
            }
        } catch {
            throw error
        }
    }

    // Delete account (calls Firebase delete)
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user"])
        }
        // CHANGED: delete the user's Firestore data FIRST, while they are still signed in (your security rules need that).
        // Deleting a Firebase user does NOT delete their data, so it was left behind forever.
        try await deleteUserFirestoreData(uid: user.uid)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
                continuation.resume(returning: ())
            }
        }
    }

    // CHANGED: new helpers. Firestore does not delete sub-collections for you, so delete each one yourself.
    private func deleteUserFirestoreData(uid: String) async throws {
        let userDoc = Firestore.firestore().collection("users").document(uid)
        for name in ["favorites", "purchaseHistory", "bookings"] {
            try await deleteCollection(userDoc.collection(name))
        }
    }

    // Deletes every document in a collection with one batch (a batch holds up to 500 writes, plenty for this app)
    private func deleteCollection(_ collection: CollectionReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            collection.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    continuation.resume(returning: ())
                    return
                }
                let batch = Firestore.firestore().batch()
                documents.forEach { batch.deleteDocument($0.reference) }
                batch.commit { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    // For preview/mocks
    static var preview: AuthViewModel {
        let vm = AuthViewModel()
        vm.isAuthenticated = false
        vm.currentUser = nil
        return vm
    }
}
