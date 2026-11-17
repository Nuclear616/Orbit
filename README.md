# Orbit

Orbit is a SwiftUI iOS sideloading client scaffold with two explicit signing lanes:

- **Sideloading apps**: apps installed through a KSign-managed certificate or manifest endpoint.
- **Orbit refresh**: Orbit's own refresh path, backed by a personal-development profile.

## Important platform boundary

iOS does not provide a public API for a third-party app to silently sign and install arbitrary `.ipa` files. A production Orbit implementation therefore needs a supported installation handoff (for example, a trusted `itms-services` manifest or a companion signing service) and must respect Apple account, certificate, provisioning, and device policies. The code keeps that integration behind `InstallationProvider` and `SigningProvider` so the UI is usable now without embedding certificate secrets or pretending an unsupported API exists.

## Open in Xcode

1. Create a new **iOS App** project named `Orbit` using SwiftUI.
2. Set the deployment target to iOS 17 or later.
3. Replace the generated Swift files with the contents of this folder, preserving the folder structure.
4. Add the `Orbit` capability only after you have a real backend/provider for the chosen installation handoff.

The current build is intentionally safe-by-default: the demo provider returns an explanatory error until a real provider is configured.

## Provider integration points

- `KSignManifestProvider` opens a trusted installation manifest URL for an app.
- `PersonalDevelopmentProvider` models the separate Orbit refresh lane and refuses to refresh until a backend has been supplied.
- `CertificateVault` is the boundary for Keychain-backed references. Private keys and `.p12` data are never persisted in `UserDefaults`.

## Suggested production hardening

- Store certificate identities and tokens in the Keychain, never in app preferences.
- Pin or otherwise authenticate the manifest/signing service.
- Validate bundle IDs, team IDs, profile entitlements, and certificate expiration before every operation.
- Require explicit user confirmation before opening an installation handoff.
- Add a server-side audit trail and certificate revocation handling.

