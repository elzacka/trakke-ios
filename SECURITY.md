# Security Policy

## Secure by Design

Tråkke follows Secure by Design principles aligned with the CIS (Center for Internet Security) framework. Security is embedded from the start - in the code, the configuration, and the defaults - not bolted on after deployment.

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

### Low Data Mode

APIClient supports an `optional` parameter that sets `allowsConstrainedNetworkAccess = false` on the URLRequest. Non-essential requests (Artsdatabanken species images, user guide remote fetch, knowledge pack catalog fetch, remote article fetch) are marked optional and silently skipped when the user has enabled Low Data Mode in iOS Settings. Core APIs (weather, search, routing, elevation, map tiles) remain unaffected.

APIClient retries on HTTP 429 (rate limited) with `Retry-After` header support, capped at 30 seconds. Only one retry is attempted before surfacing the error.

### Input Validation

- All API responses are decoded through Swift `Codable` with strict type checking
- Coordinate inputs are validated against geographic bounds
- Coordinate values are guarded with `.isFinite` checks in GPX import/export, BundledPOIService, POIService, ActivityTrackingService, SearchService (place name and address coordinate decoding), and ElevationService (input boundary validation) to reject NaN/Inf values
- GPX import additionally validates coordinate ranges (`-90...90` latitude, `-180...180` longitude) on trackpoints, route points, and waypoints
- Search inputs are sanitized before API calls
- XXE prevention (`shouldResolveExternalEntities = false`) on all XML parsers: GPX import (GPXImportService) and GML shelter parsing (POIService/ShelterGMLParser)
- GPX import enforces a 50 MB file size limit
- Weather cache evicts expired entries and is capped at 10 entries to prevent unbounded memory growth
- SearchService maintains a 5-minute TTL in-memory cache to reduce redundant API calls
- Valhalla routing responses are decoded through `Codable` with coordinate validation; polyline6 decoded coordinates are checked for `.isFinite`
- Route computation is rate-limited client-side (1.5 s minimum interval) to prevent abuse of the public Valhalla server
- Route computation cancellation is properly propagated (CancellationError not swallowed by rate limiter)
- `ISO8601DateFormatter` and `DateFormatter` instances in actor services (VarsomService, WeatherService, WaterTemperatureService) are actor-isolated instance properties, ensuring thread safety without `nonisolated(unsafe)`. `nonisolated(unsafe)` is used only for the `hourFormatter` static in `WeatherService.upcomingChange()` (a `nonisolated static` function) and a `PreferenceKey.defaultValue` in `UserGuideSheet`. VarsomService DateFormatters use POSIX locale to prevent locale-dependent parsing on non-Gregorian devices
- Remote article file paths sanitized via `sanitizeFileName()` in `RemoteArticleService`: strips path separators, allows only alphanumerics plus `-`, `_`, `.`; truncated to 120 characters. Prevents path traversal from malicious catalog entries
- Knowledge pack file paths use allowlist sanitization in PackStorageHelper: only `CharacterSet.alphanumerics` plus hyphens and underscores pass through; all other characters are stripped. Empty results fall back to `"unknown"`. This prevents path traversal via `..`, `/`, null bytes, or other special characters
- Knowledge pack downloads verified via SHA256 checksum (PackDownloadManager.verifyChecksum)
- Knowledge pack databases opened as read-only with `immutable=1` URI flag (prevents WAL/SHM file creation)
- Activity tracking rejects GPS points with horizontal accuracy > 50 m or negative accuracy
- No dynamic code execution or `eval` equivalents

### Data Protection

- SwiftData store protected with `NSFileProtectionComplete` (encrypted at rest, locked when device is locked)
- Logger output uses `privacy: .private` for all user data interpolations
- ModelContainer crash recovery: corrupted store is deleted and recreated rather than crashing
- GDPR Art. 17 "right to erasure": In-app "Slett alle data" in Preferences deletes all SwiftData records (including WAL/SHM journal files), offline map packs, MapLibre tile cache (`clearTileCache()`), knowledge packs, temp GPX files, clears URLCache (may contain coordinates from API requests), uses `removePersistentDomain` for complete UserDefaults erasure, and clears all in-memory service caches via an `onDeleteAllData` callback: WeatherService, WaterTemperatureService, AirQualityService, VarsomService, SearchService, RoutingService, ElevationService, POIService, BundledPOIService, and ArtsdatabankenImageService. Remote article cache (`RemoteArticleService`) is always cleared during data deletion, even when `knowledgeViewModel` is nil -- a fallback instance is created to ensure cache removal. This ensures no coordinate or location data survives in memory after deletion
- Remote article cache stored in Application Support/Trakke/articles/
- GPX temp files are cleaned up automatically after share sheet dismissal and at app launch (orphaned files from previous sessions)
- GPX temp export files are additionally protected with `NSFileProtectionComplete` (encrypted at rest)
- SwiftData save failures are surfaced to the user via alerts rather than silently logged
- Knowledge pack databases stored in Application Support with `NSFileProtectionComplete`
- Knowledge pack metadata files (`installed_packs.json`, `catalog.json`) written with `.completeFileProtection`
- Activity data (GPS tracks) stored in SwiftData with `NSFileProtectionComplete`
- Logger categories use `privacy: .private` consistently for all user data across all services (centralized categories in Logger+Trakke.swift, including dedicated `Logger.sos` for SOSService)
- Clipboard security: all coordinate copy actions (EmergencySheet, POIDetailSheet, WaypointDetailSheet, KnowledgeDetailSheet) use `UIPasteboard.setItems(_:options:)` with `"public.utf8-plain-text"` type and 5-minute expiration instead of persisting indefinitely
- Activity GPX export uses the same XML escaping, coordinate validation (`.isFinite`), and `NSFileProtectionComplete` as route GPX export

