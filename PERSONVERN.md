# Personvernerklæring for Tråkke

**Sist oppdatert:** 20. februar 2026
**Behandlingsansvarlig:** Tazk
**Kontakt:** hei@tazk.no

## Kort oppsummert

Tråkke lagrer all data lokalt på enheten din. Appen samler ikke inn personopplysninger, og sporer ikke bruken din. Ingen data sendes til appens systemer/servere eller til tredjeparter for analyse eller markedsføring.

---

## 1. Hva Tråkke gjør

Tråkke er en kartapp for friluftsliv i Norge. Appen viser topografiske kart fra Kartverket, lar deg søke etter steder, lage ruter, lagre veipunkter og laste ned kart for bruk uten internett. Appen har også kartlag for turruter og naturskog.

## 2. Hvilke data behandles

### 2.1 Data som lagres på enheten din

Tråkke lagrer følgende lokalt på enheten din via SwiftData:

- **Ruter og veipunkter** som du oppretter
- **Kartinnstillinger** (valgt kartlag, koordinatformat, preferanser)
- **Nedlastede kartområder** for offline-bruk
- **Midlertidige værdata** (buffer i opptil 2 timer)

Disse dataene forlater aldri enheten din og sendes ikke til appens servere/systemer eller noen andre.

### 2.2 Posisjon

Appen ber om tilgang til posisjonen din kun når du aktivt velger å vise den på kartet. Før du får iOS-dialogen, viser appen en kort forklaring på hvorfor posisjonstilgang er nyttig. Du kan avvise uten at iOS-dialogen vises. Posisjonen brukes bare til:

- Å vise hvor du er på kartet
- Å hente værmelding for posisjonen din

Posisjonsdata lagres ikke og sendes ikke videre, bortsett fra som beskrevet i punkt 3.

### 2.3 Data som ikke samles inn

- Ingen brukerkontoer eller innlogging
- Ingen informasjonskapsler (cookies)
- Ingen enhetsidentifikatorer (IDFA)
- Ingen bruksstatistikk eller analyse
- Ingen annonser eller annonseprofiler
- Ingen biometriske data

## 3. Eksterne tjenester

Appen kommuniserer med følgende tjenester for å gi deg kartdata, vær og annen funksjonalitet. Alle tjenester er innenfor EU/EØS.

| Tjeneste | Formål | Data som sendes | Land |
|----------|--------|-----------------|------|
| Kartverket (cache.kartverket.no) | Kartfliser | Kartkoordinater (zoom, x, y) | Norge |
| Kartverket WMS (wms.geonorge.no) | Turruter-kartlag | Kartområde (bounding box) | Norge |
| Geonorge Stedsnavn (ws.geonorge.no) | Stedsnavn-søk | Søketekst | Norge |
| Geonorge Adresser (ws.geonorge.no) | Adressesøk | Søketekst | Norge |
| Geonorge Høydedata (ws.geonorge.no) | Høydeprofiler | Koordinater langs ruten | Norge |
| Meteorologisk institutt (api.met.no) | Værmelding | Omtrentlig posisjon (4 desimaler, ca. 11 m nøyaktighet) | Norge |
| DSB (ogc.dsb.no) | Tilfluktsrom | Kartområde (bounding box) | Norge |
| Riksantikvaren (api.ra.no) | Kulturminner | Kartområde (bounding box) | Norge |
| Miljødirektoratet (image001.miljodirektoratet.no) | Naturskog-kartlag | Kartområde (bounding box) | Norge |

Interessepunkter fra OpenStreetMap (huler, observasjonstårn, krigsminner, gapahuker/vindskjul) er forhåndslastet i appen og krever ingen nettverkskommunikasjon.

Disse tjenestene mottar kun den tekniske informasjonen som er nødvendig for å levere data til appen. I tillegg sender appen en User-Agent-header med appens navn, versjon og utviklerens e-postadresse (hei@tazk.no) ved alle API-forespørsler. Dette er påkrevd av flere av tjenestene for identifikasjon, og inneholder ingen brukerdata.

### IP-adresse

Når appen henter data fra tjenestene over, vil din IP-adresse være synlig for disse tjenestene. Dette er en uunngåelig del av hvordan internett fungerer. Jeg har ingen kontroll over hvordan disse tjenestene behandler IP-adresser, men alle tjenestene er offentlige, norske eller europeiske tjenester underlagt GDPR.

## 4. Rettslig grunnlag

Behandlingen av data i Tråkke er basert på:

- **Berettiget interesse** (GDPR artikkel 6(1)(f)): Appen trenger å hente kartdata og værdata for å fungere. Dette er kjernefunksjonaliteten brukeren forventer.
- **Samtykke** (GDPR artikkel 6(1)(a)): Posisjonstilgang krever eksplisitt samtykke via iOS-dialogboksen.

## 5. Dine rettigheter

Siden Tråkke ikke samler inn personopplysninger, er de fleste rettigheter automatisk ivaretatt:

- **Innsyn:** Alle data er synlig i appen din.
- **Sletting:** Slett appen for å fjerne alle data. Du kan også slette enkeltdata (ruter, veipunkter, nedlastede kart) direkte i appen.
- **Dataportabilitet:** Ruter kan eksporteres som GPX-filer.
- **Begrenset behandling:** Du kan bruke appen uten å gi posisjonstilgang.

## 6. Datasikkerhet

- All kommunikasjon med eksterne tjenester skjer over HTTPS (kryptert)
- Data lagres lokalt på enheten med NSFileProtectionComplete og er beskyttet av sikkerhetsfunksjoner i iOS (enhetspassord, biometri)
- GPX-import validerer filstørrelse (maks 50 MB), blokkerer ondsinnet XML (XXE-beskyttelse) og avviser ugyldige koordinatverdier
- XML-parsing av tilfluktsromdata (GML) har samme XXE-beskyttelse
- Ingen data sendes til skytjenester
- Appen krever ingen brukerkontoer eller passord

## 7. Barn

Tråkke samler ikke inn personopplysninger og har ingen aldersgrense. Appen inneholder ingen kjøp, annonser eller sosiale funksjoner.

## 8. Endringer

Ved vesentlige endringer i denne erklæringen vil oppdatert versjon gjøres tilgjengelig i appen og via GitHub. Datoen øverst i dokumentet viser når erklæringen ble oppdatert sist.

## 9. Kontakt

Har du spørsmål om personvern i Tråkke?

- **E-post:** hei@tazk.no
- **Kildekode:** https://github.com/elzacka/trakke-ios

Du har også rett til å klage til Datatilsynet (datatilsynet.no) dersom du mener at behandlingen av personopplysninger ikke er i samsvar med regelverket.
