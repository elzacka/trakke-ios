# Tråkke - Norsk friluftslivsapp for iOS

**Versjon 1.1.0** | iOS 26.0+ | Swift 6.2

Tråkke er en kartapp for iPhone og iPad som bruker kartdata fra Kartverket. Appen er laget for turgåere og friluftsfolk i Norge, med fokus på personvern og offline-bruk.

## Funksjoner

- **Topografiske kart** fra Kartverket (farge og gråtone)
- **GPS-posisjon** med sanntidsvisning på kartet
- **Stedsnavn- og adressesøk** via Kartverket
- **Offline kart** - last ned områder for bruk uten nett
- **Ruter og veipunkter** - tegn, lagre, importer og eksporter som GPX
- **Interessepunkter** - tilfluktsrom, huler, utsiktspunkter, krigsminner, gapahuker/vindskjul, kulturminner
- **Kartlag** - turruter (Kartverket) og naturskog (Miljødirektoratet)
- **Høydeprofiler** med data fra Kartverkets høydemodell
- **Værmelding** fra Meteorologisk institutt
- **Måleverktøy** for avstand og areal
- **Koordinatformater** - DD, DMS, DDM, UTM, MGRS
- **Navigasjon** - beregnet rute (via Valhalla) med sving-for-sving eller kompassretning til mål
- **Slett alle data** - GDPR-sletting av alle ruter, veipunkter og nedlastede kart (innstillinger)

## Krav

- iOS 26.0 eller nyere
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
| UI | SwiftUI (iOS 26, Liquid Glass) |
| Arkitektur | MVVM med @Observable |
| Kart | MapLibre Native 6.23.0 |
| Lagring | SwiftData |
| Koordinater | NGA mgrs-ios 2.0.0 |
| Grafer | Swift Charts |

## Kartdata

Alle kartdata kommer fra Kartverket (kartverket.no). Appen bruker ikke kartdata fra Apple.

| Kartlag | Kilde |
|---------|-------|
| Topografisk (standard) | Kartverket WMTS |
| Gråtone | Kartverket WMTS |
| Turruter (overlay) | Kartverket WMS |
| Naturskog (overlay) | Miljødirektoratet ArcGIS REST |

## Datakilder

Alle tjenester er innenfor EU/EØS. Ingen autentisering kreves.

| Data | Kilde | Land |
|------|-------|------|
| Kart | Kartverket | Norge |
| Stedsnavn | Geonorge | Norge |
| Adresser | Geonorge | Norge |
| Høydedata | Geonorge | Norge |
| Tilfluktsrom | DSB | Norge |
| Vær | Meteorologisk institutt (CC BY 4.0) | Norge |
| POI (OpenStreetMap) | Forhåndslastet fra Overpass API (ODbL) | Lokalt i appen |
| Kulturminner | Riksantikvaren | Norge |
| Turruter | Kartverket WMS (NLOD 2.0) | Norge |
| Naturskog | Miljødirektoratet ArcGIS REST (NLOD 2.0) | Norge |
| Ruting | FOSSGIS Valhalla (ODbL / MIT) | Tyskland (EU) |

## Personvern

Alle brukerdata lagres lokalt på enheten. Ingen sporing, ingen informasjonskapsler, ingen analyse. Alle eksterne tjenester er innenfor EU/EØS.

Se [PERSONVERN.md](PERSONVERN.md) for fullstendig personvernerklæring.

## Dokumentasjon

| Dokument | Innhold |
|----------|---------|
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklæring (GDPR) |
| [SECURITY.md](SECURITY.md) | Sikkerhetspolicy og arkitektur |
| [CLAUDE.md](CLAUDE.md) | Utviklerkontekst og arkitektur |
| [API-JOURNAL.md](API-JOURNAL.md) | API-referanse og feilsøking |
| [APP-STORE-CHECKLIST.md](APP-STORE-CHECKLIST.md) | App Store-sjekkliste |

## Lisens

MIT License

## Attribusjon

- (c) Kartverket - kartdata, turruter og tjenester (NLOD 2.0)
- Meteorologisk institutt - værdata (CC BY 4.0)
- OpenStreetMap-bidragsytere - interessepunkter (ODbL)
- Riksantikvaren - kulturminnedata (NLOD)
- DSB - tilfluktsromdata (NLOD)
- Miljødirektoratet - naturskogdata (NLOD 2.0)
- FOSSGIS / Valhalla - ruteberegning (MIT / ODbL)
