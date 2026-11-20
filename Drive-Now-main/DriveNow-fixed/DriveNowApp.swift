
import SwiftUI
import Firebase

@main
struct DriveNowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Use a StateObject for the Firebase auth view model and inject into environment
    @StateObject private var authViewModel = AuthViewModel()

    // CHANGED: configure Firebase as early as possible. AuthViewModel only attaches its login listener if Firebase is
    // already configured when it is created, so a late configure could leave the app never noticing logins.
    init() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // CHANGED: only configure if the App's init() below has not already done it
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    print("Connected to Firebase")

    return true
  }
}
