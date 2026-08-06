# Personvernerklæring for Tråkke

**Sist oppdatert:** 31. juli 2026

## 1. Kort fortalt

Tråkke lagrer all data lokalt på enheten din. Ingen personopplysninger samles inn, og ingen sporing skjer når du bruker appen. Ingenting sendes til appens egne systemer eller til tredjeparter for analyse eller markedsføring.

## 2. Hva som behandles

### Data som lagres lokalt

- **Ruter, steder og turer** du oppretter
- **Turdata:** GPS-spor, avstand og høydemeter fra registrerte turer
- **Innstillinger:** valgt kartlag, koordinatformat og øvrige innstillinger
- **Nedlastede kart** for bruk uten nett
- **Kunnskapsartikler** for bruk uten nett
- **Mellomlagrede vær- og varseldata:** svar fra vær- og varseltjenestene mellomlagres kort tid på enheten, beskyttet med iOS-filbeskyttelse, og slettes med «Slett alle data»

Disse dataene forlater aldri enheten.

### Posisjon

Appen ber om posisjon kun når du aktivt velger å vise den på kartet. Du får en kort forklaring i appen før iOS-dialogen vises, og du kan avvise uten å se iOS-dialogen.

Posisjonen brukes til å vise deg på kartet, navigere til et mål, hente lokal værmelding og registrere GPS-spor. Posisjonsdata lagres kun lokalt.

Under aktiv navigering fortsetter Tråkke å lese posisjonen mens skjermen er låst, slik at låseskjermen og Dynamic Island kan vise retning og avstand. iOS viser dette med posisjonsindikatoren i statuslinjen. Avlesingen stopper når du avslutter navigeringen. Tillatelsen er fortsatt «Mens appen er i bruk» – appen leser aldri posisjon i bakgrunnen utenom aktiv navigering.

### Nettverksstatus

Appen viser om enheten er tilkoblet eller frakoblet, og hvilken tilkoblingstype som er i bruk (Wi-Fi, mobildata, kablet, annet eller ingen). Dette leses lokalt fra iOS via NWPathMonitor. Ingen nettverksdata sendes ut av enheten og ingenting lagres.

### Data som ikke samles inn

Appen bruker ingen kontoer, informasjonskapsler, enhetsidentifikatorer (IDFA), bruksstatistikk eller biometriske data.

## 3. Eksterne tjenester

Appen henter data fra følgende tjenester. Alle er norske eller europeiske, med ett unntak: kunnskapspakker (GitHub). Disse inneholder ingen brukerdata.

| Tjeneste | Formål | Data som sendes | Land |
|----------|--------|-----------------|------|
| Kartverket (cache.kartverket.no) | Kartfliser | Kartkoordinater (zoom, x, y) | Norge |
| Kartverket WMS (wms.geonorge.no) | Turruter | Kartområde | Norge |
| Geonorge (ws.geonorge.no) | Stedsnavn, adresser, høydedata | Søketekst eller koordinater | Norge |
| Meteorologisk institutt (api.met.no) | Vær, havtemperatur, luftkvalitet | Omtrentlig posisjon (luftkvalitet: 2 desimaler, ca. 1,1 km) | Norge |
| Meteorologisk institutt (havvarsel-frost.met.no) | Badevannstemperatur fra målestasjoner | Omtrentlig posisjon | Norge |
| DSB (ogc.dsb.no) | Tilfluktsrom | Kartområde | Norge |
| Riksantikvaren (api.ra.no) | Kulturminner | Kartområde | Norge |
| Miljødirektoratet | Naturvernområder og naturskog | Kartområde | Norge |
| NVE / Varsom (api01.nve.no, gis3.nve.no) | Snøskred, flom, bratthet | Omtrentlig posisjon eller kartområde | Norge |
| Artsdatabanken (artsdatabanken.no) | Artsbilder | Vitenskapelige artsnavn | Norge |
| GitHub (github.com, raw.githubusercontent.com) | Kunnskapspakker og artikler | Ingen brukerdata | USA¹ |

¹ Hentes anonymt, uten brukeridentifikasjon. Kun filnavn sendes.

Appen sender en User-Agent-header med appens navn, versjon og utviklerens e-postadresse, som påkrevd av flere tjenester. Headeren inneholder ingen brukerdata.

### IP-adresse

Når appen henter data, vil IP-adressen din være synlig for tjenesten som en del av normal nettverkskommunikasjon. Alle norske og europeiske tjenester er underlagt GDPR.

## 4. Rettslig grunnlag

- **Berettiget interesse** (GDPR art. 6(1)(f)): Appen henter kart- og værdata for å levere kjernefunksjonen.
- **Samtykke** (GDPR art. 6(1)(a)): Posisjonstilgang krever eksplisitt samtykke via iOS-dialogen.

## 5. Rettighetene dine

Siden Tråkke ikke samler inn personopplysninger, er de fleste rettighetene automatisk ivaretatt:

- **Innsyn**: Alle data vises i appen.
- **Sletting**: Bruk «Slett alle data» i innstillingene, eller slett appen. Enkeltdata kan slettes direkte i appen.
- **Dataportabilitet**: Ruter, steder og turer kan eksporteres som GPX-filer. Import støtter både GPX og GeoJSON.
- **Begrenset behandling**: Appen kan brukes uten å gi posisjonstilgang.

## 6. Datasikkerhet

- All kommunikasjon over HTTPS
- Lokal lagring beskyttet med iOS-filbeskyttelse (NSFileProtectionComplete)
- Ingen data sendes til skytjenester

## 7. Barn

Tråkke samler ikke inn personopplysninger og har ingen aldersgrense. Appen har ingen kjøp, annonser eller sosiale funksjoner.

## 8. Endringer

Ved vesentlige endringer publiseres oppdatert erklæring i appen og på GitHub.

## 9. Kontakt

Spørsmål om personvern:

- **E-post**: hei@tazk.no
- **Kildekode**: https://github.com/elzacka/trakke-ios

Du kan klage til Datatilsynet hvis du mener behandlingen ikke er i samsvar med regelverket.
