import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var screenTimeService: ScreenTimeService
    
    var body: some View {
        NavigationView {
            VStack {
                if !screenTimeService.isAuthorized {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Screen Time Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("GuardTime needs permission to monitor screen time activity. This allows you to view family members' device usage.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Grant Access") {
                            Task {
                                await screenTimeService.requestAuthorization()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else {
                    // Show the Screen Time report test view
                    ScreenTimeReportView(screenTimeService: screenTimeService)
                }
            }
            .navigationTitle("GuardTime")
            .onAppear {
                // Check authorization status when view appears
                screenTimeService.checkAuthorizationStatus()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeService())
}
