# Security Policy

## Secure by Design

Trakke follows Secure by Design principles aligned with the CIS (Center for Internet Security) framework. Security is embedded from the start -- in the code, the configuration, and the defaults -- not bolted on after deployment.

## Security Architecture

### Secure Defaults

- **No tracking:** No IDFA, no analytics SDKs, no user fingerprinting
- **No third-party SDKs** for advertising, social media, or telemetry
- **Local-first storage:** All user data (routes, waypoints, preferences) stays on-device via SwiftData
- **No cloud sync:** User data is never transmitted to external servers
- **Minimal permissions:** Only Location When In Use (no background tracking)

### Transport Security

- **App Transport Security (ATS):** Enforced. All network connections require HTTPS
- **Certificate pinning:** Not implemented (public government APIs use standard CA certificates)
- **TLS 1.2+:** Minimum for all connections (enforced by iOS ATS)

### Data Residency

All external API connections are restricted to EU/EEA services:

| Service | Host | Location | Data Transmitted |
|---------|------|----------|-----------------|
| Kartverket WMTS | cache.kartverket.no | Norway | Tile coordinates only |
| Geonorge APIs | ws.geonorge.no | Norway | Search queries, coordinate lookups |
| MET Norway | api.met.no | Norway | Approximate coordinates (4 decimal truncation) |
| DSB Shelters | github.com (dsb-norge) | EU | None (static download) |
| Overpass API | overpass-api.de | Germany | Bounding box queries |
| Riksantikvaren | api.ra.no | Norway | Bounding box queries |

No data is sent to servers outside the EU/EEA.

### Input Validation

- All API responses are decoded through Swift `Codable` with strict type checking
- Coordinate inputs are validated against geographic bounds
- Search inputs are sanitized before API calls
- No dynamic code execution or `eval` equivalents

### Dependency Management

- **4 external SPM dependencies**, all open-source with active maintenance:
  - MapLibre Native (BSD-2-Clause)
  - MapLibreSwiftUI (BSD-2-Clause)
  - NGA mgrs-ios (MIT)
  - NGA projections-ios (MIT)
- Dependencies are pinned to specific versions via `Package.resolved`
- No closed-source SDKs

### Privacy as Security

- No user accounts or authentication (no credentials to compromise)
- No personal data collection beyond device-local storage
- No cookies, tokens, or session identifiers sent to external services
- Location data is never stored remotely or shared with third parties

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Current development |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Email:** hei@tazk.no
2. **Subject:** `[SECURITY] Trakke iOS - Brief description`
3. **Include:** Steps to reproduce, potential impact, suggested fix if any

We will acknowledge receipt within 48 hours and provide an initial assessment within 7 days.

Please do not open public GitHub issues for security vulnerabilities.

## Security Checklist (Development)

- [ ] All network calls use HTTPS (enforced by ATS)
- [ ] No hardcoded secrets or API keys in source code
- [ ] User location data never leaves the device
- [ ] SwiftData storage is device-local only
- [ ] No `UIWebView` or `WKWebView` with arbitrary content loading
- [ ] Input validation on all user-facing text fields
- [ ] Dependencies reviewed and pinned to specific versions
