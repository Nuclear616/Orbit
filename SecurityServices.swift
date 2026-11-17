import Foundation
import Security

enum VaultError: LocalizedError {
    case invalidPKCS12
    case invalidProvisioningProfile
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPKCS12:
            return "The .p12 file or password is invalid, or the file does not contain a private key."
        case .invalidProvisioningProfile:
            return "The provisioning profile could not be read."
        case .keychainFailure(let status):
            return "Keychain could not store the imported credential (status \(status))."
        }
    }
}

final class KeychainVault {
    static let shared = KeychainVault()
    private let service = "com.orbit.app.credentials"

    private init() {}

    func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let updateStatus = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else { throw VaultError.keychainFailure(updateStatus) }
        } else if status != errSecSuccess {
            throw VaultError.keychainFailure(status)
        }
    }
}

struct ProvisioningProfileMetadata {
    let name: String
    let teamIdentifier: String
    let bundleIdentifier: String
    let expiresAt: Date?
}

final class CertificateVault {
    static let shared = CertificateVault()
    private let keychain = KeychainVault.shared

    private init() {}

    func importPKCS12(
        data: Data,
        password: String,
        label: String,
        lane: CertificateLane,
        sourceFileName: String
    ) throws -> CertificateProfile {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var imported: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &imported)
        guard status == errSecSuccess,
              let items = imported as? [[String: Any]],
              let first = items.first,
              first[kSecImportItemIdentity as String] as? SecIdentity != nil else {
            throw VaultError.invalidPKCS12
        }

        let keychainReference = "p12.\(UUID().uuidString)"
        try keychain.save(data, account: keychainReference)
        return CertificateProfile(
            id: UUID(),
            label: label,
            teamIdentifier: "Imported",
            bundleIdentifier: "*",
            expiresAt: nil,
            lane: lane,
            keychainReference: keychainReference,
            kind: "PKCS#12 identity",
            sourceFileName: sourceFileName,
            isEnabled: true
        )
    }

    func importProvisioningProfile(
        data: Data,
        label: String,
        lane: CertificateLane,
        sourceFileName: String
    ) throws -> CertificateProfile {
        let metadata = try parseProvisioningProfile(data)
        let keychainReference = "profile.\(UUID().uuidString)"
        try keychain.save(data, account: keychainReference)
        return CertificateProfile(
            id: UUID(),
            label: label.isEmpty ? metadata.name : label,
            teamIdentifier: metadata.teamIdentifier,
            bundleIdentifier: metadata.bundleIdentifier,
            expiresAt: metadata.expiresAt,
            lane: lane,
            keychainReference: keychainReference,
            kind: "Provisioning profile",
            sourceFileName: sourceFileName,
            isEnabled: true
        )
    }

    private func parseProvisioningProfile(_ data: Data) throws -> ProvisioningProfileMetadata {
        let plistStart = Data("<plist".utf8)
        let plistEnd = Data("</plist>".utf8)
        guard let start = data.range(of: plistStart),
              let end = data.range(of: plistEnd, options: [], in: start.lowerBound..<data.endIndex) else {
            throw VaultError.invalidProvisioningProfile
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let root = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
              let dict = root as? [String: Any] else {
            throw VaultError.invalidProvisioningProfile
        }
        let entitlements = dict["Entitlements"] as? [String: Any]
        let appIdentifier = entitlements?["application-identifier"] as? String
        let bundleIdentifier = appIdentifier?.split(separator: ".", maxSplits: 1).last.map(String.init) ?? "*"
        let teamIdentifier = (dict["TeamIdentifier"] as? [String])?.first
            ?? appIdentifier?.split(separator: ".", maxSplits: 1).first.map(String.init)
            ?? "Unknown"
        return ProvisioningProfileMetadata(
            name: dict["Name"] as? String ?? "Provisioning profile",
            teamIdentifier: teamIdentifier,
            bundleIdentifier: bundleIdentifier,
            expiresAt: dict["ExpirationDate"] as? Date
        )
    }
}

