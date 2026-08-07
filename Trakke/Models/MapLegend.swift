import Foundation

// MARK: - Map Legend

/// Tegnforklaring for Kartverkets topografiske kart.
///
/// Symbolutsnittene er skåret ut av Kartverkets offisielle N50-tegnforklaring
/// (CC BY 4.0) og ligger som imagesets under `Assets.xcassets/LegendSymbols/`.
/// `fromZoom` settes bare der nivået er dokumentert i Kartverkets
/// spesifikasjon for skjermkartografi eller verifisert mot faktiske
/// kartfliser – aldri gjettet. Symboler uten verdi følger kartserien sin:
/// turkart-symbolene (N50) tegnes fra zoomnivå 11–12, detaljkartet (FKB)
/// tar over fra 13.
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
            MapLegendRow("legend-gaard-bolig-hytte", "legend.row.gaardBoligHytte", fromZoom: 13),
            MapLegendRow("legend-naust", "legend.row.naust"),
            MapLegendRow("legend-sykehus-akutt", "legend.row.sykehusAkutt", fromZoom: 13),
            MapLegendRow("legend-skole", "legend.row.skole"),
            MapLegendRow("legend-kirke-gravplass", "legend.row.kirkeGravplass", fromZoom: 13),
            MapLegendRow("legend-overnattingssted", "legend.row.overnattingssted"),
            MapLegendRow("legend-campingplass", "legend.row.campingplass"),
            MapLegendRow("legend-turisthytte-betjent", "legend.row.turisthytteBetjent", fromZoom: 11),
            MapLegendRow("legend-turisthytte-selvbetjent", "legend.row.turisthytteSelvbetjent"),
            MapLegendRow("legend-turisthytte-ubetjent", "legend.row.turisthytteUbetjent"),
            MapLegendRow("legend-annen-turisthytte-selvbetjent", "legend.row.annenTuristhytteSelvbetjent"),
            MapLegendRow("legend-annen-turisthytte-ubetjent", "legend.row.annenTuristhytteUbetjent"),
            MapLegendRow("legend-dagsturhytte", "legend.row.dagsturhytte"),
            MapLegendRow("legend-rastebu-gapahuk", "legend.row.rastebuGapahuk"),
        ]),
        MapLegendSection(titleKey: "legend.section.transport", rows: [
            MapLegendRow("legend-veinummer-europavei", "legend.row.veinummerEuropavei", fromZoom: 9),
            MapLegendRow("legend-motorvei", "legend.row.motorvei"),
            MapLegendRow("legend-europavei-riksvei", "legend.row.europaveiRiksvei"),
            MapLegendRow("legend-fylkesvei", "legend.row.fylkesvei"),
            MapLegendRow("legend-kommunal-vei", "legend.row.kommunalVei"),
            MapLegendRow("legend-privat-vei-bom", "legend.row.privatVeiBom"),
            MapLegendRow("legend-traktorvei", "legend.row.traktorvei"),
            MapLegendRow("legend-merket-sti", "legend.row.merketSti", fromZoom: 11),
            MapLegendRow("legend-sti-gangbru", "legend.row.stiGangbru"),
            MapLegendRow("legend-barmarksloype", "legend.row.barmarksloype"),
            MapLegendRow("legend-skuterloype", "legend.row.skuterloype"),
            MapLegendRow("legend-vei-tunnel", "legend.row.veiTunnel"),
            MapLegendRow("legend-bru", "legend.row.bru"),
            MapLegendRow("legend-bilferje", "legend.row.bilferje", fromZoom: 9),
            MapLegendRow("legend-passasjerferje", "legend.row.passasjerferje"),
            MapLegendRow("legend-flyplass", "legend.row.flyplass"),
            MapLegendRow("legend-jernbane-enkelt-spor", "legend.row.jernbane", fromZoom: 8),
            MapLegendRow("legend-jernbane-stasjon", "legend.row.jernbaneStasjon", fromZoom: 9),
            MapLegendRow("legend-jernbane-tunnel", "legend.row.jernbaneTunnel"),
            MapLegendRow("legend-parkering", "legend.row.parkering"),
        ]),
        MapLegendSection(titleKey: "legend.section.terrain", rows: [
            MapLegendRow("legend-skog", "legend.row.skog"),
            MapLegendRow("legend-dyrket-mark", "legend.row.dyrketMark"),
            MapLegendRow("legend-myr", "legend.row.myr"),
            MapLegendRow("legend-bre", "legend.row.bre"),
            MapLegendRow("legend-stor-elv", "legend.row.storElv"),
            MapLegendRow("legend-mindre-elv-foss", "legend.row.mindreElvFoss"),
            MapLegendRow("legend-hoydekurver", "legend.row.hoydekurver", fromZoom: 9, detailKey: "legend.row.hoydekurver.detail"),
            MapLegendRow("legend-trigpunkt", "legend.row.trigpunkt"),
            MapLegendRow("legend-terrengpunkt", "legend.row.terrengpunkt"),
            MapLegendRow("legend-innsjo-hoyde", "legend.row.innsjoHoyde"),
        ]),
        MapLegendSection(titleKey: "legend.section.borders", rows: [
            MapLegendRow("legend-riksgrense", "legend.row.riksgrense"),
            MapLegendRow("legend-fylkesgrense", "legend.row.fylkesgrense"),
            MapLegendRow("legend-kommunegrense", "legend.row.kommunegrense"),
            MapLegendRow("legend-statsallmenning", "legend.row.statsallmenning"),
            MapLegendRow("legend-skytefelt", "legend.row.skytefelt"),
            MapLegendRow("legend-verneomraade", "legend.row.verneomraade"),
        ]),
        MapLegendSection(titleKey: "legend.section.coast", rows: [
            MapLegendRow("legend-kystlinje-dybde", "legend.row.kystlinjeDybde"),
            MapLegendRow("legend-fyr-lykt", "legend.row.fyrLykt", fromZoom: 10),
            MapLegendRow("legend-varde", "legend.row.varde"),
        ], footnoteKey: "legend.coast.note"),
        MapLegendSection(titleKey: "legend.section.facilities", rows: [
            MapLegendRow("legend-kraftlinje", "legend.row.kraftlinje"),
            MapLegendRow("legend-vindkraftverk", "legend.row.vindkraftverk"),
            MapLegendRow("legend-taubane-skitrekk", "legend.row.taubaneSkitrekk"),
            MapLegendRow("legend-alpinbakke", "legend.row.alpinbakke"),
            MapLegendRow("legend-lysloype", "legend.row.lysloype"),
            MapLegendRow("legend-hoppbakke", "legend.row.hoppbakke"),
            MapLegendRow("legend-skytebane", "legend.row.skytebane"),
            MapLegendRow("legend-gruve", "legend.row.gruve"),
            MapLegendRow("legend-dagbrudd-grustak", "legend.row.dagbruddGrustak"),
            MapLegendRow("legend-dam", "legend.row.dam"),
            MapLegendRow("legend-industriomraade", "legend.row.industriomraade"),
            MapLegendRow("legend-tank-taarn-mast", "legend.row.tankTaarnMast"),
            MapLegendRow("legend-reingjerde", "legend.row.reingjerde"),
        ]),
    ]
}
