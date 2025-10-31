import SwiftUI
import FamilyControls
import DeviceActivity
import Combine

class ScreenTimeService: ObservableObject {
    @Published var isAuthorized = false
    @Published var children: [Child] = []
    @Published var familyMembers: [FamilyMember] = []
    @Published var debugInfo: String = ""
    
    let authCenter = AuthorizationCenter.shared
    private let sharedStorage = SharedStorageService.shared
    private var pollingTimer: Timer?
    
    init() {
        // Check authorization status on startup on main thread
        Task { @MainActor in
            checkAuthorizationStatus()
            loadFamilyMembersFromSharedStorage()
            startPollingForUpdates()
        }
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    func checkAuthorizationStatus() {
        let status = authCenter.authorizationStatus
        isAuthorized = (status == .approved)
        print("🔍 Authorization check: status=\(status.rawValue), isAuthorized=\(isAuthorized)")
        if isAuthorized {
            print("✅ Already authorized - skipping permission request")
        } else {
            print("⚠️ Not authorized - will show permission screen")
        }
    }
    
    // MARK: - Shared Storage Methods
    
    func loadFamilyMembersFromSharedStorage() {
        let members = sharedStorage.loadFamilyMembers()
        Task { @MainActor in
            self.familyMembers = members
            if !members.isEmpty {
                self.debugInfo = "✅ Loaded \(members.count) family members from shared storage\n"
                self.debugInfo += sharedStorage.getDebugInfo()
            } else {
                self.debugInfo = "⚠️ No family members in shared storage yet.\n"
                self.debugInfo += "Start monitoring to populate data from extension."
            }
        }
    }
    
    func startPollingForUpdates() {
        // Poll every 2 seconds to check for updates from the extension
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentMembers = self.familyMembers
            let newMembers = self.sharedStorage.loadFamilyMembers()
            
            // Only update if data changed
            if newMembers.count != currentMembers.count || 
               !newMembers.isEmpty && newMembers.map({ $0.id }) != currentMembers.map({ $0.id }) {
                Task { @MainActor in
                    self.familyMembers = newMembers
                    print("🔄 [MAIN APP] Updated family members from shared storage: \(newMembers.count) members")
                }
            }
        }
    }
    
    func refreshFamilyMembers() {
        loadFamilyMembersFromSharedStorage()
    }
    
    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = authCenter.authorizationStatus == .approved
            }
            
            // After authorization, try to fetch family members
            if self.isAuthorized {
                await fetchFamilyMembers()
            }
        } catch {
            print("Failed to request authorization: \(error)")
            await MainActor.run {
                self.debugInfo = "Authorization error: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchFamilyMembers() async {
        await MainActor.run {
            self.debugInfo = "=== Attempting to fetch family members ===\n"
            self.debugInfo += "Authorization Status: \(authCenter.authorizationStatus.rawValue)\n"
        }
        
        // Create a query context for today's activity
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        await MainActor.run {
            self.debugInfo += "Time Range: \(startOfDay) to \(endOfDay)\n"
        }
        
        // Try different approaches to access DeviceActivityFilter.Users
        
        // Approach 1: Try using .all users (if available)
        await MainActor.run {
            self.debugInfo += "\n--- Approach 1: DeviceActivityFilter.Users ---\n"
        }
        
        do {
            // Create filter with .all users to include all family members
            let filter = DeviceActivityFilter(
                segment: .daily(during: DateInterval(start: startOfDay, end: endOfDay)),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
            
            await MainActor.run {
                self.debugInfo += "✓ Created DeviceActivityFilter with users: .all\n"
                self.debugInfo += "  - Segment: daily\n"
                self.debugInfo += "  - Users: .all (includes all family members)\n"
                self.debugInfo += "  - Devices: iPhone, iPad\n"
            }
            
            // Start monitoring to enable data collection
            let center = DeviceActivityCenter()
            let activityName = DeviceActivityName("FamilyMonitoring")
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            
            try center.startMonitoring(activityName, during: schedule)
            
            await MainActor.run {
                self.debugInfo += "✓ Started monitoring with activity name: FamilyMonitoring\n"
                self.debugInfo += "\n--- Important Discovery ---\n"
                self.debugInfo += "DeviceActivityFilter.Users is successfully configured!\n"
                self.debugInfo += "However, to ACCESS the actual user names/data:\n"
                self.debugInfo += "• DeviceActivityData.User values are ONLY available\n"
                self.debugInfo += "  inside a DeviceActivityReport extension\n"
                self.debugInfo += "• The extension runs in a sandboxed environment\n"
                self.debugInfo += "• User info (nameComponents, appleID, role) can be\n"
                self.debugInfo += "  read there and used to generate reports\n"
                self.debugInfo += "\n--- What This Means ---\n"
                self.debugInfo += "From the main app, we CANNOT directly list family\n"
                self.debugInfo += "member names. Apple requires a Report Extension.\n"
                self.debugInfo += "\nTo get the dropdown with real kids' names, you need:\n"
                self.debugInfo += "1. Create a DeviceActivityReport extension target\n"
                self.debugInfo += "2. In that extension, access DeviceActivityData.User\n"
                self.debugInfo += "3. The extension will show the family member picker\n"
            }
            
        } catch {
            await MainActor.run {
                self.debugInfo += "✗ Error: \(error.localizedDescription)\n"
            }
        }
    }
    
    func addChild(_ child: Child) {
        children.append(child)
    }
    
    func removeChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
    }
}

struct Child: Identifiable, Codable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// FamilyMember is now defined in Models/FamilyMember.swift
