# REVIEW-FINDINGS

Open findings from code reviews. Check this file before every review to avoid rediscovering known items. Remove entries when fixed (note the fix commit).

Last full review: 2026-07-31 (all six iOS specialist agents, full codebase). Nearly all findings were fixed the same day in the working tree (pending commit) — see "Fixed" below. Only the items in "Open" remain.

## Open

- **SOS-1 (P3, design decision needed)** — An active SOS signal can outlive its sheet (programmatic sheet swap, e.g. file import); there is no always-visible "SOS aktiv — stopp" affordance outside the sheet. Deliberate trade-off: an emergency signal is never stopped implicitly. A persistent on-map indicator/stop control while `sosViewModel.isActive` needs an ios-designer pass before implementing.
- **TEST-2 (P3)** — SwiftData migration tests do not round-trip V1/V2-seeded stores to V3; lightweight migrations dropping `isVisible`/`category` values would ship undetected. Needs on-disk store fixtures (in-memory containers do not exercise migration).
- **API-3 (P3, hygiene)** — `try!` NSRegularExpression literals in [SearchService.swift:110](Trakke/Services/SearchService.swift); a future typo crashes at static-init. Converting to compile-checked Swift Regex requires careful behavioral verification of the two patterns.
- **API-4 (P3, hygiene)** — Kartverket style JSON cache requires a manual `styleVersion` bump when the template changes ([KartverketTileService.swift:189](Trakke/Services/KartverketTileService.swift)); no guard detects a missed bump.
- **CI-2 (P3)** — No automated pre-flight for `NSSupportsLiveActivities` + widget entitlement consistency; only verified at archive time.
- **QA-4 (P3)** — SOS interruption-recovery (`handleInterruptionEnded`) and Live Activity lifecycle still lack direct automated tests (deadlock regression and watchdog are now covered; AVAudioSession/ActivityKit behavior needs on-device verification).
- **RELEASE (v1.7.2 gate)** — Manual on-device checks required before shipping: torch continues through a lock-screen cycle (both lydsignal on and off), SOS tone resumes after a real phone call, Live Activity appears on lock screen/Dynamic Island, and a recording started without prior locate-tap accumulates points.

## Fixed 2026-07-31 (pending commit — do not re-report)

Full-review fixes:

- **REC-1 (P1)** — `startActivityRecording()` now starts location updates; recordings no longer silently lose all points when started without prior tracking.
- **GDPR-1 (P1)** — "Slett alle data" now clears `APIClient`'s private URLCache via `APIClient.clearCache()`. The cache got its own instance reference (`session.configuration` returns a copy) and its own directory (removal in the shared default directory proved unreliable — verified by regression test).
- **PRIV-1 (P2)** — PERSONVERN.md and SECURITY.md now disclose background location during active navigation (locked screen, visible indicator, When-In-Use unchanged).
- **PRIV-2 (P2)** — `NSFileProtectionComplete` now explicitly applied to `Trakke.store` + WAL/SHM at launch, and to MapLibre's cache directory (docs and code now agree).
- **QA-1/QA-3 (P2, partial)** — New regression tests: SOS rapid-toggle deadlock guard, GPS watchdog timeout + recovery (injectable per-instance timeout), arrival from short start, APIClient cache deletion. Arrival test no longer swallows sleep cancellation; bearing symmetry tolerance tightened 5° → 0.5°.
- **QA-2 (P2)** — UI test target revived: real assertions (foreground state, map attribution "© Kartverket", Meny button), added to the scheme's test action, and CI no longer excludes it.
- **API-1 (P2)** — `fetchBathingSpots` now skips Low Data Mode and retries once on timeout/connection loss (TLS-backoff preserved).
- **UX-1 (P2)** — Weather legend info button expanded to 44 pt.
- **PERF-1 (P2)** — Heading updates throttled in the nonisolated delegate before the MainActor hop.
- **NAV-1 (P3)** — Arrival now also fires for targets started 30-60 m away (max-observed-distance gate replaces start-distance gate).
- **UX-2 (P3)** — SOS screen uses `Color.Trakke.textInverse`/`surface` tokens; SOS crossfade respects Reduce Motion; `eye.slash` uses `textSoft`; BottomNavBar uses `trakkeFABShadow()`; "Fremme!" → "Fremme".
- **L10N-1 (P3)** — Orphaned `navigation.routeError*` strings removed.
- **SEC-2 (P3)** — Live Activity error log switched to `privacy: .private`.
- **API-2 (P3, partial)** — Kulturminner decoder hoisted out of pagination loop; `WeatherAdvice` shared `DateFormatter` replaced with per-call helper.
- **CI-1 (P3)** — Simulator fallback now fails with a clear error instead of guessing a device name; SPM cache uses a deterministic `-clonedSourcePackagesDirPath`; version bumped to 1.7.2 (build 1) in `project.yml`.
- **DOC-1 (P3)** — CLAUDE.md version corrected; SECURITY.md cross-reference §4 → §5; BRUKERVEILEDNING SOS chapter documents lock-screen behavior and torchless devices, "f.eks. via AirDrop" fixed; dev_only/CLAUDE.md location-routing section updated; API-JOURNAL.md purged of removed Valhalla/Mapzen integrations.

Earlier same day (v1.7.2 base): navigation Live Activity race, GPS auto-pause/distance-filter freeze, camera re-engagement after gestures, SOS background keep-alive/interruption recovery/generation counter/dismissal guards.
