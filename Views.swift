import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: OrbitStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Orbit", systemImage: "circle.hexagongrid.fill") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack.3d.up.fill") }
            CertificatesView()
                .tabItem { Label("Certificates", systemImage: "checkmark.shield.fill") }
            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
        .tint(.indigo)
        .alert("Orbit", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.clearAlert() } }
        )) {
            Button("OK", role: .cancel) { store.clearAlert() }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: OrbitStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    laneCard(
                        title: "KSign apps",
                        subtitle: "Install apps using the enabled KSign certificate.",
                        systemImage: "arrow.down.app.fill",
                        color: .blue,
                        status: store.ksignCertificate.map { $0.isExpired ? "Expired" : "Ready" } ?? "Not configured"
                    )
                    laneCard(
                        title: "Orbit refresh",
                        subtitle: "Keep Orbit current with your personal-development profile.",
                        systemImage: "arrow.triangle.2.circlepath",
                        color: .purple,
                        status: store.personalCertificate.map { $0.isExpired ? "Expired" : "Ready" } ?? "Not configured"
                    )
                    Button {
                        Task { await store.refreshOrbit() }
                    } label: {
                        Label("Refresh Orbit", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isBusy)
                }
                .padding()
            }
            .navigationTitle("Orbit")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your app orbit")
                .font(.largeTitle.bold())
            Text("One place for your certificate-backed installs and Orbit refreshes.")
                .foregroundStyle(.secondary)
        }
    }

    private func laneCard(title: String, subtitle: String, systemImage: String, color: Color, status: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.caption.bold())
                .foregroundStyle(status == "Ready" ? .green : .orange)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct LibraryView: View {
    @EnvironmentObject private var store: OrbitStore

    var body: some View {
        NavigationStack {
            List {
                Section("Installed") {
                    if store.installedApps.isEmpty {
                        OrbitEmptyState(title: "No installed apps", systemImage: "square.stack.3d.up", message: "Apps you install through Orbit will appear here.")
                    } else {
                        ForEach(store.installedApps) { app in
                            appRow(app)
                        }
                    }
                }
                Section("Available") {
                    ForEach(store.apps.filter { $0.state != .installed }) { app in
                        appRow(app)
                    }
                }
            }
            .navigationTitle("Library")
        }
    }

    private func appRow(_ app: OrbitAppRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: app.iconSystemName)
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.headline)
                Text("v\(app.version) · \(app.lane.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(app.state == .installed ? "Reinstall" : "Install") {
                Task { await store.install(app) }
            }
            .buttonStyle(.bordered)
            .disabled(store.isBusy || app.lane != .ksign)
        }
        .padding(.vertical, 4)
    }
}

struct CertificatesView: View {
    @EnvironmentObject private var store: OrbitStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(CertificateLane.allCases) { lane in
                    Section(lane.title) {
                        ForEach(store.certificates.filter { $0.lane == lane }) { certificate in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(certificate.label).font(.headline)
                                    Spacer()
                                    Image(systemName: certificate.isExpired ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                        .foregroundStyle(certificate.isExpired ? .orange : .green)
                                }
                                Text(certificate.isExpired ? "Expired" : "Expires \(certificate.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Team \(certificate.teamIdentifier) · \(certificate.bundleIdentifier)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Certificates")
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var store: OrbitStore

    var body: some View {
        NavigationStack {
            List {
                if store.activity.isEmpty {
                    OrbitEmptyState(title: "No activity yet", systemImage: "clock.arrow.circlepath", message: "Install and refresh events will appear here.")
                } else {
                    ForEach(store.activity) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(item.isError ? .red : .green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Activity")
        }
    }
}

private struct OrbitEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

