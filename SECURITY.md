# Security Policy

Tråkke is built on a small set of secure-by-default choices. This document describes them and how to report vulnerabilities.

## Reporting a vulnerability

Email **hei@tazk.no** with subject `[SECURITY] Trakke iOS - <brief description>`. Include reproduction steps, potential impact, and a suggested fix if you have one. Acknowledgement within 48 hours, initial assessment within 7 days. Do not open public GitHub issues.

## Architecture

### Defaults

- No tracking, no IDFA, no analytics SDKs, no third-party telemetry
- All user data stays on-device — nothing is transmitted to app-owned servers
- Only `Location When In Use` is requested
- During active navigation and while a trip is being recorded, location updates continue with the screen locked — navigation to keep the lock-screen Live Activity current, recording so the track is not truncated when the phone goes in a pocket. Both are shown by the iOS location indicator and stop when the user ends navigation or the recording. The permission remains `When In Use`: neither starts without an explicit user action
- App Intents (Siri, Shortcuts, Action button) pass no data. An intent writes only its own case name to `UserDefaults` and opens the app, which consumes and clears it; nothing is performed headlessly

For what data is processed and the legal basis under GDPR, see [PERSONVERN.md](PERSONVERN.md).

### Transport

- App Transport Security enforced globally — all connections require HTTPS
- TLS 1.2+ minimum (iOS ATS)
- Certificate pinning is not used; public government APIs rely on standard CA certificates

### Data residency

Primary APIs are Norwegian or EU/EEA. One non-EU service is used for non-personal data only: GitHub (article updates — plain JSON fetched anonymously, filename only). No user identity or tracking data is sent to any service. See [PERSONVERN.md](PERSONVERN.md) for the full list.

### Data protection

- SwiftData store (with its WAL/SHM sidecars) protected with `NSFileProtectionComplete`. The in-progress recording journal and exported GPX files use `NSFileProtectionCompleteUntilFirstUserAuthentication` — `.complete` would fail every write while the screen is locked, which is exactly when a recording runs
- All log output uses `privacy: .private` for user data
- Coordinates truncated before API transmission (2–4 decimal places, depending on service)
- Clipboard copies expire after 5 minutes
- Temporary GPX and GeoJSON files cleaned up automatically

### Input validation

- API responses decoded through Swift `Codable` with strict type checking
- Coordinate inputs validated against geographic bounds (`.isFinite` guards)
- GPX and GeoJSON imports enforce a 50 MB file cap and 50 000 points per feature
- XML parsers disable external entity resolution (XXE prevention); parse failures surface as thrown errors
- File paths sanitized against path traversal

### Data deletion (GDPR Art. 17)

In-app deletion clears every persistent and transient store the app owns. See [PERSONVERN.md](PERSONVERN.md) section 5 for the user-facing description.

### Low Data Mode

Non-essential requests (species images, article updates) are silently skipped when Low Data Mode is enabled. Core functionality is unaffected.

### Dependencies

All dependencies are open-source and pinned via `Package.resolved`. No closed-source SDKs.

- MapLibre Native (BSD-2-Clause)
- MapLibreSwiftUI (ISC)

## Supported versions

| Version | Support |
|---------|---------|
| Latest  | Current release |
| Previous minor | Security fixes only |
