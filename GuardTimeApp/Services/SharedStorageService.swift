import Foundation

/// Shared storage service for communication between main app and extension
class SharedStorageService {
    static let shared = SharedStorageService()
    
    private let appGroupID = "group.com.jidai.guardtime"
    private let familyMembersKey = "savedFamilyMembers"
    private let lastUpdateKey = "familyMembersLastUpdate"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    // MARK: - Save Family Members (called from extension)
    func saveFamilyMembers(_ members: [FamilyMember]) {
        guard let defaults = sharedDefaults else {
            print("❌ [SharedStorage] Failed to access shared UserDefaults")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(members)
            defaults.set(data, forKey: familyMembersKey)
            defaults.set(Date().timeIntervalSince1970, forKey: lastUpdateKey)
            defaults.synchronize() // Force immediate save
            
            print("✅ [SharedStorage] Saved \(members.count) family members to shared storage")
            for member in members {
                print("   - \(member.name) (\(member.role))")
            }
        } catch {
            print("❌ [SharedStorage] Failed to encode family members: \(error)")
        }
    }
    
    // MARK: - Load Family Members (called from main app)
    func loadFamilyMembers() -> [FamilyMember] {
        guard let defaults = sharedDefaults else {
            print("❌ [SharedStorage] Failed to access shared UserDefaults")
            return []
        }
        
        guard let data = defaults.data(forKey: familyMembersKey) else {
            print("⚠️ [SharedStorage] No family members data found in shared storage")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let members = try decoder.decode([FamilyMember].self, from: data)
            print("✅ [SharedStorage] Loaded \(members.count) family members from shared storage")
            for member in members {
                print("   - \(member.name) (\(member.role))")
            }
            return members
        } catch {
            print("❌ [SharedStorage] Failed to decode family members: \(error)")
            return []
        }
    }
    
    // MARK: - Get Last Update Time
    func getLastUpdateTime() -> Date? {
        guard let defaults = sharedDefaults else { return nil }
        let timestamp = defaults.double(forKey: lastUpdateKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    // MARK: - Check if data exists
    func hasFamilyMembersData() -> Bool {
        guard let defaults = sharedDefaults else { return false }
        return defaults.data(forKey: familyMembersKey) != nil
    }
    
    // MARK: - Debug info
    func getDebugInfo() -> String {
        var info = "=== Shared Storage Debug ===\n"
        info += "App Group ID: \(appGroupID)\n"
        info += "Has data: \(hasFamilyMembersData())\n"
        
        if let lastUpdate = getLastUpdateTime() {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            info += "Last update: \(formatter.string(from: lastUpdate))\n"
        } else {
            info += "Last update: Never\n"
        }
        
        let members = loadFamilyMembers()
        info += "Stored members: \(members.count)\n"
        for member in members {
            info += "  - \(member.name) (\(member.role), \(member.appleID))\n"
        }
        
        return info
    }
}
