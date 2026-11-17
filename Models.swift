import Foundation

enum CertificateLane: String, Codable, CaseIterable, Identifiable {
    case ksign
    case personalDevelopment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ksign: return "KSign apps"
        case .personalDevelopment: return "Orbit refresh"
        }
    }

    var subtitle: String {
        switch self {
        case .ksign: return "Certificate-backed app installs"
        case .personalDevelopment: return "Personal developer profile"
        }
    }
}

enum AppInstallState: String, Codable {
    case ready
    case installing
    case installed
    case needsAttention
}

struct OrbitAppRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String
    var version: String
    var iconSystemName: String
    var manifestURL: URL?
    var lane: CertificateLane
    var state: AppInstallState
    var lastInstalledAt: Date?
    var sourceLabel: String
    var localIPAPath: String?

    static let examples: [OrbitAppRecord] = [
        OrbitAppRecord(
            id: UUID(),
            name: "Example Player",
            bundleIdentifier: "com.example.player",
            version: "1.4.2",
            iconSystemName: "play.rectangle.fill",
            manifestURL: nil,
            lane: .ksign,
            state: .ready,
            lastInstalledAt: nil,
            sourceLabel: "KSign catalog",
            localIPAPath: nil
        ),
        OrbitAppRecord(
            id: UUID(),
            name: "Orbit",
            bundleIdentifier: "com.orbit.app",
            version: "0.1",
            iconSystemName: "circle.hexagongrid.fill",
            manifestURL: nil,
            lane: .personalDevelopment,
            state: .installed,
            lastInstalledAt: Date(),
            sourceLabel: "Personal development",
            localIPAPath: nil
        )
    ]
}

struct CertificateProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var teamIdentifier: String
    var bundleIdentifier: String
    var expiresAt: Date?
    var lane: CertificateLane
    var keychainReference: String?
    var kind: String
    var sourceFileName: String?
    var isEnabled: Bool

    var isExpired: Bool { expiresAt.map { $0 <= Date() } ?? false }

    static let examples: [CertificateProfile] = [
        CertificateProfile(
            id: UUID(),
            label: "KSign certificate",
            teamIdentifier: "KSIGN-DEMO",
            bundleIdentifier: "*",
            expiresAt: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
            lane: .ksign,
            keychainReference: nil,
            kind: "KSign-managed",
            sourceFileName: nil,
            isEnabled: true
        ),
        CertificateProfile(
            id: UUID(),
            label: "Personal developer certificate",
            teamIdentifier: "PERSONAL-DEMO",
            bundleIdentifier: "com.orbit.app",
            expiresAt: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            lane: .personalDevelopment,
            keychainReference: nil,
            kind: "Personal development",
            sourceFileName: nil,
            isEnabled: true
        )
    ]
}

struct DeveloperAccount: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var email: String
    var teamIdentifier: String
    var keychainReference: String?
    var connectedAt: Date
}

struct ActivityItem: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let isError: Bool
}

