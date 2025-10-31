import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

class DeviceActivityMonitorService: ObservableObject {
    @Published var isMonitoring = false
    @Published var autoMonitorDuringStudyTime = false
    @Published var studyTimeStart = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @Published var studyTimeEnd = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    
    private let center = DeviceActivityCenter()
    private let studyTimeActivityName = DeviceActivityName("study-time-monitoring")
    private var autoMonitorTimer: Timer?
    
    init() {
        checkMonitoringStatus()
        
        // Set up auto-monitoring timer that checks every minute
        if autoMonitorDuringStudyTime {
            startAutoMonitorTimer()
        }
    }
    
    func startMonitoring() {
        print("🟢 Starting Study Time monitoring...")
        
        do {
            // Only monitor study hours (6-10 PM) - Report Extension handles daily data
            let studyStartComponents = Calendar.current.dateComponents([.hour, .minute], from: studyTimeStart)
            let studyEndComponents = Calendar.current.dateComponents([.hour, .minute], from: studyTimeEnd)
            
            let studySchedule = DeviceActivitySchedule(
                intervalStart: studyStartComponents,
                intervalEnd: studyEndComponents,
                repeats: true,
                warningTime: DateComponents(minute: 5) // Get updates every 5 minutes during study hours
            )
            
            // Start study time monitoring schedule
            try center.startMonitoring(studyTimeActivityName, during: studySchedule)
            
            DispatchQueue.main.async {
                self.isMonitoring = true
                print("✅ Study Time monitoring started successfully")
                print("   - Study hours: \(studyStartComponents.hour ?? 18):\(String(format: "%02d", studyStartComponents.minute ?? 0)) - \(studyEndComponents.hour ?? 22):\(String(format: "%02d", studyEndComponents.minute ?? 0))")
                print("   - Updates: Every 5 minutes during study hours")
                print("   - Daily data: Automatically loaded from Report Extension")
            }
        } catch {
            print("❌ Failed to start monitoring: \(error)")
        }
    }
    
    func stopMonitoring() {
        print("🛑 Stopping Study Time monitoring...")
        center.stopMonitoring([studyTimeActivityName])
        
        DispatchQueue.main.async {
            self.isMonitoring = false
            print("✅ Study Time monitoring stopped")
        }
    }
    
    func checkMonitoringStatus() {
        // Check if monitoring is active
        let activities = center.activities
        isMonitoring = activities.contains(studyTimeActivityName)
    }
    
    func isCurrentlyStudyTime() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: studyTimeStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: studyTimeEnd)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        guard let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }),
              let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }) else {
            return false
        }
        
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }
    
    // MARK: - Auto-Monitoring
    
    private func startAutoMonitorTimer() {
        stopAutoMonitorTimer()
        
        // Check every minute if we should start/stop monitoring
        autoMonitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndAutoToggleMonitoring()
        }
        
        // Check immediately
        checkAndAutoToggleMonitoring()
    }
    
    private func stopAutoMonitorTimer() {
        autoMonitorTimer?.invalidate()
        autoMonitorTimer = nil
    }
    
    private func checkAndAutoToggleMonitoring() {
        guard autoMonitorDuringStudyTime else { return }
        
        let isStudyTime = isCurrentlyStudyTime()
        
        if isStudyTime && !isMonitoring {
            print("📚 Auto-starting monitoring (study time began)")
            startMonitoring()
        } else if !isStudyTime && isMonitoring {
            print("🎉 Auto-stopping monitoring (study time ended)")
            stopMonitoring()
        }
    }
    
    func updateAutoMonitoringSetting(_ enabled: Bool) {
        autoMonitorDuringStudyTime = enabled
        
        if enabled {
            startAutoMonitorTimer()
            print("✅ Auto-monitoring enabled - will activate during study hours")
        } else {
            stopAutoMonitorTimer()
            print("⏸️ Auto-monitoring disabled")
        }
    }
    
    deinit {
        stopAutoMonitorTimer()
    }
}
