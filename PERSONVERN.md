# Personvernerklæring for Tråkke

**Sist oppdatert:** 30. mars 2026
**Behandlingsansvarlig:** Tazk
**Kontakt:** hei@tazk.no

## Kort oppsummert

Tråkke lagrer all data lokalt på enheten din. Appen samler ikke inn personopplysninger, og sporer ikke bruken din. Ingen data sendes til appens systemer eller til tredjeparter for analyse eller markedsføring.

---

## 1. Hvilke data behandles

### 1.1 Data som lagres på enheten din

Tråkke lagrer følgende lokalt:

- **Ruter og steder** som du oppretter
- **Turdata** (GPS-spor, avstand, høydemeter) fra registrerte turer
- **Kartinnstillinger** (valgt kartlag, koordinatformat, preferanser)
- **Nedlastede kartområder** for offline-bruk
- **Kunnskapspakker** for offline-bruk
- **Midlertidige værdata** (buffer i opptil 2 timer)

Disse dataene forlater aldri enheten din.

### 1.2 Posisjon

Appen ber om tilgang til posisjonen din kun når du aktivt velger å vise den på kartet. Før du får iOS-dialogen, viser appen en kort forklaring på hvorfor posisjonstilgang er nyttig. Du kan avvise uten at iOS-dialogen vises.

Posisjonen brukes til å vise deg på kartet, hente værmelding, beregne turruter og registrere GPS-spor. Posisjonsdata lagres kun lokalt på enheten.

### 1.3 Data som ikke samles inn

Ingen brukerkontoer, informasjonskapsler, enhetsidentifikatorer (IDFA), bruksstatistikk, annonser eller biometriske data.

## 2. Eksterne tjenester

Appen henter data fra følgende tjenester. Alle tjenester er norske eller europeiske, med unntak av terrengdata (AWS) og kunnskapspakker (GitHub) som ikke inneholder brukerdata.

| Tjeneste | Formål | Data som sendes | Land |
|----------|--------|-----------------|------|
| Kartverket (cache.kartverket.no) | Kartfliser | Kartkoordinater (zoom, x, y) | Norge |
| Kartverket WMS (wms.geonorge.no) | Turruter-kartlag | Kartområde (bounding box) | Norge |
| Geonorge (ws.geonorge.no) | Stedsnavn, adresser, høydedata | Søketekst eller koordinater | Norge |
| Meteorologisk institutt (api.met.no) | Værmelding og havtemperatur | Omtrentlig posisjon | Norge |
| Havvarsel-Frost (havvarsel-frost.met.no) | Badevannstemperatur | Omtrentlig posisjon | Norge |
| DSB (ogc.dsb.no) | Tilfluktsrom | Kartområde (bounding box) | Norge |
| Riksantikvaren (api.ra.no) | Kulturminner | Kartområde (bounding box) | Norge |
| Miljødirektoratet | Naturvernområder og naturskog | Kartområde (bounding box) | Norge |
| FOSSGIS Valhalla (valhalla1.openstreetmap.de) | Ruteberegning | Start- og målkoordinater | Tyskland (EU) |
| Mapzen Terrain Tiles (s3.amazonaws.com) | Terrengmodell for 3D-relieff | Kartkoordinater (zoom, x, y) | USA* |
| GitHub Releases (github.com) | Kunnskapspakker | Ingen brukerdata | USA* |

*Terrengdata og kunnskapspakker hentes som anonyme nedlastinger uten brukeridentifikasjon. Kun kartkoordinater eller filnavn sendes.

Appen sender en User-Agent-header med appens navn, versjon og utviklerens e-postadresse ved alle API-forespørsler, som påkrevd av flere av tjenestene. Headeren inneholder ingen brukerdata.

### IP-adresse

Når appen henter data fra tjenestene over, vil din IP-adresse være synlig for disse tjenestene som en del av normal nettverkskommunikasjon. Alle norske og europeiske tjenester er underlagt GDPR.

## 3. Rettslig grunnlag

- **Berettiget interesse** (GDPR artikkel 6(1)(f)): Appen henter kartdata og værdata for å levere kjernefunksjonaliteten brukeren forventer.
- **Samtykke** (GDPR artikkel 6(1)(a)): Posisjonstilgang krever eksplisitt samtykke via iOS-dialogboksen.

## 4. Dine rettigheter

Siden Tråkke ikke samler inn personopplysninger, er de fleste rettigheter automatisk ivaretatt:

- **Innsyn:** Alle data er synlig i appen.
- **Sletting:** Bruk «Slett alle data» i innstillingene, eller slett appen. Du kan også slette enkeltdata direkte i appen.
- **Dataportabilitet:** Ruter og turer kan eksporteres som GPX-filer.
- **Begrenset behandling:** Du kan bruke appen uten å gi posisjonstilgang.

## 5. Datasikkerhet

- All kommunikasjon skjer over HTTPS
- Data lagres lokalt med iOS-filbeskyttelse (NSFileProtectionComplete)
- Ingen data sendes til skytjenester

## 6. Barn

Tråkke samler ikke inn personopplysninger og har ingen aldersgrense. Appen inneholder ingen kjøp, annonser eller sosiale funksjoner.

## 7. Endringer

Ved vesentlige endringer i denne erklæringen vil oppdatert versjon gjøres tilgjengelig i appen og via GitHub.

## 8. Kontakt

Har du spørsmål om personvern i Tråkke?

- **E-post:** hei@tazk.no
- **Kildekode:** https://github.com/elzacka/trakke-ios

Du har rett til å klage til Datatilsynet (datatilsynet.no) dersom du mener at behandlingen av personopplysninger ikke er i samsvar med regelverket.
