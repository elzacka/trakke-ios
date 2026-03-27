# API Journal -- Trakke iOS

API reference and integration journal for Trakke v1.3.0.
Last updated: 27 March 2026.

---

## 1. API Overview

| API | Endpoint | Purpose | Auth | Rate Limit | Service File |
|-----|----------|---------|------|------------|--------------|
| Kartverket WMTS (topo) | `cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png` | Base map tiles | None | None known | `KartverketTileService.swift` |
| Kartverket WMTS (grayscale) | `cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png` | Alt base layer | None | None known | `KartverketTileService.swift` |
| Kartverket WMTS (toporaster) | `cache.kartverket.no/v1/wmts/1.0.0/toporaster/default/webmercator/{z}/{y}/{x}.png` | Alt base layer | None | None known | `KartverketTileService.swift` |
| Kartverket WMS (turruter) | `wms.geonorge.no/skwms1/wms.friluftsruter2` | Hiking trails overlay | None | None known | `KartverketTileService.swift` |
| Kartverket WMS (fjellskygge) | `wms.geonorge.no/skwms1/wms.fjellskygge` | Hillshading overlay | None | None known | `KartverketTileService.swift` |
| Geonorge Stedsnavn | `ws.geonorge.no/stedsnavn/v1/navn` | Place name search | None | None known | `SearchService.swift` |
| Geonorge Adresser | `ws.geonorge.no/adresser/v1/sok` | Address search | None | None known | `SearchService.swift` |
| Geonorge Hoydedata | `ws.geonorge.no/hoydedata/v1/punkt` | Elevation profiles | None | None known | `ElevationService.swift` |
| MET Locationforecast | `api.met.no/weatherapi/locationforecast/2.0/compact` | Weather forecast | None (User-Agent required) | Expires/If-Modified-Since | `WeatherService.swift` |
| MET Oceanforecast | `api.met.no/weatherapi/oceanforecast/2.0/complete` | Ocean temperature | None (User-Agent required) | Expires/If-Modified-Since | `WaterTemperatureService.swift` |
| Havvarsel-Frost | `havvarsel-frost.met.no/api/v1/obs/badevann/get` | Bathing spot temps | None (User-Agent sent) | None known | `WaterTemperatureService.swift` |
| DSB Shelters | `ogc.dsb.no/wfs.ashx` | Shelter locations (WFS/GML) | None | None known | `POIService.swift` |
| Riksantikvaren | `api.ra.no/brukerminner/collections/brukerminner/items` | Cultural heritage POI | None | Paginated (100/page, max 3 pages) | `POIService.swift` |
| Miljodirektoratet (naturvern) | `kart.miljodirektoratet.no/arcgis/services/vern/mapserver/WMSServer` | Protected areas overlay | None | None known | `KartverketTileService.swift` |
| Miljodirektoratet (naturskog) | `image001.miljodirektoratet.no/.../naturskog_v1/MapServer/export` | Forest overlays (3 layers) | None | None known | `KartverketTileService.swift` |
| FOSSGIS Valhalla | `valhalla1.openstreetmap.de/route` | Hiking route computation | None | Client-side 1.5s min interval | `RoutingService.swift` |
| Knowledge Catalog | `github.com/elzacka/trakke-ios/releases/download/knowledge-v3/catalog.json` | Knowledge pack catalog | None | None | `PackCatalogService.swift` |

All endpoints are HTTPS. No API keys are used anywhere in the app.

---

## 2. Common Headers

**User-Agent** (required by MET, recommended by Kartverket):

```
Trakke-iOS/{version} hei@tazk.no
```

Set dynamically from `CFBundleShortVersionString` via `APIClient.userAgent`. All requests routed through `APIClient` include this header automatically. `WeatherService` and `WaterTemperatureService` set it manually on their own `URLRequest` objects.

**If-Modified-Since / Expires** -- used by MET APIs (`WeatherService`, `WaterTemperatureService`). On 304 responses, cached data is kept and the expiry is refreshed from the new `Expires` header.

**Accept-Language** -- `nb-NO,nb;q=0.9,no;q=0.8,en;q=0.5` set on the shared `URLSession` configuration via `APIClient`.

**Accept-Encoding** -- `gzip, deflate, br` set globally on the shared `URLSession` configuration.

