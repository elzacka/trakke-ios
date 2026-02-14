# Trakke - Norsk friluftslivsapp for iOS

Trakke er en kartapp for iPhone og iPad som bruker kartdata fra Kartverket. Appen er laget for turgaere og friluftsfolk i Norge, med fokus pa personvern og offline-bruk.

## Funksjoner

- **Topografiske kart** fra Kartverket (farge og gratone)
- **GPS-posisjon** med sanntidsvisning pa kartet
- **Stedsnavn- og adressesok** via Kartverket
- **Frakoblede kart** - last ned omrader for bruk uten nett
- **Ruter og veipunkter** - tegn, lagre og eksporter som GPX
- **Interessepunkter** - tilfluktsrom, huler, observasjonstarn, krigsminner, gapahuker, kulturminner
- **Hoydeprofiler** med data fra Kartverkets hoydemodell
- **Vaermelding** fra Meteorologisk institutt
- **Maleverktoy** for avstand og areal
- **Koordinatformater** - DD, DMS, DDM, UTM, MGRS

## Krav

- iOS 26.2 eller nyere
- iPhone eller iPad
- Xcode 26.2 (for utvikling)

## Kom i gang (utvikling)

```bash
# Klon repoet
git clone https://github.com/elzacka/trakke-ios.git
cd trakke-ios

# Generer Xcode-prosjekt
xcodegen generate

# Bygg
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation build

# Kjor tester
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation test
```

**Forutsetninger:** Xcode 26.2, xcodegen (`brew install xcodegen`)

## Teknisk stack

| Komponent | Teknologi |
|-----------|-----------|
| Sprak | Swift 6.2 |
| UI | SwiftUI (iOS 26) |
| Arkitektur | MVVM med @Observable |
| Kart | MapLibre Native 6.23.0 |
| Lagring | SwiftData |
| Koordinater | NGA mgrs-ios 2.0.0 |

## Kartdata

Alle kartdata kommer fra Kartverket (kartverket.no). Appen bruker ikke kartdata fra Apple.

| Kartlag | Kilde |
|---------|-------|
| Topografisk (standard) | Kartverket WMTS |
| Gratone | Kartverket WMTS |

## Datakilder

| Data | Kilde | Land |
|------|-------|------|
| Kart | Kartverket | Norge |
| Stedsnavn | Geonorge | Norge |
| Adresser | Geonorge | Norge |
| Hoydedata | Geonorge | Norge |
| Tilfluktsrom | DSB | Norge |
| Vaer | Meteorologisk institutt | Norge |
| POI (OpenStreetMap) | Overpass API | Tyskland (EU) |
| Kulturminner | Riksantikvaren | Norge |

## Dokumentasjon

| Dokument | Innhold |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Utviklerkontekst, arkitektur, kodemonster |
| [SECURITY.md](SECURITY.md) | Sikkerhetspolicy og arkitektur |
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklaering (GDPR) |

## Personvern

Alle brukerdata lagres lokalt pa enheten. Ingen sporing, ingen informasjonskapsler, ingen analyse. Alle eksterne tjenester er innenfor EU/EOS.

Se [PERSONVERN.md](PERSONVERN.md) for fullstendig personvernerklaering.

## Lisens

MIT License

## Attribusjon

(c) Kartverket - kartdata og tjenester
