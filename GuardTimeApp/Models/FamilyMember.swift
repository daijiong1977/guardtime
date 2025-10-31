import Foundation

// Shared family member model used by both main app and extension
struct FamilyMember: Codable, Identifiable {
    let name: String
    let role: String
    let appleID: String
    
    var id: String { appleID }
}
