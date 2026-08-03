# Tråkke iOS

@~/.claude/rules/ios-shared.md
@dev_only/CLAUDE.md

Norwegian outdoor map app for iPhone. Built on Kartverket maps (not Apple Maps). All UI in Norwegian Bokmål.

## Naming

- **Tråkke** (with å) — display name, GPX exports, UI text, prose, commit messages, all user-visible text
- **Trakke** (ASCII) — code identifiers, file paths, bundle IDs, User-Agent
- Always use **æ, ø, å** in Norwegian text. Verify before output.

## Project

- **Repo**: https://github.com/elzacka/trakke-ios
- **Version**: 1.7.2 (build 6) — set in `project.yml`
- **Target**: iOS 26.0+, Swift 6.3, Xcode 26.5
- **PWA reference**: `/Users/lene/dev/trakke_pwa` — reference ONLY when explicitly instructed

Architecture and subsystem details: [dev_only/CLAUDE.md](dev_only/CLAUDE.md).

## Build

Prerequisite: `brew install xcodegen`. The Xcode project is generated from `project.yml` — never edit `.xcodeproj` directly.

```bash
xcodegen generate
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation build
```

`-skipMacroValidation` is required for MapLibreSwiftUI macros.

## Non-obvious conventions

- **No Apple Maps** — all rendering via MapLibre + Kartverket
- **No Supabase** — all APIs are unauthenticated public services
- **No emojis** in code, commits, or UI
- **Light mode only** — `.preferredColorScheme(.light)` enforced
- **No blue text** — use `Color.Trakke.brand` (#3e4533) and `.tint(Color.Trakke.brand)`
- **No tracking, no IDFA, no analytics** — Location When In Use only
- **EU/EEA data residency** for API calls (exception: GitHub knowledge packs — no user data sent)
- **WCAG 2.2 AA** mandatory (Norwegian law + EAA from June 2025)
- **Coordinate formats**: DD, DMS, UTM (EUREF89 sone 33). MGRS was removed — the NGA `mgrs-ios` dependency is gone
- **iPhone-only by design, iPad by accident** — every layout decision targets iPhone. `TARGETED_DEVICE_FAMILY` is `"1,2"` and **cannot be narrowed**: Apple rejects updates supporting fewer devices than the published version (QA1623). Attempted and rejected at upload on 1 August 2026. Real iPhone-only would need a new bundle ID, losing reviews and existing users. Consequence: App Store Connect requires a 13" iPad screenshot, and `ShareSheet`'s popover anchor plus the `horizontalSizeClass` branch in `ElevationProfileView` must stay
- **Portrait only on iPhone** — `UISupportedInterfaceOrientations` lists portrait alone (since 1.7.2); no view has a landscape-adaptive layout. `UISupportedInterfaceOrientations~ipad` must keep all four: while iPad support exists, Apple rejects the upload without them ("you need to include all of the … orientations to support iPad multitasking"). Verified by a rejected upload on 1 August 2026

## Hard rules

- Do NOT push to GitHub without explicit confirmation
- Do NOT delete databases, files, or directories without confirmation
- Do NOT change deployed `SwiftData VersionedSchema.versionIdentifier` values — breaks user data on update
- Do NOT reference or base decisions on the PWA codebase unless explicitly instructed

## iOS specialist agents

Use the agents in `~/.claude/agents/` for code review, security, design, API work, and release: `ios-project-lead`, `ios-expert`, `ios-designer`, `ios-data-and-api-expert`, `ios-security-and-privacy-expert`, `ios-qa-and-release`. Shared conventions: `~/.claude/rules/ios-shared.md`.