**ATS** -- App Transport Security enforced. No exceptions. All traffic is HTTPS.

---

## 3. Networking Infrastructure

### APIClient (`Trakke/Networking/APIClient.swift`)

Shared `URLSession` with:
- Request timeout: 15s
- Resource timeout: 60s
- `waitsForConnectivity: true`
- URLCache: 20 MB memory, 100 MB disk

Methods:
- `fetchData(url:timeout:additionalHeaders:)` -- raw data fetch with User-Agent, HTTP status validation, and single retry (1s delay) for timeouts, connection loss, and 5xx errors.
- `fetch(_:url:timeout:)` -- generic `Decodable` fetch built on `fetchData`.
- `buildURL(base:path:queryItems:)` -- URL construction helper.

### APIError (`Trakke/Networking/APIClient.swift`)

```swift
enum APIError: Error, LocalizedError, Sendable {
    case invalidURL          // "Ugyldig URL"
    case invalidResponse     // "Ugyldig respons"
    case httpError(statusCode: Int) // "HTTP-feil: {code}"
    case rateLimited         // "For mange forsok"
    case decodingError(String)     // "Dekodingsfeil: {detail}"
    case networkError(String)      // "Nettverksfeil: {detail}"
    case timeout             // "Tidsavbrudd"
}
```

All error descriptions are in Norwegian Bokmål. Localized via `String(localized:)` through `Localizable.xcstrings` (migrated from hardcoded strings).

### RoutingError (`Trakke/Services/RoutingService.swift`)

Separate error type for Valhalla routing: `.noRoute`, `.offline`, `.timeout`, `.rateLimited`, `.serverError(Int)`, `.decodingError`. Localized via `Localizable.xcstrings`.

### ConnectivityMonitor (`Trakke/Services/ConnectivityMonitor.swift`)

`@Observable` wrapper around `NWPathMonitor`. Exposes `isConnected`, `isConstrained` (Low Data Mode), and `isExpensive` (cellular). Used by the map view to display a "Frakoblet" chip when offline.

---

## 4. Caching Strategy

| Service | Cache Type | TTL | Max Entries | Eviction |
|---------|-----------|-----|-------------|----------|
| WeatherService | In-memory dict | Respects `Expires` header (fallback 2h) | 10 | Stale entries evicted first, then oldest |
| WaterTemperatureService | In-memory dict | Respects `Expires` header (fallback 1h) | 10 | Oldest evicted when full |
| POIService (live) | In-memory dict | 30 min | 50 | Stale evicted, then oldest |
| BundledPOIService | In-memory (static) | Permanent (loaded once at launch) | N/A | N/A |
| RoutingService | In-memory dict (route + cachedAt tuples) | 2 hours | 20 | Stale evicted inline, then FIFO |
| PackCatalogService | In-memory + on-disk JSON | 1 hour (in-memory), persistent (disk) | 1 | Replaced on refresh |
| PackQueryService (installed list) | In-memory | 30s | 1 | Replaced on refresh |
| ElevationService | In-memory dict (keyed by `first\|last\|count`, coords rounded to 4dp) | Permanent (static data) | 5 | FIFO |
| SearchService | None | N/A | N/A | N/A |

Tile caching is handled by MapLibre internally and by `URLCache` (100 MB disk) on the shared `URLSession`.

Overlay tile requests are made by MapLibre's networking stack, not through `APIClient`.

---

## 5. Data Licenses and Attribution

| Source | License | Attribution Required | Where Shown |
|--------|---------|---------------------|-------------|
| Kartverket | NLOD 2.0 | "(c) Kartverket" | Map view (always visible), InfoSheet |
| Miljodirektoratet | NLOD 2.0 | "(c) Miljodirektoratet" | Map view (when overlay active), InfoSheet |
| MET Norway | CC BY 4.0 | Credit near weather data | InfoSheet |
| Yr/NRK | CC BY 4.0 | Weather icon attribution | InfoSheet |
| OpenStreetMap contributors | ODbL | "(c) OpenStreetMap contributors" | InfoSheet |
| DSB | NLOD | Credit in app | InfoSheet |
| Riksantikvaren | NLOD | Credit in app | InfoSheet |
| Havvarsel-Frost | CC BY 4.0 | Credit in app | InfoSheet (under MET Norway) |
| FOSSGIS / Valhalla | MIT / ODbL | Credit in app | InfoSheet (Open Source section) |

