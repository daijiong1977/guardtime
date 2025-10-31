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
        
        // Always request last 8 days (today + 7 previous days)
        // Extension will handle showing/hiding history view internally
        let today = calendar.startOfDay(for: now)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: sevenDaysAgo, end: endOfToday)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }
}

extension DeviceActivityReport.Context {
    static let childrenTabs = Self("ChildrenTabs")
}
