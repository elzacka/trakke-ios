# Security Policy

## Secure by Design

Tråkke follows Secure by Design principles aligned with the CIS (Center for Internet Security) framework. Security is embedded from the start -- in the code, the configuration, and the defaults -- not bolted on after deployment.

## Security Architecture

### Secure Defaults

- **No tracking:** No IDFA, no analytics SDKs, no user fingerprinting
- **No third-party SDKs** for advertising, social media, or telemetry
- **Local-first storage:** All user data (routes, waypoints, preferences) stays on-device via SwiftData
- **No cloud sync:** User data is never transmitted to external servers
- **Minimal permissions:** Only Location When In Use. Background location is activated only during active navigation and uses `CLBackgroundActivitySession` with the blue status bar indicator.
- **Connectivity monitoring:** Network framework (NWPathMonitor) used only for connected/disconnected status; no interface types, SSIDs, or identifying network data is read

### Transport Security

- **App Transport Security (ATS):** Enforced. All network connections require HTTPS
- **Certificate pinning:** Not implemented (public government APIs use standard CA certificates)
- **TLS 1.2+:** Minimum for all connections (enforced by iOS ATS)

### Data Residency

All primary API connections use Norwegian or EU/EEA services. Two non-EU services are used for non-personal data: AWS (terrain tiles, anonymous tile coordinates only) and GitHub (knowledge pack downloads, no user data). No user identity or tracking data is sent to any service.

See [PERSONVERN.md](PERSONVERN.md) for the complete list of external services and what data is transmitted.

### Input Validation

- All API responses are decoded through Swift `Codable` with strict type checking
- Coordinate inputs are validated against geographic bounds
- Coordinate values are guarded with `.isFinite` checks in GPX import/export, BundledPOIService, POIService, ActivityTrackingService, SearchService (place name and address coordinate decoding), and ElevationService (input boundary validation) to reject NaN/Inf values
- Search inputs are sanitized before API calls
- XXE prevention (`shouldResolveExternalEntities = false`) on all XML parsers: GPX import (GPXImportService) and GML shelter parsing (POIService/ShelterGMLParser)
- GPX import enforces a 50 MB file size limit
- Weather cache evicts expired entries and is capped at 10 entries to prevent unbounded memory growth
- Valhalla routing responses are decoded through `Codable` with coordinate validation; polyline6 decoded coordinates are checked for `.isFinite`
- Route computation is rate-limited client-side (1.5 s minimum interval) to prevent abuse of the public Valhalla server
- Route computation cancellation is properly propagated (CancellationError not swallowed by rate limiter)
- ISO8601 date formatters use local per-call allocations (no `nonisolated(unsafe)` static mutable state) to eliminate data race risk under Swift strict concurrency
- Knowledge pack file paths use allowlist sanitization in PackStorageHelper: only `CharacterSet.alphanumerics` plus hyphens and underscores pass through; all other characters are stripped. Empty results fall back to `"unknown"`. This prevents path traversal via `..`, `/`, null bytes, or other special characters
- Knowledge pack downloads verified via SHA256 checksum (PackDownloadManager.verifyChecksum)
- Knowledge pack databases opened as read-only with `immutable=1` URI flag (prevents WAL/SHM file creation)
- Activity tracking rejects GPS points with horizontal accuracy > 50 m or negative accuracy
- No dynamic code execution or `eval` equivalents

### Data Protection

- SwiftData store protected with `NSFileProtectionComplete` (encrypted at rest, locked when device is locked)
- Logger output uses `privacy: .private` for all user data interpolations
- ModelContainer crash recovery: corrupted store is deleted and recreated rather than crashing
- GDPR Art. 17 "right to erasure": In-app "Slett alle data" in Preferences deletes all SwiftData records, offline map packs, temp files, clears URLCache (may contain coordinates from API requests), and uses `removePersistentDomain` for complete UserDefaults erasure
- GPX temp files are cleaned up automatically after share sheet dismissal
- GPX temp export files are additionally protected with `NSFileProtectionComplete` (encrypted at rest)
- SwiftData save failures are surfaced to the user via alerts rather than silently logged
- Knowledge pack databases stored in Application Support with `NSFileProtectionComplete`
- Activity data (GPS tracks) stored in SwiftData with `NSFileProtectionComplete`
- Logger categories use `privacy: .private` for all user data (centralized in Logger+Trakke.swift), including WaterTemperatureService error logs
- Clipboard security: all coordinate copy actions (EmergencySheet, POIDetailSheet, WaypointDetailSheet) use `UIPasteboard.setItems(_:options:)` with 5-minute expiration instead of persisting indefinitely
- Activity GPX export uses the same XML escaping, coordinate validation (`.isFinite`), and `NSFileProtectionComplete` as route GPX export

### Dependency Management

- **4 external SPM dependencies**, all open-source with active maintenance:
  - MapLibre Native (BSD-2-Clause)
  - MapLibreSwiftUI (ISC)
  - NGA mgrs-ios (MIT)
  - GRDB (MIT)
- Dependencies are pinned to specific versions via `Package.resolved`
- These 4 direct dependencies resolve to 10 total packages via SPM (including NGA utility libraries and Mockable for testing macros). All are open-source.
- No closed-source SDKs

### Information Disclosure

- All API requests include a User-Agent header: `Trakke-iOS/{version} hei@tazk.no` (version read dynamically from bundle). This is required by several Norwegian public APIs for identification. The header contains the app name, version, and developer contact email -- no user data.
- An `Accept-Language: nb-NO` header is sent with API requests. This identifies the app's language preference but contains no user data.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.3.x   | Current release |
| 1.2.x   | Security fixes only |
| 1.1.x   | End of life |
| 1.0.x   | End of life |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Email:** hei@tazk.no
2. **Subject:** `[SECURITY] Trakke iOS - Brief description`
3. **Include:** Steps to reproduce, potential impact, suggested fix if any

I will acknowledge receipt within 48 hours and provide an initial assessment within 7 days.

Please do not open public GitHub issues for security vulnerabilities.

## Security Checklist (Development)

- [ ] All network calls use HTTPS (enforced by ATS)
- [ ] No hardcoded secrets or API keys in source code
- [ ] User location data never leaves the device
- [ ] SwiftData storage is device-local only
- [ ] No `UIWebView` or `WKWebView` with arbitrary content loading
- [ ] Input validation on all user-facing text fields
- [ ] Dependencies reviewed and pinned to specific versions
- [ ] Knowledge pack paths use allowlist sanitization against traversal attacks
- [ ] Knowledge databases opened read-only (immutable)
- [ ] Activity GPS data never leaves the device
- [ ] Pack download checksums verified before installation
- [ ] Clipboard copies use time-limited expiry (5 minutes)
- [ ] No `nonisolated(unsafe)` static mutable state
