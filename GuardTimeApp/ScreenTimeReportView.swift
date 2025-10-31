import SwiftUI
import FamilyControls
import DeviceActivity

struct ScreenTimeReportView: View {
    @ObservedObject var screenTimeService: ScreenTimeService
    
    var body: some View {
        // Full screen - no navigation bar, let extension control everything
        DeviceActivityReport(.childrenTabs, filter: createFilter())
            .ignoresSafeArea(.all)
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
    }
    
    private func createFilter() -> DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        
        // Request TODAY's data only for fast initial load
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // Request daily segments
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: startOfToday, end: endOfToday)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
}

extension DeviceActivityReport.Context {
    static let childrenTabs = Self("ChildrenTabs")
}