Attribution is displayed in `InfoSheet.swift` (Settings > Om Trakke) with source name, description, and license badge. Map-level attribution is set via `MapConstants.attribution` and `OverlayLayer.attribution`.

---

## 6. Offline Behavior

- **Map tiles**: MapLibre caches viewed tiles. Pre-downloaded offline packs via `OfflineMapService`.
- **Weather/water temp**: Cached data served when offline. Cache respects Expires headers.
- **POI (bundled)**: Fully offline (caves, viewpoints, war memorials, wilderness shelters loaded from bundled GeoJSON).
- **POI (live)**: Cached for 30 min. Returns cached data on network failure.
- **Routing**: Falls back to compass-based navigation when Valhalla is unreachable.
- **Knowledge packs**: Downloaded SQLite databases queried locally via GRDB. Catalog falls back to on-disk copy.
- **Search/elevation**: Require network. No offline fallback.
- **Connectivity**: `ConnectivityMonitor` shows "Frakoblet" chip on map when offline.

---

## 7. Known Issues and Notes

- **Valhalla**: Community-hosted, no SLA. If unreachable, UI falls back to compass navigation. Client-side rate limit of 1.5s between requests.
- **Riksantikvaren**: API truncates responses at ~328 KB. Fetched in pages of 100 items, max 3 pages per viewport query. Uses fault-tolerant `SafeDecodable` wrapper.
- **MET APIs**: User-Agent is mandatory. Omission may result in 403. `If-Modified-Since` / `Expires` handling is a ToS requirement.
- **Kartverket WMTS**: Consolidation ongoing (2026). The `/v1/wmts/` endpoint structure is current. Monitor Kartverket Geonorge status page for URL changes.
- **DSB WFS**: XML parsing uses `shouldResolveExternalEntities = false` (XXE prevention). GML coordinate format is `lat lon` (not `lon lat`).
- **Knowledge packs**: Hosted on GitHub Releases. No authentication needed. Small catalog size makes rate limiting a non-concern.
- **Low Data Mode**: `ConnectivityMonitor.isConstrained` is exposed but not currently used to suppress fetches. The `URLSession` has `waitsForConnectivity: true` but does not set `allowsConstrainedNetworkAccess = false`.
- **Satellite tiles**: Deferred. Norge i bilder shutting down March 2026. Replacement requires Norge digitalt membership and GeoID token.

---

## 8. Request Flow

```
View -> ViewModel -> Service (actor) -> APIClient.fetchData() -> URLSession
                                     -> Manual URLRequest (MET services)
                                     -> MapLibre internal (tile overlays)
```

Services are Swift actors. ViewModels are `@Observable` classes on `@MainActor`. Network errors are surfaced to the user via ViewModel error properties or logged silently for best-effort fetches (water temperature).

`CancellationError` is propagated correctly through the actor chain -- not swallowed.

---

## 9. Security Notes

- No API keys in source code.
- All XML parsers disable external entity resolution (`shouldResolveExternalEntities = false`).
- Coordinate validation: `.isFinite` guards on all coordinate paths (GPX import/export, POI, Activity, SearchService, ElevationService).
- GPX import: 50 MB file size limit, temp files protected with `NSFileProtectionComplete`.
- GPX export: `GPXExportService.exportActivity(_:)` exports Activity records as GPX `<trk>` documents with `<ele>` and `<time>` per trackpoint. Temp files use `NSFileProtectionComplete`.
- Knowledge pack file paths sanitized via **allowlist** (`CharacterSet.alphanumerics` plus `-` and `_`; all other characters stripped; empty results fall back to `"unknown"`). Prevents path traversal.
- Clipboard expiration: Copied coordinates (EmergencySheet, POIDetailSheet, WaypointDetailSheet) use `UIPasteboard.setItems(_:options:)` with a **5-minute expiration** instead of persisting indefinitely.
- Date formatters: `nonisolated(unsafe)` static `ISO8601DateFormatter` instances removed from WeatherService and KnowledgeArticle. Replaced with local allocations (thread-safe under strict concurrency).
- Logger privacy: `WaterTemperatureService` error logs use `privacy: .private` to prevent coordinate leakage in system logs.
- Knowledge pack downloads report error state via `DownloadProgress.error` field and `isFailed` computed property.
