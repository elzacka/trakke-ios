# Security Policy

## Secure by Design

Tråkke follows Secure by Design principles. Security is embedded from the start. In the code, the configuration, and the defaults.

## Security Architecture

### Secure Defaults

No tracking, no IDFA, no analytics SDKs, no third-party telemetry. All user data stays on-device; nothing is transmitted to app-owned servers. Only `Location When In Use` is requested.

For what data is processed and the legal basis under GDPR, see [PERSONVERN.md](PERSONVERN.md).

### Transport Security

- **App Transport Security (ATS):** Enforced globally. All connections require HTTPS
- **TLS 1.2+:** Minimum for all connections (enforced by iOS ATS)
- **Certificate pinning:** Not implemented (public government APIs use standard CA certificates)

### Data Residency

All primary API connections use Norwegian or EU/EEA services. Two non-EU services are used for non-personal data only: AWS (terrain tiles) and GitHub (knowledge articles). No user identity or tracking data is sent to any service.

See [PERSONVERN.md](PERSONVERN.md) for the complete list of external services and what data is transmitted.

### Data Protection

- SwiftData store protected with `NSFileProtectionComplete` (encrypted at rest)
- All log output uses `privacy: .private` for user data
- Coordinates truncated before API transmission (2-4 decimal places depending on service)
- Clipboard copies expire after 5 minutes
- GPX temp files cleaned up automatically

### Input Validation

- All API responses decoded through Swift `Codable` with strict type checking
- Coordinate inputs validated against geographic bounds with `.isFinite` guards
- GPX and GeoJSON import validates coordinate ranges, enforces 50 MB file size limit and 50 000 point cap per feature
- XXE prevention on all XML parsers (`shouldResolveExternalEntities = false`)
- Knowledge pack downloads verified via SHA-256 checksum
- File paths sanitized against path traversal attacks

### Data Deletion (GDPR Art. 17)

In-app deletion clears every persistent and transient store the app owns. For the user-facing flow and rights description, see [PERSONVERN.md section 4](PERSONVERN.md#4-dine-rettigheter).

### Low Data Mode

Non-essential requests (species images, knowledge pack updates) are silently skipped when Low Data Mode is enabled. Core functionality is unaffected.

### Dependencies

All dependencies are open-source with active maintenance:
- MapLibre Native (BSD-2-Clause)
- MapLibreSwiftUI (ISC)
- NGA mgrs-ios (MIT)
- GRDB (MIT)

Pinned to specific versions via `Package.resolved`. No closed-source SDKs.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Current release |
| Previous minor | Security fixes only |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Email:** hei@tazk.no
2. **Subject:** `[SECURITY] Trakke iOS - Brief description`
3. **Include:** Steps to reproduce, potential impact, suggested fix if any

I will acknowledge receipt within 48 hours and provide an initial assessment within 7 days.

Please do not open public GitHub issues for security vulnerabilities.
