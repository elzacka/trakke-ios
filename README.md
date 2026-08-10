# Tråkke

En kartapp for iPhone, laget for tur i norsk natur. Bygget på Kartverkets kart. Virker uten dekning. Lagrer ingenting om deg.

[Last ned Tråkke fra App Store](https://apps.apple.com/no/app/id6759306717). Appen er gratis, uten annonser og uten sporing.

## Hva du får

**Kart fra Kartverket.** Topografisk, gråtone og turkart. Bratthet, snøskred-aktsomhetsområder, naturskog, naturvern og turruter som kartlag. Stedsnavn- og adressesøk. Kompasset veksler kartet mellom nord opp og retning opp. Last ned hele kommuner eller egne områder for bruk uten nett.

**Steder på kartet.** 26 kategorier, gruppert etter hva de er til: friluftsliv (gapahuker, hytter, badeplasser, bålplasser, teltplasser, rasteplasser, hengekøyeplasser, huler, friluftsområder, fiskeplasser, klatrefelt, akebakker, skiheiser, turposter), ferdsel og fasiliteter (bruer og klopper, vadesteder, parkering, skiltpunkt, toaletter, servering), landskap (utsiktspunkter med fjelltopper, fosser), kulturarv (kulturminner, krigsminner, severdigheter) og beredskap (tilfluktsrom). Slå av og på etter behov. Alt virker uten dekning.

**Tur og navigasjon.** Tegn ruter, lagre steder, registrer turer med GPS. Turer og ruter står i samme samling, med felles kategorier og filter. Kompassretning til et valgt mål, også uten dekning. Under navigasjon vises avstand og retning på låseskjermen og i Dynamic Island. Turopptak fortsetter med skjermen låst, og har telefonen barometer, brukes det til høydemeterne. Import og eksport av GPX og GeoJSON.

**Uten å åpne appen.** Start og stopp turopptak og marker stedet du står på via Siri, Snarveier eller handlingsknappen.

**Vær og varsler.** Værmelding, luftkvalitet og vanntemperatur fra Meteorologisk institutt. Snøskred og flom fra NVE/Varsom. Soloppgang og solnedgang.

**Trygghet på tur.** Nødnumre, koordinater i flere formater, SOS-signal med blink og lyd, måleverktøy og en kunnskapsbase med artikler om friluftsliv, alt tilgjengelig uten nett.

## Personvern

Alle data ligger på enheten din. Ingen kontoer, ingen sporing, ingen analyse. Posisjonstilgang kun når du bruker appen, og kun hvis du sier ja. Se [PERSONVERN.md](PERSONVERN.md) for detaljer.

## Dokumentasjon

| Dokument | For hvem |
|----------|----------|
| [BRUKERVEILEDNING.md](BRUKERVEILEDNING.md) | Brukere. Vises også i appen under «Info». |
| [PERSONVERN.md](PERSONVERN.md) | Personvernerklæring (GDPR). Vises også i appen. |
| [SECURITY.md](SECURITY.md) | Sikkerhetsforskere: arkitektur og rapportering av sårbarheter. |

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

- `AppCoordinator`: eier ViewModels og navigasjon-/opptaks-tilstand
- `MapScreen`: kart med alle overlay-lag og gester
- `SheetHost`: sheet-ruting og FAB-meny
- `DialogHost`: dialoger
- `AppLifecycleModifier`: `onAppear`, `onChange` og `task`-hekter

`ContentView` setter disse sammen og holder seg under 100 linjer.

## Lisens

MIT.

## Kildedata

- Kartverket: kart, terreng og tjenester (CC BY 4.0)
- Miljødirektoratet: naturvern og naturskog (NLOD 2.0)
- Meteorologisk institutt: vær, luftkvalitet, hav- og badevannstemperatur (CC BY 4.0)
- Yr/NRK: værsymboler (CC BY 4.0)
- NVE / Varsom: snøskred- og flomvarsler (NLOD)
- Artsdatabanken: artsbilder (CC BY 4.0)
- Riksantikvaren: kulturminner (NLOD)
- DSB, via Geonorge: tilfluktsrom (NLOD)
- Wikidata: fosser (CC0)
- Wikimedia Commons: enkelte artsbilder (CC BY / CC BY-SA)
- UT.no/DNT, Statskog, fjellstyrer m.fl.: hytter, og bruer, vadesteder, parkering, skiltpunkt, toaletter, servering, friluftsområder, fiskeplasser, klatrefelt, akebakker, skiheiser, turposter og severdigheter
- Oslo kommune (Bymiljøetaten): badeplasser i Oslo (NLOD)
- OpenStreetMap-bidragsytere: øvrige kategorier (ODbL)

