import Foundation
import UIKit

enum OrbitError: LocalizedError {
    case missingManifest
    case expiredCertificate(String)
    case unsupportedInstallationFlow
    case providerNotConfigured
    case missingPKCS12
    case invalidManifestURL

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "This app has no installation manifest yet."
        case .expiredCertificate(let label):
            return "\(label) is expired. Choose an active certificate before continuing."
        case .unsupportedInstallationFlow:
            return "iOS requires a supported installation handoff; Orbit cannot silently install an IPA from inside the app."
        case .providerNotConfigured:
            return "This provider is not configured for the current build."
        case .missingPKCS12:
            return "Import a .p12 certificate before sideloading apps."
        case .invalidManifestURL:
            return "The installation manifest URL is invalid or not trusted."
        }
    }
}

protocol InstallationProvider {
    func install(app: OrbitAppRecord, using certificate: CertificateProfile) async throws
}

protocol SigningProvider {
    func refreshOrbit(using certificate: CertificateProfile) async throws
}

/// Opens a trusted manifest handoff. The actual certificate/private key remains outside Orbit.
struct KSignManifestProvider: InstallationProvider {
    func install(app: OrbitAppRecord, using certificate: CertificateProfile) async throws {
        guard certificate.lane == .ksign else {
            throw OrbitError.providerNotConfigured
        }
        guard certificate.keychainReference != nil, certificate.kind == "PKCS#12 identity" else {
            throw OrbitError.missingPKCS12
        }
        guard !certificate.isExpired else {
            throw OrbitError.expiredCertificate(certificate.label)
        }
        guard let manifestURL = app.manifestURL else {
            throw OrbitError.missingManifest
        }
        guard manifestURL.scheme?.lowercased() == "https" else {
            throw OrbitError.invalidManifestURL
        }
        try await MainActor.run {
            guard UIApplication.shared.canOpenURL(manifestURL) else {
                throw OrbitError.invalidManifestURL
            }
            UIApplication.shared.open(manifestURL)
        }
    }
}

/// Boundary for the personal-development refresh backend used only by Orbit itself.
struct PersonalDevelopmentProvider: SigningProvider {
    func refreshOrbit(using certificate: CertificateProfile) async throws {
        guard certificate.lane == .personalDevelopment else {
            throw OrbitError.providerNotConfigured
        }
        guard !certificate.isExpired else {
            throw OrbitError.expiredCertificate(certificate.label)
        }
        // A real implementation belongs here and must talk to a user-authorized
        // personal-development signing backend. There is no public iOS API that
        // lets Orbit silently replace its own installed app bundle.
        throw OrbitError.unsupportedInstallationFlow
    }
}

/// Stores references, not certificate bytes. Replace the placeholder methods with Keychain code.
final class CertificateVault {
    static let shared = CertificateVault()

    private init() {}

    func storeKeychainReference(_ reference: String, for profileID: UUID) throws {
        // TODO: Store the reference in Keychain with kSecAttrAccessibleAfterFirstUnlock.
        _ = reference
        _ = profileID
    }
}

