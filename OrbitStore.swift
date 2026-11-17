import Foundation

@MainActor
final class OrbitStore: ObservableObject {
    @Published private(set) var apps: [OrbitAppRecord]
    @Published private(set) var certificates: [CertificateProfile]
    @Published private(set) var account: DeveloperAccount?
    @Published private(set) var activity: [ActivityItem]
    @Published var isBusy = false
    @Published var alertMessage: String?

    private let installer: InstallationProvider
    private let refresher: SigningProvider

    init(
        installer: InstallationProvider = KSignManifestProvider(),
        refresher: SigningProvider = PersonalDevelopmentProvider()
    ) {
        self.installer = installer
        self.refresher = refresher
        self.apps = Self.load([OrbitAppRecord].self, key: "orbit.apps") ?? OrbitAppRecord.examples
        self.certificates = Self.load([CertificateProfile].self, key: "orbit.certificates") ?? CertificateProfile.examples
        self.account = Self.load(DeveloperAccount.self, key: "orbit.account")
        self.activity = Self.load([ActivityItem].self, key: "orbit.activity") ?? []
    }

    var ksignCertificate: CertificateProfile? {
        certificates.first {
            $0.lane == .ksign &&
            $0.isEnabled &&
            $0.keychainReference != nil &&
            $0.kind == "PKCS#12 identity"
        }
    }

    var personalCertificate: CertificateProfile? {
        certificates.first { $0.lane == .personalDevelopment && $0.isEnabled }
    }

    var installedApps: [OrbitAppRecord] {
        apps.filter { $0.state == .installed }
    }

    func install(_ app: OrbitAppRecord) async {
        guard let certificate = ksignCertificate else {
            showError(OrbitError.missingPKCS12.localizedDescription)
            return
        }
        setState(.installing, for: app.id)
        isBusy = true
        defer { isBusy = false }

        do {
            try await installer.install(app: app, using: certificate)
            setState(.installed, for: app.id)
            appendActivity("Install handoff started", detail: app.name, isError: false)
        } catch {
            setState(.needsAttention, for: app.id)
            showError(error.localizedDescription)
            appendActivity("Install failed", detail: "\(app.name): \(error.localizedDescription)", isError: true)
        }
    }

    func refreshOrbit() async {
        guard let certificate = personalCertificate else {
            showError("No enabled personal-development certificate is configured.")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await refresher.refreshOrbit(using: certificate)
            appendActivity("Orbit refresh started", detail: "Personal-development lane", isError: false)
        } catch {
            showError(error.localizedDescription)
            appendActivity("Orbit refresh unavailable", detail: error.localizedDescription, isError: true)
        }
    }

    func addManifest(to appID: UUID, url: URL) {
        guard url.scheme?.lowercased() == "https" else {
            showError(OrbitError.invalidManifestURL.localizedDescription)
            return
        }
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].manifestURL = url
        persist()
    }

    func importIPA(from url: URL) {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ImportedIPAs", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: destination)
            let imported = OrbitAppRecord(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                bundleIdentifier: "Imported IPA",
                version: "Unknown",
                iconSystemName: "shippingbox.fill",
                manifestURL: nil,
                lane: .ksign,
                state: .ready,
                lastInstalledAt: nil,
                sourceLabel: "Imported file",
                localIPAPath: destination.path
            )
            apps.insert(imported, at: 0)
            appendActivity("IPA imported", detail: imported.name, isError: false)
            persist()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func importPKCS12(from url: URL, password: String, lane: CertificateLane) {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let profile = try CertificateVault.shared.importPKCS12(
                data: data,
                password: password,
                label: url.deletingPathExtension().lastPathComponent,
                lane: lane,
                sourceFileName: url.lastPathComponent
            )
            certificates.append(profile)
            appendActivity("Certificate imported", detail: profile.label, isError: false)
            persist()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func importProvisioningProfile(from url: URL, lane: CertificateLane) {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let profile = try CertificateVault.shared.importProvisioningProfile(
                data: data,
                label: url.deletingPathExtension().lastPathComponent,
                lane: lane,
                sourceFileName: url.lastPathComponent
            )
            certificates.append(profile)
            appendActivity("Provisioning profile imported", detail: profile.label, isError: false)
            persist()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func saveDeveloperAccount(displayName: String, email: String, teamIdentifier: String) {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !teamIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Enter the Apple Developer email and Team ID.")
            return
        }
        account = DeveloperAccount(
            id: account?.id ?? UUID(),
            displayName: displayName.isEmpty ? email : displayName,
            email: email,
            teamIdentifier: teamIdentifier,
            keychainReference: nil,
            connectedAt: Date()
        )
        appendActivity("Developer account saved", detail: email, isError: false)
        persist()
    }

    func report(_ message: String) { showError(message) }

    func clearAlert() { alertMessage = nil }

    private func setState(_ state: AppInstallState, for id: UUID) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].state = state
        apps[index].lastInstalledAt = state == .installed ? Date() : apps[index].lastInstalledAt
        persist()
    }

    private func showError(_ message: String) { alertMessage = message }

    private func appendActivity(_ title: String, detail: String, isError: Bool) {
        activity.insert(ActivityItem(id: UUID(), date: Date(), title: title, detail: detail, isError: isError), at: 0)
        activity = Array(activity.prefix(20))
        persist()
    }

    private func persist() {
        Self.save(apps, key: "orbit.apps")
        Self.save(certificates, key: "orbit.certificates")
        Self.save(account, key: "orbit.account")
        Self.save(activity, key: "orbit.activity")
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