### External API: MET Air Quality

`AirQualityService` fetches air quality forecasts from MET Norway (`api.met.no/weatherapi/airqualityforecast/0.1/`). This is a Norwegian government service.

- Coordinates are truncated to 2 decimal places (~1.1 km precision) before transmission. Air quality data is per grunnkrets or kommune -- higher precision is not meaningful and would over-share location.
- Only truncated coordinates are sent; no user identity, no session data.
- Tries `areaclass=grunnkrets` first; falls back to `areaclass=kommune` on failure.
- Auth: None. Uses standard User-Agent header.
- Requests use `APIClient.session` (shared `URLSession` with 15 s request timeout and standard headers).
- `If-Modified-Since` / `Expires` header handling is implemented as required by MET API ToS.
- Responses are held in a single-entry in-memory cache (keyed on 2dp coordinate string); cache is cleared in "Slett alle data" via `AirQualityFetching.clearCache()`.
- Service uses the `AirQualityFetching` protocol for dependency injection and testability.
- The NAAF Pollenvarsel URL shown in the AQ card is a static HTTPS link opened via `UIApplication.open`. It is not used to transmit any app data.

### External API: Artsdatabanken

`ArtsdatabankenImageService` fetches species profile images for knowledge articles from Artsdatabanken (ai.artsdatabanken.no for the catalog, artsdatabanken.no/Media for images). This is a Norwegian government service.

- Only scientific species names (Latin binomials) are sent; no user data
- All requests go through `APIClient` with standard User-Agent
- Requests are marked `optional: true` (skipped in Low Data Mode)
- Images are held in a 30-entry LRU in-memory cache with eviction; cache cleared in "Slett alle data"
- The catalog (species name to media ID mapping) is fetched once per session and not persisted to disk
- Service uses the `ArtsdatabankenImageProviding` protocol for dependency injection and testability

### External API: GitHub Content (Remote Articles)

`RemoteArticleService` fetches article content updates from a GitHub content repository (`raw.githubusercontent.com`).

- No user data transmitted; only article file paths and checksums
- File paths from remote catalog are sanitized before disk operations (path traversal prevention)
- Requests routed through `APIClient.fetchData(optional: true)` -- skipped in Low Data Mode
- Cached in Application Support with GDPR deletion support
- Service uses the `RemoteArticleFetching` protocol for dependency injection and testability

### External API: NVE / Varsom

`VarsomService` fetches avalanche and flood warnings from NVE (Norges vassdrags- og energidirektorat), and the Bratthetskart WMS overlay provides slope steepness visualization. These are Norwegian government services under NLOD 2.0 license.

- **Avalanche API** (`api01.nve.no`): Coordinates are truncated to 4 decimal places (~11 m precision) before transmission. Only a single day's forecast is requested.
- **Flood API** (`api01.nve.no`): Only a date range is sent (county-level data returned). No coordinates or user data.
- **Bratthetskart WMS** (`nve.geodataonline.no`): Map overlay tiles requested by MapLibre's internal networking (bounding box only, same as other WMS overlays). No requests go through APIClient.
- Auth: None. All endpoints are unauthenticated.
- All APIClient requests use the standard User-Agent header
- Responses are held in a 1-hour in-memory cache; cache cleared in "Slett alle data"
- Service uses the `VarsomFetching` protocol for dependency injection and testability
- Static `DateFormatter` instances use POSIX locale to prevent locale-dependent parsing on non-Gregorian calendar devices

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
| 1.4.0   | Current release |
| 1.3.x   | Security fixes only |
| < 1.3   | End of life |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Email:** hei@tazk.no
2. **Subject:** `[SECURITY] Trakke iOS - Brief description`
3. **Include:** Steps to reproduce, potential impact, suggested fix if any

I will acknowledge receipt within 48 hours and provide an initial assessment within 7 days.

Please do not open public GitHub issues for security vulnerabilities.

## Security Checklist (Development)

- [ ] All network calls use HTTPS (ATS enforced)
- [ ] No hardcoded secrets or API keys in source code
- [ ] User location data never leaves the device
- [ ] SwiftData storage is device-local only
- [ ] No `UIWebView` or `WKWebView` with arbitrary content loading
- [ ] Input validation on all user-facing text fields
- [ ] Dependencies reviewed and pinned to specific versions
- [ ] Knowledge pack paths use allowlist sanitization against traversal attacks
- [ ] Remote article file paths sanitized against path traversal (sanitizeFileName)
- [ ] Knowledge databases opened read-only (immutable)
- [ ] Activity GPS data never leaves the device
- [ ] Pack download checksums verified before installation
- [ ] Clipboard copies use 5-minute expiry at all copy sites
- [ ] `nonisolated(unsafe)` used only for read-only static instances (hourFormatter, PreferenceKey.defaultValue)
- [ ] Non-essential network requests marked `optional` (Low Data Mode)
- [ ] All in-memory service caches cleared in "Slett alle data"
- [ ] Remote article cache cleared in GDPR deletion (including nil-knowledgeViewModel fallback)
- [ ] GDPR deletion removes WAL/SHM files and MapLibre tile cache
- [ ] Knowledge pack metadata files written with `.completeFileProtection`
- [ ] GPX import validates coordinate ranges and `.isFinite`
- [ ] GPX temp files cleaned up at app launch
- [ ] VarsomService truncates coordinates to 4dp before transmission
- [ ] AirQualityService truncates coordinates to 2dp before transmission
- [ ] AirQualityService uses APIClient.session (15s timeout enforced)
- [ ] VarsomService DateFormatters use POSIX locale
