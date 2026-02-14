# Tråkke - Norsk friluftslivsapp for iOS

Tråkke er en kartapp for iPhone og iPad som bruker kartdata fra Kartverket. Appen er laget for turgåere og friluftsfolk i Norge, med fokus på personvern og offline-bruk.

## Funksjoner

- **Topografiske kart** fra Kartverket (farge og gråtone)
- **GPS-posisjon** med sanntidsvisning på kartet
- **Stedsnavn- og adressesøk** via Kartverket
- **Offline kart** - last ned områder for bruk uten nett
- **Ruter og veipunkter** - tegn, lagre og eksporter som GPX
- **Interessepunkter** - tilfluktsrom, huler, observasjonstårn, krigsminner, gapahuker, kulturminner
- **Høydeprofiler** med data fra Kartverkets høydemodell
- **Værmelding** fra Meteorologisk institutt
- **Måleverktøy** for avstand og areal
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

# Kjør tester
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation test
```

**Forutsetninger:** Xcode 26.2, xcodegen (`brew install xcodegen`)

## Teknisk stack

| Komponent | Teknologi |
|-----------|-----------|
| Språk | Swift 6.2 |
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
| Gråtone | Kartverket WMTS |

## Datakilder

| Data | Kilde | Land |
|------|-------|------|
| Kart | Kartverket | Norge |
| Stedsnavn | Geonorge | Norge |
| Adresser | Geonorge | Norge |
| Høydedata | Geonorge | Norge |
| Tilfluktsrom | DSB | Norge |
| Vær | Meteorologisk institutt | Norge |
| POI (OpenStreetMap) | Overpass API | Tyskland (EU) |
| Kulturminner | Riksantikvaren | Norge |

## Dokumentasjon

| Dokument | Innhold |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Utviklerkontekst, arkitektur, kodemønster |
| [SECURITY.md](SECURITY.md) | Sikkerhetspolicy og arkitektur |
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklæring (GDPR) |

## Personvern

Alle brukerdata lagres lokalt på enheten. Ingen sporing, ingen informasjonskapsler, ingen analyse. Alle eksterne tjenester er innenfor EU/EØS.

Se [PERSONVERN.md](PERSONVERN.md) for fullstendig personvernerklæring.

## Lisens

MIT License

## Attribusjon

(c) Kartverket - kartdata og tjenester
