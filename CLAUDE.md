# Tråkke iOS

Norwegian outdoor/hiking map app for iPhone. Uses Kartverket maps (not Apple Maps). All UI in Norwegian Bokmål.

## Critical naming rules

- **Tråkke** (with å) — display name, GPX exports, UI text, prose, commit messages, all user-visible text
- **Trakke** (ASCII) — code identifiers, file paths, bundle IDs, User-Agent only
- Always use correct **æ, ø, å** in Norwegian text. Verify before output.

## Project context

- **Repo**: https://github.com/elzacka/trakke-ios
- **Current version**: 1.4.0 (build 4) — set in `project.yml`
- **Target**: iOS 26.0+, Swift 6.3, Xcode 26.5
- **PWA reference**: `/Users/lene/dev/trakke_pwa` — reference ONLY when explicitly instructed

See [dev_only/CLAUDE.md](dev_only/CLAUDE.md) for detailed architecture, services, and subsystem documentation.

## Build commands

Prerequisite: `brew install xcodegen`. The Xcode project is generated from `project.yml` — never edit `.xcodeproj` directly.

```bash
xcodegen generate
xcodebuild -project Trakke.xcodeproj -scheme Trakke -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation build
xcodebuild -project Trakke.xcodeproj -scheme Trakke -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation test
```

`-skipMacroValidation` is required for MapLibreSwiftUI macros.

## Non-obvious conventions

- **No Apple Maps** for rendering — all map tiles via MapLibre Native + Kartverket
- **No Supabase** — all APIs are unauthenticated public services
- **No emojis** in code, commits, or UI
- **Light mode only** — `.preferredColorScheme(.light)` enforced; do not add dark mode
- **No blue text** — never use SwiftUI default blue tint. Use `Color.Trakke.brand` (#3e4533) and `.tint(Color.Trakke.brand)`
- **No tracking, no IDFA, no analytics** — Location When In Use only
- **EU/EEA data residency** for API calls (exceptions: AWS terrain tiles, GitHub knowledge packs — no user data)
- **WCAG 2.1 AA** mandatory (Norwegian law + EAA from June 2025)
- **mgrs-ios** uses local override (`LocalPackages/mgrs-ios`) — iOS 26.4 SDK compiler fix; do not revert without verifying upstream

## Hard rules (do NOT)

- Do NOT push to GitHub without explicit confirmation
- Do NOT delete databases, files, or directories without confirmation
- Do NOT change deployed `SwiftData VersionedSchema.versionIdentifier` values — breaks user data on update
- Do NOT reference or base decisions on the PWA codebase unless explicitly instructed
- Do NOT include time estimates in any output (no "X timer", "X min", "X dager", "X uker"; no "Innsats"/"Effort"/"Estimat"/"Tidsbruk" columns or labels). AI executes — duration estimates are noise. Use P1/P2/P3 or liten/middels/stor for prioritization instead.

## iOS specialist agents

For code review, security, design, API integration, and release work, use the specialist agents in `~/.claude/agents/`: `ios-project-lead`, `ios-expert`, `ios-designer`, `ios-data-and-api-expert`, `ios-security-and-privacy-expert`, `ios-qa-and-release`. See `~/.claude/rules/ios-shared.md` for shared conventions.
