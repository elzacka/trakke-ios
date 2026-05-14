# Tråkke - Norsk friluftslivsapp for iOS

Tråkke er en kartapp for iPhone som bruker kartdata fra Kartverket. Appen er laget for turgåere og friluftsfolk i Norge, med fokus på personvern og offline bruk.

## Funksjoner

**Kart og terreng**
- Topografiske kart fra Kartverket (topografisk, gråtone og turkart)
- Kartlag for turruter, 3D-relieff, bratthetskart, naturvernområder og naturskog
- Stedsnavn- og adressesøk
- Høydeprofiler
- Offline kart for hele kommuner eller egne områder

**Tur og navigasjon**
- Tegn og lagre ruter og steder med valgfri kategorigruppering
- Turregistrering med GPS-sporing, avstand og høydemeter
- Navigasjon med beregnet rute eller kompassretning
- Import og eksport av GPX- og GeoJSON-filer

**Vær og natur**
- Værmelding, luftkvalitet og vanntemperatur fra Meteorologisk institutt
- Snøskred- og flomvarsler fra NVE/Varsom
- Soloppgang og solnedgang
- Interessepunkter: tilfluktsrom, huler, kulturminner og mer

**Kunnskap og sikkerhet**
- Artikler om friluftsliv, vær, m.m. – tilgjengelig offline
- Nødkoordinater i flere formater og SOS-signal med lys og lyd
- Måleverktøy for avstand og areal

## Personvern

All data lagres lokalt. Ingen sporing, ingen analyse, ingen brukerkontoer. Personvernerklæringen vises i appen under «Informasjon» og er også tilgjengelig i [PERSONVERN.md](PERSONVERN.md).

## Dokumentasjon

| Dokument | Innhold |
|----------|---------|
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Hvordan bruke Tråkke. Vises også i appen under «Informasjon». |
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklæring (GDPR). Datakilder, rettsgrunnlag, dine rettigheter. |
| [SECURITY.md](SECURITY.md) | Teknisk sikkerhetsarkitektur og rapportering av sårbarheter. |
| [CLAUDE.md](CLAUDE.md) | Prosjektinstruksjoner for AI-agenter. |
| [dev_only/CLAUDE.md](dev_only/CLAUDE.md) | Detaljert arkitektur- og delsystem-referanse for utviklere. |

## Utvikling

Krever Xcode og [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/elzacka/trakke-ios.git
cd trakke-ios
xcodegen generate
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation build
```


## Lisens

MIT License

## Attribusjon

- Kartverket - kartdata, terrengdata og tjenester (NLOD 2.0)
- Meteorologisk institutt - vær-, havtemperatur- og luftkvalitetsdata (CC BY 4.0)
- Havvarsel-Frost - badevannsdata (CC BY 4.0)
- NVE / Varsom - snøskred- og flomvarsler (NLOD)
- OpenStreetMap-bidragsytere - interessepunkter (ODbL)
- Riksantikvaren - kulturminnedata (NLOD)
- DSB - tilfluktsromdata (NLOD)
- Miljødirektoratet - naturvernområder og naturskogdata (NLOD 2.0)
- Mapzen Terrain Tiles - terrengmodell for 3D-relieff (CC BY 4.0)
- Artsdatabanken - artsbilder (CC BY 4.0)
- FOSSGIS / Valhalla - ruteberegning (MIT / ODbL)
