# Tråkke

En kartapp for iPhone, laget for tur i norsk natur. Bygget på Kartverkets kart. Fungerer offline. Lagrer ingenting om deg.

## Hva du får

**Kart fra Kartverket.** Topografisk, gråtone og turkart. 3D-relieff, bratthet, naturskog, naturvern og turruter som kartlag. Stedsnavn- og adressesøk. Last ned hele kommuner eller egne områder for offline bruk.

**Steder på kartet.** Tilfluktsrom, gapahuker, hytter, badeplasser, bålplasser, hengekøyeplasser, teltplasser, rasteplasser, fosser, huler, utsiktspunkter, kulturminner og krigsminner — slå av og på etter behov. Det meste fungerer offline.

**Tur og navigasjon.** Tegn ruter, lagre steder, registrer turer med GPS. Turer og ruter står i samme samling, med felles kategorier og filter. Sving-for-sving navigasjon eller kompassretning når dekningen svikter. Import og eksport av GPX og GeoJSON.

**Vær og varsler.** Værmelding, luftkvalitet og vanntemperatur fra Meteorologisk institutt. Snøskred og flom fra NVE/Varsom. Soloppgang og solnedgang.

**Trygghet på tur.** Nødnumre, koordinater i flere formater, SOS-signal med blink og lyd, måleverktøy og en kunnskapsbase med artikler om friluftsliv — alt tilgjengelig offline.

## Personvern

All data ligger på enheten din. Ingen kontoer, ingen sporing, ingen analyse. Posisjonstilgang kun når du bruker appen — og kun hvis du sier ja. Se [PERSONVERN.md](PERSONVERN.md) for detaljer.

## Dokumentasjon

| Dokument | For hvem |
|----------|----------|
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Brukere. Vises også i appen under «Informasjon». |
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklæring (GDPR). |
| [SECURITY.md](SECURITY.md) | Sikkerhetsforskere — arkitektur og rapportering av sårbarheter. |
| [dev_only/CLAUDE.md](dev_only/CLAUDE.md) | Utviklere — arkitektur og delsystemer. |

## Utvikling

```bash
brew install xcodegen
git clone https://github.com/elzacka/trakke-ios.git
cd trakke-ios
xcodegen generate
xcodebuild -project Trakke.xcodeproj -scheme Trakke \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -skipMacroValidation build
```

Krever Xcode 26.5 og iOS 26-simulator.

### Arkitektur

App-rota består av små, fokuserte enheter:

- `AppCoordinator` — eier ViewModels og navigasjon-/opptaks-tilstand
- `MapScreen` — kart med alle overlay-lag og gester
- `SheetHost` — sheet-ruting og FAB-meny
- `DialogHost` — dialoger
- `AppLifecycleModifier` — `onAppear`, `onChange` og `task`-hekter

`ContentView` setter disse sammen og holder seg under 100 linjer. Se [dev_only/CLAUDE.md](dev_only/CLAUDE.md) for utfyllende beskrivelse.

## Lisens

MIT.

## Kildedata

- Kartverket — kart, terreng og tjenester (NLOD 2.0)
- Mapzen Terrain Tiles — terrengmodell for 3D-relieff (CC BY 4.0)
- Miljødirektoratet — naturvern og naturskog (NLOD 2.0)
- FOSSGIS / Valhalla — ruteberegning (MIT / ODbL)
- Meteorologisk institutt — vær, havtemperatur og luftkvalitet (CC BY 4.0)
- Havvarsel-Frost — badevannsdata (CC BY 4.0)
- NVE / Varsom — snøskred- og flomvarsler (NLOD)
- Artsdatabanken — artsbilder (CC BY 4.0)
- Riksantikvaren — kulturminner (NLOD)
- DSB — tilfluktsrom (NLOD)
- Wikidata — fosser (CC0)
- UT.no/DNT, Statskog, fjellstyrer m.fl. — hytter
- OpenStreetMap-bidragsytere — øvrige kategorier (ODbL)

