# Personvernerklaering for Trakke

**Sist oppdatert:** 14. februar 2026
**Behandlingsansvarlig:** tazk.no
**Kontakt:** hei@tazk.no

## Kort oppsummert

Trakke lagrer all data lokalt pa din enhet. Vi samler ikke inn personopplysninger, og vi sporer ikke bruken din. Ingen data sendes til oss eller til tredjeparter for analyse eller markedsforing.

---

## 1. Hva Trakke gjor

Trakke er en kartapp for friluftsliv i Norge. Appen viser topografiske kart fra Kartverket, lar deg soke etter steder, lage ruter, lagre veipunkter og laste ned kart for bruk uten internett.

## 2. Hvilke data behandles

### 2.1 Data som lagres pa enheten din

Trakke lagrer folgende lokalt pa din iPhone eller iPad via SwiftData:

- **Ruter og veipunkter** du oppretter
- **Kartinnstillinger** (valgt kartlag, koordinatformat, preferanser)
- **Nedlastede kartomrader** for offline-bruk
- **Midlertidig vaerdata** (buffer i opptil 2 timer)

Disse dataene forlater aldri enheten din og sendes ikke til oss eller noen andre.

### 2.2 Posisjon

Appen ber om tilgang til posisjonen din kun nar du aktivt velger a vise den pa kartet. Posisjonen brukes bare til:

- A vise hvor du er pa kartet
- A hente vaermelding for din posisjon

Posisjonsdata lagres ikke og sendes ikke videre, bortsett fra som beskrevet i punkt 3.

### 2.3 Data vi ikke samler inn

- Ingen brukerkontoer eller innlogging
- Ingen informasjonskapsler (cookies)
- Ingen enhetsidentifikatorer (IDFA)
- Ingen bruksstatistikk eller analyse
- Ingen annonser eller annonseprofiler
- Ingen biometriske data

## 3. Eksterne tjenester

Appen kommuniserer med folgende tjenester for a gi deg kartdata, vaer og annen funksjonalitet. Alle tjenester er innenfor EU/EOS.

| Tjeneste | Formal | Data som sendes | Land |
|----------|--------|-----------------|------|
| Kartverket (cache.kartverket.no) | Kartfliser | Kartkoordinater (zoom, x, y) | Norge |
| Geonorge Stedsnavn (ws.geonorge.no) | Stedsnavn-sok | Soketekst | Norge |
| Geonorge Adresser (ws.geonorge.no) | Adressesok | Soketekst | Norge |
| Geonorge Hoydedata (ws.geonorge.no) | Hoydeprofiler | Koordinater langs ruten | Norge |
| Meteorologisk institutt (api.met.no) | Vaermelding | Omtrentlig posisjon (4 desimaler, ca. 11 m noeyaktighet) | Norge |
| DSB (github.com/dsb-norge) | Tilfluktsrom | Ingen (statisk nedlasting) | Norge |
| Overpass API (overpass-api.de) | Interessepunkter fra OpenStreetMap | Kartomrade (bounding box) | Tyskland |
| Riksantikvaren (api.ra.no) | Kulturminner | Kartomrade (bounding box) | Norge |

Disse tjenestene mottar kun den tekniske informasjonen som er nodvendig for a levere data til appen. Ingen personopplysninger sendes.

### IP-adresse

Nar appen henter data fra tjenestene over, vil din IP-adresse vaere synlig for disse tjenestene. Dette er en uunngaelig del av hvordan internett fungerer. Vi har ingen kontroll over hvordan disse tjenestene behandler IP-adresser, men alle tjenestene er offentlige, norske eller europeiske tjenester underlagt GDPR.

## 4. Rettslig grunnlag

Behandlingen av data i Trakke er basert pa:

- **Berettiget interesse** (GDPR artikkel 6(1)(f)): Appen trenger a hente kartdata og vaerdata for a fungere. Dette er kjernefunksjonaliteten brukeren forventer.
- **Samtykke** (GDPR artikkel 6(1)(a)): Posisjonstilgang krever eksplisitt samtykke via iOS-dialogboksen.

## 5. Dine rettigheter

Siden Trakke ikke samler inn personopplysninger, er de fleste rettigheter automatisk ivaretatt:

- **Innsyn:** All data er synlig i appen din.
- **Sletting:** Slett appen for a fjerne alle data. Du kan ogsa slette enkeltdata (ruter, veipunkter, nedlastede kart) direkte i appen.
- **Dataportabilitet:** Ruter kan eksporteres som GPX-filer.
- **Begrensning av behandling:** Du kan bruke appen uten a gi posisjonstilgang.

## 6. Datasikkerhet

- All kommunikasjon med eksterne tjenester skjer over HTTPS (kryptert)
- Data lagres lokalt pa enheten og er beskyttet av iOS-sikkerhet (enhetspassord, biometri)
- Ingen data sendes til skytjenester
- Appen krever ingen brukerkontoer eller passord

## 7. Barn

Trakke samler ikke inn personopplysninger og har ingen aldersgrense. Appen inneholder ingen kjop, annonser eller sosiale funksjoner.

## 8. Endringer

Ved vesentlige endringer i denne erklaringen vil oppdatert versjon gjores tilgjengelig i appen og pa GitHub. Datoen overst i dokumentet viser nar erklaringen sist ble oppdatert.

## 9. Kontakt

Har du sporsmol om personvern i Trakke?

- **E-post:** hei@tazk.no
- **Kildekode:** https://github.com/elzacka/trakke-ios

Du har ogsa rett til a klage til Datatilsynet (datatilsynet.no) dersom du mener at behandlingen av personopplysninger ikke er i samsvar med regelverket.
