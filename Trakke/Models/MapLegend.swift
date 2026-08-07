import Foundation

// MARK: - Map Legend

/// Tegnforklaring for Kartverkets topografiske kart.
///
/// Symbolutsnittene er skåret ut av Kartverkets offisielle N50-tegnforklaring
/// (CC BY 4.0) og ligger som imagesets under `Assets.xcassets/LegendSymbols/`.
/// `fromZoom` er satt på ALLE rader og er aldri gjettet: verdien kommer fra
/// Kartverkets «Spesifikasjon for skjermkartografi» v2.2 (tegneregel-kapitlene
/// per zoomnivå), overstyrt av verifisering mot faktiske kartfliser der de to
/// avviker (fyr, merket sti, jernbane, stasjon, kirke, sykehus, høydekurver,
/// tettbebyggelse som flate, veinummer-skilt). Symboler som ikke finnes i
/// spesifikasjonen tegnes ikke i skjermkartet og skal ikke stå som rader –
/// derfor er skole, naust, varde og skuterløype fjernet og forklart i
/// seksjonsfotnoter i stedet.
struct MapLegendRow: Identifiable, Sendable {
    /// Navn på imageset i asset-katalogen, f.eks. `legend-skog`.
    let asset: String
    /// Nøkkel i Localizable.xcstrings for radnavnet.
    let nameKey: String
    /// Laveste zoomnivå symbolet er verifisert synlig fra.
    var fromZoom: Int?
    /// Nøkkel for en kort tilleggslinje under navnet.
    var detailKey: String?

    init(_ asset: String, _ nameKey: String, fromZoom: Int? = nil, detailKey: String? = nil) {
        self.asset = asset
        self.nameKey = nameKey
        self.fromZoom = fromZoom
        self.detailKey = detailKey
    }

    var id: String { asset }

    var name: String {
        String(localized: String.LocalizationValue(nameKey))
    }

    var detail: String? {
        detailKey.map { String(localized: String.LocalizationValue($0)) }
    }
}

struct MapLegendSection: Identifiable, Sendable {
    let titleKey: String
    let rows: [MapLegendRow]
    /// Nøkkel for en fotnote nederst i seksjonen.
    var footnoteKey: String?

    var id: String { titleKey }

    var title: String {
        String(localized: String.LocalizationValue(titleKey))
    }

    var footnote: String? {
        footnoteKey.map { String(localized: String.LocalizationValue($0)) }
    }
}

enum MapLegend {
    /// Detaljnivåene kartet tegnes fra, til introkortet.
    /// Kilde: Kartverkets «Spesifikasjon for skjermkartografi» (zoomnivå
    /// 4–17 mot kartserie), verifisert mot cache.kartverket.no.
    static let detailLevels: [(nameKey: String, range: String)] = [
        ("legend.level.overview", "z0\u{2013}8"),
        ("legend.level.regional", "z9\u{2013}10"),
        ("legend.level.n50", "z11\u{2013}12"),
        ("legend.level.detailed", "z13\u{2013}17"),
    ]

