import SwiftUI
import DeviceActivity
import FamilyControls

struct KidDetailView: View {
    let kidName: String
    let kidAppleID: String
    @Environment(\.dismiss) private var dismiss
    @State private var context: DeviceActivityReport.Context = .init(rawValue: "KidDashboard")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Save the selected kid appleID to shared storage so extension can filter
                // DeviceActivityReport filtered for this specific kid
                DeviceActivityReport(context, filter: createFilterForKid())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        saveSelectedKidAppleID()
                    }
            }
            .navigationTitle("Screen Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createFilterForKid() -> DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Note: The filter uses .all, but the extension will read the selected kid appleID
        // from shared storage and filter accordingly
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: startOfDay, end: endOfDay)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
    
    private func saveSelectedKidAppleID() {
        // Save the selected kid's appleID to shared storage
        if let userDefaults = UserDefaults(suiteName: "group.com.jidai.guardtime") {
            userDefaults.set(kidAppleID, forKey: "selectedKidAppleID")
            userDefaults.set(kidName, forKey: "selectedKidName")
            userDefaults.synchronize()
        }
    }
}
