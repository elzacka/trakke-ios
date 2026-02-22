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

All external API connections are restricted to EU/EEA services:

| Service | Host | Location | Data Transmitted |
|---------|------|----------|-----------------|
| Kartverket WMTS | cache.kartverket.no | Norway | Tile coordinates only |
| Kartverket WMS (turruter) | wms.geonorge.no | Norway | Bounding box (overlay tiles) |
| Geonorge APIs | ws.geonorge.no | Norway | Search queries, coordinate lookups |
| MET Norway | api.met.no | Norway | Approximate coordinates (4 decimal truncation) |
| DSB Shelters | ogc.dsb.no | Norway | Bounding box queries |
| Riksantikvaren | api.ra.no | Norway | Bounding box queries |
| Miljødirektoratet (naturskog) | image001.miljodirektoratet.no | Norway | Bounding box (overlay tiles) |
| FOSSGIS Valhalla | valhalla1.openstreetmap.de | Germany (EU) | Origin/destination coordinates for route computation |

No data is sent to servers outside the EU/EEA. The Valhalla routing server (FOSSGIS e.V., Germany) receives origin and destination coordinates for route computation only; no user identity data is included. POI data from OpenStreetMap (caves, viewpoints, war memorials, wilderness shelters) is pre-bundled in the app as static GeoJSON files and requires no network requests.

### Input Validation

- All API responses are decoded through Swift `Codable` with strict type checking
- Coordinate inputs are validated against geographic bounds
- Coordinate values are guarded with `.isFinite` checks in all GPX import and export paths to reject NaN/Inf values
- Search inputs are sanitized before API calls
- XXE prevention (`shouldResolveExternalEntities = false`) on all XML parsers: GPX import (GPXImportService) and GML shelter parsing (POIService/ShelterGMLParser)
- GPX import enforces a 50 MB file size limit
- Weather cache evicts expired entries and is capped at 10 entries to prevent unbounded memory growth
- Valhalla routing responses are decoded through `Codable` with coordinate validation; polyline6 decoded coordinates are checked for `.isFinite`
- Route computation is rate-limited client-side (1.5 s minimum interval) to prevent abuse of the public Valhalla server
- Route computation cancellation is properly propagated (CancellationError not swallowed by rate limiter)
- No dynamic code execution or `eval` equivalents

### Data Protection

- SwiftData store protected with `NSFileProtectionComplete` (encrypted at rest, locked when device is locked)
- Logger output uses `privacy: .private` for all user data interpolations
- ModelContainer crash recovery: corrupted store is deleted and recreated rather than crashing
- GDPR Art. 17 "right to erasure": In-app "Slett alle data" in Preferences deletes all SwiftData records, offline map packs, temp files, and resets all preferences
- GPX temp files are cleaned up automatically after share sheet dismissal
- GPX temp export files are additionally protected with `NSFileProtectionComplete` (encrypted at rest)
- SwiftData save failures are surfaced to the user via alerts rather than silently logged

### Dependency Management

- **3 external SPM dependencies**, all open-source with active maintenance:
  - MapLibre Native (BSD-2-Clause)
  - MapLibreSwiftUI (ISC)
  - NGA mgrs-ios (MIT)
- Dependencies are pinned to specific versions via `Package.resolved`
- These 3 direct dependencies resolve to 9 total packages via SPM (including NGA utility libraries and Mockable for testing macros). All are open-source.
- No closed-source SDKs

### Information Disclosure

- All API requests include a User-Agent header: `Trakke-iOS/{version} hei@tazk.no` (version read dynamically from bundle). This is required by several Norwegian public APIs for identification. The header contains the app name, version, and developer contact email -- no user data.

### Privacy as Security

- No user accounts or authentication (no credentials to compromise)
- No personal data collection beyond device-local storage
- No cookies, tokens, or session identifiers sent to external services
- Location data is never stored remotely or shared with third parties
- Location permission uses a pre-permission primer card (LocationPrimerView) before the system dialog, explaining why access is needed. The app remains fully functional without location access.
- Navigation sends only origin/destination coordinates to the routing server -- no user identity, device ID, or session tokens

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.2.x   | Current release |
| 1.1.x   | Security fixes only |
| 1.0.x   | Security fixes only |

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
