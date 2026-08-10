# Personvernerklæring for Tråkke

**Sist oppdatert:** 10. august 2026

## 1. Kort fortalt

Tråkke lagrer all data lokalt på enheten din. Ingen personopplysninger samles inn, og ingen sporing skjer når du bruker appen. Ingenting sendes til appens egne systemer eller til tredjeparter for analyse eller markedsføring.

## 2. Hva som behandles

### Data som lagres lokalt

- **Ruter, steder og turer** du oppretter
- **Turdata:** GPS-spor, avstand og høydemeter fra registrerte turer. Hvert punkt i sporet lagrer posisjon, høyde, tidspunkt, GPS-nøyaktighet, fart og retning. Nøyaktigheten lagres for at appen skal kunne vise hvilke deler av et spor som er usikre, i stedet for å tegne alt som like sikkert.
- **Barometermålinger:** Har telefonen barometer, og du gir Tråkke tilgang til bevegelse, brukes lufttrykket til å måle høydeendringer mer nøyaktig enn GPS klarer. Målingene lagres sammen med turen og forlater aldri enheten. Sier du nei, brukes GPS-høyde i stedet, og alt annet virker som før.
- **Pågående opptak:** Mens en tur tas opp, skrives sporet løpende til en fil på enheten, slik at turen ikke går tapt hvis appen blir avsluttet. Fila slettes når turen er lagret eller forkastet.
- **Innstillinger:** valgt kartlag, koordinatformat og øvrige innstillinger
- **Nedlastede kart** for bruk uten nett
- **Kunnskapsartikler** for bruk uten nett
- **Mellomlagrede vær- og varseldata:** svar fra vær- og varseltjenestene mellomlagres kort tid på enheten, beskyttet med iOS-filbeskyttelse, og slettes med «Slett alle data»

Disse dataene forlater aldri enheten.

### Posisjon

Appen ber om posisjon kun når du aktivt velger å vise den på kartet. Du får en kort forklaring i appen før iOS-dialogen vises, og du kan avvise uten å se iOS-dialogen.

Posisjonen brukes til å vise deg på kartet, navigere til et mål, hente lokal værmelding, registrere GPS-spor og lagre stedet du står på. Posisjonsdata lagres kun lokalt.

Under aktiv navigering og mens en tur tas opp, fortsetter Tråkke å lese posisjonen med skjermen låst. Under navigering er det for at låseskjermen og Dynamic Island skal vise retning og avstand. Under et turopptak er det for at turen ikke skal bli en stump av seg selv i det du legger telefonen i lomma. iOS viser begge deler med posisjonsindikatoren i statuslinjen, og avlesingen stopper når du avslutter navigeringen eller opptaket. Tillatelsen er fortsatt «Mens appen er i bruk» – appen leser aldri posisjon uten at du har startet en av disse to tingene selv.

### Nettverksstatus

Appen viser om enheten er tilkoblet eller frakoblet, og hvilken tilkoblingstype som er i bruk (Wi-Fi, mobildata, kablet, annet eller ingen). Dette leses lokalt fra iOS via NWPathMonitor. Ingen nettverksdata sendes ut av enheten og ingenting lagres.

### Siri, Snarveier og Handlingsknappen

Tråkke tilbyr tre handlinger utenfor appen: start turopptak, stopp turopptak og marker stedet. Handlingene sender ingenting ut av enheten. Det eneste som lagres, er navnet på handlingen du ba om, i innstillingene på enheten, fram til appen åpnes og utfører den. Ingen posisjon, tekst eller lyd følger med.

Sier du kommandoen til Siri, behandler iOS talen etter Apples egne personvernvilkår, ikke Tråkkes. Tråkke får bare vite hvilken av de tre handlingene du valgte.

### Data som ikke samles inn

Appen bruker ingen kontoer, informasjonskapsler, enhetsidentifikatorer (IDFA), bruksstatistikk eller biometriske data. Barometeret leses bare mens du tar opp en tur, og bare til høyde og lufttrykk – ikke til å kjenne igjen enheten.

## 3. Eksterne tjenester

Appen henter data fra følgende tjenester. Alle er norske eller europeiske, med ett unntak: artikkeloppdateringer (GitHub). Disse inneholder ingen brukerdata.

| Tjeneste | Formål | Data som sendes | Land |
|----------|--------|-----------------|------|
| Kartverket (cache.kartverket.no) | Kartfliser | Kartkoordinater (zoom, x, y) | Norge |
| Kartverket WMS (wms.geonorge.no) | Turruter | Kartområde | Norge |
| Geonorge (ws.geonorge.no) | Stedsnavn, adresser, høydedata | Søketekst eller koordinater | Norge |
| Meteorologisk institutt (api.met.no) | Vær, havtemperatur, luftkvalitet | Omtrentlig posisjon (luftkvalitet: 2 desimaler, ca. 1,1 km) | Norge |
| Meteorologisk institutt (havvarsel-frost.met.no) | Badevannstemperatur fra målestasjoner | Omtrentlig posisjon | Norge |
| Geonorge (wfs.geonorge.no) | Tilfluktsrom fra DSB | Kartområde | Norge |
| Riksantikvaren (api.ra.no) | Kulturminner | Kartområde | Norge |
| Miljødirektoratet | Naturvernområder og naturskog | Kartområde | Norge |
| NVE / Varsom (api01.nve.no, gis3.nve.no) | Snøskred, flom, bratthet | Omtrentlig posisjon eller kartområde | Norge |
| Artsdatabanken (artsdatabanken.no) | Artsbilder | Vitenskapelige artsnavn | Norge |
| GitHub (raw.githubusercontent.com) | Artikkeloppdateringer | Ingen brukerdata | USA¹ |

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
- Lokal lagring beskyttet med iOS-filbeskyttelse. Ruter, steder, turer og mellomlagrede data er kryptert så lenge telefonen er låst (NSFileProtectionComplete). Sporet fra et pågående opptak og filer du eksporterer er kryptert i hvile, men lesbare mens telefonen er låst opp én gang etter omstart (NSFileProtectionCompleteUntilFirstUserAuthentication) – ellers ville et turopptak ikke kunne skrive til enheten mens skjermen er låst, som er nettopp når det pågår
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
