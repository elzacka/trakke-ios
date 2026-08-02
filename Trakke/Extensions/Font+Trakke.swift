import SwiftUI

extension Font {
    /// Typografisk skala for Tråkke.
    ///
    /// Systemet har to nivåer med ulikt formål:
    ///
    /// **Langform** (`article*`) – artikler, brukerveiledning og
    /// personvernerklæring. Flater du leser sammenhengende. Hierarkiet bæres av
    /// tre signaler samtidig: skriftfamilie (Exo 2 for display, systemfont for
    /// lesing), størrelse og vekt. Derfor er en h2 synlig som overskrift selv
    /// når Dynamic Type presser nivåene mot hverandre.
    ///
    /// **Skannende flater** (`body*`, `caption*`) – rader, kort og lister der
    /// du leter etter én verdi. Tettere skala, mindre grunnlinje.
    ///
    /// De to skalaene skal ikke blandes: en artikkel bruker ikke `bodyRegular`,
    /// og en listerad bruker ikke `articleBody`.
    enum Trakke {
        /// Merkevarefont – Exo 2. Standardvekt Light for display-tekst;
        /// variabelfonten bærer hele aksen 100–900, så `weight` kan settes.
        static func brand(
            size: CGFloat,
            relativeTo textStyle: Font.TextStyle = .body,
            weight: Font.Weight = .light
        ) -> Font {
            .custom("Exo 2", size: size, relativeTo: textStyle).weight(weight)
        }

        // MARK: - Langform

        /// Arktittel. Eneste sted Light-vekten får stå alene og stor.
        static var articleTitle: Font { brand(size: 28, relativeTo: .largeTitle) }

        /// h2. Exo 2 Regular, ikke Light: Light på 20 pt gir for tynne streker
        /// mot cream-bakgrunn til å lese som overskrift.
        static var articleHeading: Font { brand(size: 20, relativeTo: .title3, weight: .regular) }

        /// h3. Blir værende i systemfonten – familiebytte hver tredje linje
        /// ville blitt uro, ikke struktur.
        static var articleSubheading: Font { .headline }

        /// Brødtekst og listepunkt i langform.
        static var articleBody: Font { .body }

        /// Bildetekst, kilde og fotnote i langform.
        static var articleCaption: Font { .footnote }

        // MARK: - Skannende flater

        /// Radtittel med metadata under.
        static var bodyMedium: Font { .subheadline.weight(.medium) }

        /// Enlinjes navigasjonsrad og vanlig tekst i kort.
        static var bodyRegular: Font { .subheadline }

        /// Sekundærlinje under en radtittel.
        static var caption: Font { .caption }

        /// Kreditering og lisenstekst. Minste tekst i appen – ikke bruk den
        /// til noe brukeren må lese for å ta en beslutning.
        static var captionSoft: Font { .caption2 }

        // MARK: - Roller

        /// Dialogtittel. Semibold, mens knappene er medium, slik at tittelen
        /// aldri leser som trykkbar.
        static var dialogTitle: Font { .subheadline.weight(.semibold) }

        /// Gruppetittel: CardSection-overskrift og kategorioverskrift i lister.
        static var sectionHeader: Font { .caption.weight(.semibold) }

        // MARK: - Spesialiserte

        /// Store SF Symbols i tomtilstander og primere. Egen verdi fordi en
        /// tekstfont ville latt Exo 2s metrikk bestemme symbolstørrelsen.
        static var iconLarge: Font { .system(.largeTitle) }

        /// Statistikkverdi i StatTile.
        static var numeralXLarge: Font { .title2.monospacedDigit().bold() }

        /// Temperaturvisning i været.
        static var temperature: Font { .system(.largeTitle, design: .rounded, weight: .light) }

        /// Morsekode i SOS – monospaced gir jevn tegnavstand.
        static var morse: Font { .system(.title, design: .monospaced, weight: .bold) }
    }
}
