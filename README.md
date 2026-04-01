# Tråkke - Norsk friluftslivsapp for iOS

**Versjon 1.3.1** | iOS 26.0+ | Swift 6.2

Tråkke er en kartapp for iPhone som bruker kartdata fra Kartverket. Appen er laget for turgåere og friluftsfolk i Norge, med fokus på personvern og offline bruk.

## Funksjoner

- **Topografiske kart** fra Kartverket (topografisk, gråtone og toporaster/turkart)
- **GPS-posisjon** med sanntidsvisning på kartet
- **Stedsnavn- og adressesøk** via Kartverket
- **Offline kart** - last ned områder for bruk uten nett
- **Ruter og steder** - tegn, lagre, importer og eksporter som GPX
- **Interessepunkter** - tilfluktsrom, huler, utsiktspunkter, krigsminner, gapahuker/vindskjul, kulturminner
- **Kartlag** - turruter, 3D-relieff, naturvernområder og naturskog fra Kartverket og Miljødirektoratet
- **Høydeprofiler** med data fra Kartverkets høydemodell
- **Værmelding** fra Meteorologisk institutt
- **Vanntemperatur** - havtemperatur (MET Oceanforecast) og badevannstemperatur (Havvarsel-Frost) med ferskhetsstatus
- **Soloppgang og solnedgang** - dagslysinfo beregnet lokalt uten nett
- **Måleverktøy** for avstand og areal
- **Koordinatformater** - DD, DMS, DDM, UTM, MGRS
- **Navigasjon** - beregnet rute (via Valhalla) med sving-for-sving eller kompassretning til mål
- **Turregistrering** - GPS-basert sporregistrering med avstand, høydemeter og varighet
- **Eksport av turdata som GPX** - registrerte aktiviteter kan eksporteres som GPX-filer for dataportabilitet
- **Kunnskap og overlevelse** - nedlastbare artikler om friluftsliv med artsbilder, tilgjengelig uten nett
- **Nødkoordinater og SOS-signal** - vis posisjon i DD, UTM og MGRS, SOS-morsekode med lommelykt
- **Slett alle data** - slett alle ruter og steder du har lagt til kart du har lastet ned (via Innstillinger)

## Krav

- iOS 26.0 eller nyere
- iPhone eller iPad
- Xcode 26.3 (for utvikling)

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

**Forutsetninger:** Xcode 26.3, xcodegen (`brew install xcodegen`)

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
| Kunnskap (DB) | GRDB 7.4.0 |

## Personvern

Alle brukerdata lagres lokalt på enheten. Ingen sporing, ingen analyse. Se [PERSONVERN.md](PERSONVERN.md) for fullstendig personvernerklæring.

## Dokumentasjon

| Dokument                                                           | Innhold                        |
| ------------------------------------------------------------------ | ------------------------------ |
| [PERSONVERN.md](PERSONVERN.md)                                     | Personvernerklæring (GDPR)     |
| [SECURITY.md](SECURITY.md)                                         | Sikkerhetspolicy               |
| [CLAUDE.md](CLAUDE.md)                                             | Utviklerkontekst og arkitektur |

## Lisens

MIT License

## Attribusjon

- (c) Kartverket - kartdata, terrengdata, turruter og tjenester (NLOD 2.0)
- Mapzen Terrain Tiles - terrengmodell for 3D-relieff (CC BY 4.0)
- Meteorologisk institutt - vær- og havtemperaturdata (CC BY 4.0)
- Havvarsel-Frost - badevannsdata (CC BY 4.0)
- OpenStreetMap-bidragsytere - interessepunkter (ODbL)
- Riksantikvaren - kulturminnedata (NLOD)
- DSB - tilfluktsromdata (NLOD)
- Miljødirektoratet - naturvernområder og naturskogdata (NLOD 2.0)
- FOSSGIS / Valhalla - ruteberegning (MIT / ODbL)
- Artsdatabanken - artsbilder (CC BY 4.0)
