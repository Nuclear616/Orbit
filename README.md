# Orbit

Orbit is a SwiftUI iOS sideloading client scaffold with two explicit signing lanes:

- **KSign apps**: apps installed through a KSign-managed certificate or manifest endpoint.
- **Orbit refresh**: Orbit's own refresh path, backed by a personal-development profile.

The app now supports importing `.ipa` files from Files, importing `.p12` identities and `.mobileprovision` profiles into the device Keychain, and saving a developer-account profile without collecting an Apple ID password. Orbit requires an imported `.p12` identity before it will start a KSign app install handoff.

## Important platform boundary

iOS does not provide a public API for a third-party app to silently sign and install arbitrary `.ipa` files. A production Orbit implementation therefore needs a supported installation handoff (for example, a trusted `itms-services` manifest or a companion signing service) and must respect Apple account, certificate, provisioning, and device policies. The code keeps that integration behind `InstallationProvider` and `SigningProvider` so the UI is usable now without embedding certificate secrets or pretending an unsupported API exists.

## Open in Xcode

1. Create a new **iOS App** project named `Orbit` using SwiftUI.
2. Set the deployment target to iOS 16 or later.
3. Replace the generated Swift files with the contents of this folder, preserving the folder structure.
4. Add the `Orbit` capability only after you have a real backend/provider for the chosen installation handoff.

The current build is intentionally safe-by-default: the demo provider returns an explanatory error until a real provider is configured.

## Build an unsigned IPA with GitHub Actions

The repository includes `.github/workflows/build-ipa.yml`. It runs on a macOS GitHub-hosted runner, archives Orbit without Apple signing, packages an unsigned IPA, uploads it as a workflow artifact, and publishes it to a GitHub release for release-marked pushes.

No Apple signing secrets are required for this workflow. The resulting IPA is not installable on a physical iPhone until it is signed with a valid certificate and provisioning profile.

The workflow does not embed KSign private keys; KSign remains the installation lane for other apps.

## Provider integration points

- `KSignManifestProvider` opens a trusted installation manifest URL for an app.
- `PersonalDevelopmentProvider` models the separate Orbit refresh lane and refuses to refresh until a backend has been supplied.
- `CertificateVault` is the boundary for Keychain-backed references. Private keys and `.p12` data are never persisted in `UserDefaults`.
- `CertificateVault` validates imported PKCS#12 identities and parses provisioning-profile metadata before saving the files in Keychain.
- IPA import behavior is currently in `OrbitStore`: imported IPAs are copied into Application Support and tracked in the library.

## Account and certificate boundary

Orbit does not collect Apple ID passwords or verification codes. The account screen stores developer-account metadata, while `.p12` and provisioning-profile imports are stored in Keychain. Actual Apple Developer account authentication and arbitrary IPA signing still require a user-authorized backend or a supported Apple/Xcode workflow; iOS does not expose a public API for silently replacing an installed app or installing arbitrary unsigned IPAs.

## Suggested production hardening

- Store certificate identities and tokens in the Keychain, never in app preferences.
- Pin or otherwise authenticate the manifest/signing service.
- Validate bundle IDs, team IDs, profile entitlements, and certificate expiration before every operation.
- Require explicit user confirmation before opening an installation handoff.
- Add a server-side audit trail and certificate revocation handling.

