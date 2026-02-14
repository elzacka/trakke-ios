# Trakke iOS - Developer Context

## Project

Trakke is a Norwegian outdoor/hiking map app for iPhone and iPad. It uses Kartverket map data (topo + grayscale), not Apple Maps. All UI is in Norwegian.

**GitHub:** https://github.com/elzacka/trakke-ios
**PWA reference:** /Users/lene/dev/trakke_pwa (port algorithms and API logic from here)

## Current Date

Today is February 14, 2026. Always use this date when researching versions, APIs, and dependencies. Verify all tech stack versions are current.

## Tech Stack

- **Language:** Swift 6.2 (Xcode 26.2)
- **Target:** iOS 26.2 minimum, iPhone + iPad
- **UI:** SwiftUI with iOS 26 Liquid Glass design
- **Architecture:** MVVM with @Observable
- **Map:** MapLibre Native 6.23.0 (NOT Apple Maps/MapKit for rendering)
- **Persistence:** SwiftData
- **Charts:** Swift Charts (elevation profiles)
- **Networking:** URLSession with async/await
- **Coordinates:** NGA mgrs-ios 2.0.0, projections-ios 3.0.0

## SPM Dependencies

```
maplibre-gl-native-distribution  6.23.0
swiftui-dsl (MapLibreSwiftUI)    0.21.1
mgrs-ios                         2.0.0
projections-ios                  3.0.0
```

## Map Layers

Only Kartverket raster tiles (no satellite -- deferred due to Norge digitalt access requirement):

| Layer | URL |
|-------|-----|
| Topo (default) | `https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png` |
| Grayscale | `https://cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png` |

**Attribution:** `(c) Kartverket` (required on all map views).

## External APIs (EU/EEA only, no auth required)

| API | Endpoint |
|-----|----------|
| Place names | `ws.geonorge.no/stedsnavn/v1` |
| Addresses | `ws.geonorge.no/adresser/v1` |
| Elevation | `ws.geonorge.no/hoydedata/v1` |
| Weather | `api.met.no/weatherapi/locationforecast/2.0/compact` |
| Shelters | `raw.githubusercontent.com/dsb-norge/static-share/master/shelters.json` |
| POI (OSM) | `overpass-api.de` (rate-limited, 4 slots) |
| Cultural heritage | `api.ra.no` |

MET Norway requires User-Agent: `Trakke-iOS/1.0 hei@tazk.no`

## Architecture

```
View (SwiftUI) --> ViewModel (@Observable) --> Service (actor) --> API / SwiftData
```

- **Views:** SwiftUI views using sheets pattern
- **ViewModels:** @Observable classes, presentation logic
- **Services:** Swift actors for async network/data operations
- **Models:** SwiftData @Model for persistence, structs for API responses

## Conventions

- Norwegian (NO) for all UI strings
- No emojis in code, commits, or UI
- No Supabase (public APIs only)
- Privacy-first: Location When In Use only, no tracking, no IDFA
- EU/EEA data residency for all API calls
- WCAG 2.2 AA accessibility
- Test after each implementation phase
- Descriptive commit messages without emojis
- ES module patterns adapted to Swift (no global state, use actors)

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build (iOS 26.2 SDK uses iPhone 17 simulators)
xcodebuild -project Trakke.xcodeproj -scheme Trakke -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation build

# Test
xcodebuild -project Trakke.xcodeproj -scheme Trakke -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation test

# iPad build
xcodebuild -project Trakke.xcodeproj -scheme Trakke -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' -skipMacroValidation build
```

Note: `-skipMacroValidation` is needed for MapLibreSwiftUI and Mockable macros.

## Brand Colors

- Brand: #3e4533 (forest green)
- Brand light: #757d68
- Brand dark: #2e3326
- See `Color+Trakke.swift` for full palette

## POI Categories

| Category | Source | Color |
|----------|--------|-------|
| Tilfluktsrom | DSB | #fbbf24 |
| Huler | Overpass | #8b4513 |
| Observasjonstarn | Overpass | #4a5568 |
| Krigsminner | Overpass | #6b7280 |
| Gapahuk/vindskjul | Overpass | #b45309 |
| Kulturminner | Riksantikvaren | #8b7355 |

## Important Notes

- Do NOT use Apple Maps tile data. All map rendering via MapLibre + Kartverket.
- Do NOT push to GitHub without explicit confirmation.
- Do NOT delete databases or files without confirmation.
- Reference the PWA codebase for API call patterns and business logic.
