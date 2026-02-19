# Security Policy

## Secure by Design

Tråkke follows Secure by Design principles aligned with the CIS (Center for Internet Security) framework. Security is embedded from the start -- in the code, the configuration, and the defaults -- not bolted on after deployment.

## Security Architecture

### Secure Defaults

- **No tracking:** No IDFA, no analytics SDKs, no user fingerprinting
- **No third-party SDKs** for advertising, social media, or telemetry
- **Local-first storage:** All user data (routes, waypoints, preferences) stays on-device via SwiftData
- **No cloud sync:** User data is never transmitted to external servers
- **Minimal permissions:** Only Location When In Use (no background tracking)
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

No data is sent to servers outside the EU/EEA. POI data from OpenStreetMap (caves, observation towers, war memorials, wilderness shelters) is pre-bundled in the app as static GeoJSON files and requires no network requests.

### Input Validation

- All API responses are decoded through Swift `Codable` with strict type checking
- Coordinate inputs are validated against geographic bounds
- Search inputs are sanitized before API calls
- GPX import: XXE prevention (`shouldResolveExternalEntities = false`), 50 MB file size limit
- No dynamic code execution or `eval` equivalents

### Data Protection

- SwiftData store protected with `NSFileProtectionComplete` (encrypted at rest, locked when device is locked)
- Logger output uses `privacy: .private` for all user data interpolations
- ModelContainer crash recovery: corrupted store is deleted and recreated rather than crashing

### Dependency Management

- **3 external SPM dependencies**, all open-source with active maintenance:
  - MapLibre Native (BSD-2-Clause)
  - MapLibreSwiftUI (ISC)
  - NGA mgrs-ios (MIT)
- Dependencies are pinned to specific versions via `Package.resolved`
- These 3 direct dependencies resolve to 9 total packages via SPM (including NGA utility libraries and Mockable for testing macros). All are open-source.
- No closed-source SDKs

### Privacy as Security

- No user accounts or authentication (no credentials to compromise)
- No personal data collection beyond device-local storage
- No cookies, tokens, or session identifiers sent to external services
- Location data is never stored remotely or shared with third parties
- Location permission uses a pre-permission primer card (LocationPrimerView) before the system dialog, explaining why access is needed. The app remains fully functional without location access.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.1.x   | Current release |
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