    static let sections: [MapLegendSection] = [
        MapLegendSection(titleKey: "legend.section.buildings", rows: [
            MapLegendRow("legend-tettbebyggelse", "legend.row.tettbebyggelse", fromZoom: 9),
            MapLegendRow("legend-gaard-bolig-hytte", "legend.row.gaardBoligHytte", fromZoom: 8),
            MapLegendRow("legend-sykehus-akutt", "legend.row.sykehusAkutt", fromZoom: 13),
            MapLegendRow("legend-kirke-gravplass", "legend.row.kirkeGravplass", fromZoom: 13),
            MapLegendRow("legend-overnattingssted", "legend.row.overnattingssted", fromZoom: 8),
            MapLegendRow("legend-campingplass", "legend.row.campingplass", fromZoom: 10),
            MapLegendRow("legend-turisthytte-betjent", "legend.row.turisthytteBetjent", fromZoom: 11),
            MapLegendRow("legend-turisthytte-selvbetjent", "legend.row.turisthytteSelvbetjent", fromZoom: 11),
            MapLegendRow("legend-turisthytte-ubetjent", "legend.row.turisthytteUbetjent", fromZoom: 11),
            MapLegendRow("legend-annen-turisthytte-selvbetjent", "legend.row.annenTuristhytteSelvbetjent", fromZoom: 11),
            MapLegendRow("legend-annen-turisthytte-ubetjent", "legend.row.annenTuristhytteUbetjent", fromZoom: 11),
            MapLegendRow("legend-dagsturhytte", "legend.row.dagsturhytte", fromZoom: 11),
            MapLegendRow("legend-rastebu-gapahuk", "legend.row.rastebuGapahuk", fromZoom: 11),
        ], footnoteKey: "legend.buildings.note"),
        MapLegendSection(titleKey: "legend.section.transport", rows: [
            MapLegendRow("legend-veinummer-europavei", "legend.row.veinummerEuropavei", fromZoom: 9),
            MapLegendRow("legend-motorvei", "legend.row.motorvei", fromZoom: 6),
            MapLegendRow("legend-europavei-riksvei", "legend.row.europaveiRiksvei", fromZoom: 4),
            MapLegendRow("legend-fylkesvei", "legend.row.fylkesvei", fromZoom: 4),
            MapLegendRow("legend-kommunal-vei", "legend.row.kommunalVei", fromZoom: 6),
            MapLegendRow("legend-privat-vei-bom", "legend.row.privatVeiBom", fromZoom: 7),
            MapLegendRow("legend-traktorvei", "legend.row.traktorvei", fromZoom: 8),
            MapLegendRow("legend-merket-sti", "legend.row.merketSti", fromZoom: 11),
            MapLegendRow("legend-sti-gangbru", "legend.row.stiGangbru", fromZoom: 8),
            MapLegendRow("legend-barmarksloype", "legend.row.barmarksloype", fromZoom: 7),
            MapLegendRow("legend-vei-tunnel", "legend.row.veiTunnel", fromZoom: 7),
            MapLegendRow("legend-bru", "legend.row.bru", fromZoom: 4),
            MapLegendRow("legend-bilferje", "legend.row.bilferje", fromZoom: 4),
            MapLegendRow("legend-passasjerferje", "legend.row.passasjerferje", fromZoom: 7),
            MapLegendRow("legend-flyplass", "legend.row.flyplass", fromZoom: 4),
            MapLegendRow("legend-jernbane-enkelt-spor", "legend.row.jernbane", fromZoom: 8),
            MapLegendRow("legend-jernbane-stasjon", "legend.row.jernbaneStasjon", fromZoom: 9),
            MapLegendRow("legend-jernbane-tunnel", "legend.row.jernbaneTunnel", fromZoom: 9),
            MapLegendRow("legend-parkering", "legend.row.parkering", fromZoom: 10),
        ], footnoteKey: "legend.transport.note"),
        MapLegendSection(titleKey: "legend.section.terrain", rows: [
            MapLegendRow("legend-skog", "legend.row.skog", fromZoom: 4),
            MapLegendRow("legend-dyrket-mark", "legend.row.dyrketMark", fromZoom: 9),
            MapLegendRow("legend-myr", "legend.row.myr", fromZoom: 6),
            MapLegendRow("legend-bre", "legend.row.bre", fromZoom: 4),
            MapLegendRow("legend-stor-elv", "legend.row.storElv", fromZoom: 4),
            MapLegendRow("legend-mindre-elv-foss", "legend.row.mindreElvFoss", fromZoom: 4),
            MapLegendRow("legend-hoydekurver", "legend.row.hoydekurver", fromZoom: 9, detailKey: "legend.row.hoydekurver.detail"),
            MapLegendRow("legend-trigpunkt", "legend.row.trigpunkt", fromZoom: 6),
            MapLegendRow("legend-terrengpunkt", "legend.row.terrengpunkt", fromZoom: 8),
            MapLegendRow("legend-innsjo-hoyde", "legend.row.innsjoHoyde", fromZoom: 8),
        ]),
        MapLegendSection(titleKey: "legend.section.borders", rows: [
            MapLegendRow("legend-riksgrense", "legend.row.riksgrense", fromZoom: 4),
            MapLegendRow("legend-fylkesgrense", "legend.row.fylkesgrense", fromZoom: 4),
            MapLegendRow("legend-kommunegrense", "legend.row.kommunegrense", fromZoom: 6),
            MapLegendRow("legend-statsallmenning", "legend.row.statsallmenning", fromZoom: 11),
            MapLegendRow("legend-skytefelt", "legend.row.skytefelt", fromZoom: 7),
            MapLegendRow("legend-verneomraade", "legend.row.verneomraade", fromZoom: 4),
        ]),
        MapLegendSection(titleKey: "legend.section.coast", rows: [
            MapLegendRow("legend-kystlinje-dybde", "legend.row.kystlinjeDybde", fromZoom: 4),
            MapLegendRow("legend-fyr-lykt", "legend.row.fyrLykt", fromZoom: 10),
        ], footnoteKey: "legend.coast.note"),
        MapLegendSection(titleKey: "legend.section.facilities", rows: [
            MapLegendRow("legend-kraftlinje", "legend.row.kraftlinje", fromZoom: 7),
            MapLegendRow("legend-vindkraftverk", "legend.row.vindkraftverk", fromZoom: 8),
            MapLegendRow("legend-taubane-skitrekk", "legend.row.taubaneSkitrekk", fromZoom: 10),
            MapLegendRow("legend-alpinbakke", "legend.row.alpinbakke", fromZoom: 9),
            MapLegendRow("legend-lysloype", "legend.row.lysloype", fromZoom: 11),
            MapLegendRow("legend-hoppbakke", "legend.row.hoppbakke", fromZoom: 11),
            MapLegendRow("legend-skytebane", "legend.row.skytebane", fromZoom: 11),
            MapLegendRow("legend-gruve", "legend.row.gruve", fromZoom: 7),
            MapLegendRow("legend-dagbrudd-grustak", "legend.row.dagbruddGrustak", fromZoom: 8),
            MapLegendRow("legend-dam", "legend.row.dam", fromZoom: 7),
            MapLegendRow("legend-industriomraade", "legend.row.industriomraade", fromZoom: 7),
            MapLegendRow("legend-tank-taarn-mast", "legend.row.tankTaarnMast", fromZoom: 10),
            MapLegendRow("legend-reingjerde", "legend.row.reingjerde", fromZoom: 10),
        ]),
    ]
}
