# REVIEW-FINDINGS

Open findings from code reviews. Check this file before every review to avoid rediscovering known items. Remove entries when fixed (note the fix commit).

Last full review: 2026-07-31 (all six iOS specialist agents, full codebase). All findings from that review are fixed and pushed. Current release candidate: **1.7.2 build 4**.

## Open

- **RELEASE (1.7.2 gate)** — Two fixes cannot be verified in the simulator and need a TestFlight run on device: the SOS torch continuing through a screen-lock cycle (with lydsignal both on and off), and the navigation Live Activity appearing on the lock screen and in the Dynamic Island. Diagnostic logging is in place for both — Console will name the cause if either still fails.
- **SOS-1 (P3, design decision needed)** — An active SOS signal can outlive its sheet (programmatic sheet swap, e.g. file import); there is no always-visible "SOS aktiv — stopp" affordance outside the sheet. Deliberate trade-off: an emergency signal is never stopped implicitly. A persistent on-map indicator/stop control while `sosViewModel.isActive` needs an ios-designer pass before implementing.
- **IPAD-1 (P3, blocked by Apple)** — iPad support cannot be removed (see "Device support and orientation" in [dev_only/CLAUDE.md](dev_only/CLAUDE.md)). The app therefore ships an iPhone layout on iPad. If it is ever worth improving, the lever is constraining widths on floating elements (`BottomNavBar`, sheet content) following the existing `maxWidth` caps in `TrakkeDialog`, `LocationPrimerView` and `EmptyStateView`. App Store Connect also requires a current 13" iPad screenshot.
- **TEST-2 (P3)** — SwiftData migration tests do not round-trip V1/V2-seeded stores to V3; lightweight migrations dropping `isVisible`/`category` values would ship undetected. Needs on-disk store fixtures (in-memory containers do not exercise migration).
- **QA-4 (P3)** — SOS interruption-recovery (`handleInterruptionEnded`) and Live Activity lifecycle lack direct automated tests. Both depend on AVAudioSession/ActivityKit behavior that only exists on device.
- **API-3 (P3, hygiene)** — `try!` NSRegularExpression literals in [SearchService.swift:110](Trakke/Services/SearchService.swift); a future typo crashes at static-init. Converting to compile-checked Swift Regex requires careful behavioral verification of the two patterns.
- **API-4 (P3, hygiene)** — Kartverket style JSON cache requires a manual `styleVersion` bump when the template changes ([KartverketTileService.swift:189](Trakke/Services/KartverketTileService.swift)); no guard detects a missed bump.
- **CI-2 (P3)** — No automated pre-flight for `NSSupportsLiveActivities` + widget entitlement consistency; only verified at archive time.

## Fixed and shipped in 1.7.2

**Build 4** (`88d2a50`) — portrait lock on iPhone via `UISupportedInterfaceOrientations`, with `~ipad` keeping all four orientations. iPad removal attempted and rejected by Apple; both constraints documented in `CLAUDE.md`, `project.yml` and `dev_only/CLAUDE.md`.

**Build 3** (`20100b9`) — eight device-reported bugs: Naturvernområder overlay (Miljødirektoratet moved to `wms.miljodirektoratet.no`), SOS audio session without `mixWithOthers` plus torch-failure logging, Live Activity diagnostics and a 10-minute stale window, default area name in the download sheet, info chips lifted above `BottomNavBar`, category lists unified into one card, "Nedlastede kart" tab renamed "Last ned kart", tap-to-dismiss keyboard. Plus a language pass over all 39 knowledge articles (216 em dashes replaced, four KI phrases rewritten) and image captions removed from "Lage bål".

**Build 2** (`3ed40ca`) — privacy manifest no longer declares location collection (matches "Ingen data samles inn" in ASC), "Vurder Tråkke i App Store" row in Info → Om, Kartverket licence corrected to CC BY 4.0 in app, README and `Kommuner.json`.

**Build 1** (`53de432`) — full-review fixes. P1: `startActivityRecording()` now starts location updates (recordings no longer silently lose all points); "Slett alle data" now clears `APIClient`'s private URLCache. P2: `NSFileProtectionComplete` applied explicitly to the store and WAL/SHM; background location during navigation disclosed in PERSONVERN/SECURITY; bathing-spot fetch respects Low Data Mode and retries; weather legend button expanded to 44 pt; heading updates throttled before the MainActor hop. P3: arrival fires for targets started 30–60 m away; SOS screen uses design tokens and respects Reduce Motion; orphaned `navigation.routeError*` strings removed; Live Activity error log switched to `.private`. Tests: SOS deadlock guard, GPS watchdog, short-start arrival, cache deletion; UI test target revived with real assertions and re-enabled in CI; CI simulator fallback fails loudly; deterministic SPM cache.

Earlier the same day: navigation Live Activity start race, GPS auto-pause and distance-filter freeze, camera re-engagement after gestures, SOS background keep-alive, audio-interruption recovery, generation counter and dismissal guards.
