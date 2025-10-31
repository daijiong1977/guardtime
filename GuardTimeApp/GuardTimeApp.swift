import SwiftUI
import FamilyControls

@main
struct GuardTimeApp: App {
    @StateObject private var screenTimeService = ScreenTimeService()
    @State private var selectedMemberURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenTimeService)
                .environment(\.openURL, OpenURLAction { url in
                    print("🔵 [APP] Received URL: \(url)")
                    selectedMemberURL = url
                    return .handled
                })
                .onOpenURL { url in
                    print("🔵 [APP] onOpenURL called with: \(url)")
                    selectedMemberURL = url
                }
        }
    }
}
