import SwiftUI
import Charts
import CoreLocation

struct ActivityDetailSheet: View {
    @Bindable var viewModel: ActivityViewModel
    let activity: Activity
    var onRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onFollowAgain: ((Activity) -> Void)?
    var isEmbedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var shareURL: ShareableURL?
    @State private var showEditDialog = false
    @State private var stats: DerivedStats?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            // Pushet visning får appens tilbakeknapp; top-level sheet har
            // ingen vei tilbake og viser bare tittelen.
            TrakkeSheetHeader(title: activity.name, onBack: backAction)
            content
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .toolbar(.hidden, for: .navigationBar)
        // Statistikken skannes én gang per aktivitet, ikke én gang per
        // body-evaluering. De avledede egenskapene på `Activity` går gjennom
        // hele sporet – `movingDuration` med en Haversine per punktpar – og
        // uten mellomlagring kjørte hver eneste @State-vipp (rediger, del,
        // slett) elleve fulle skanninger på hovedtråden. Sporet er uforanderlig
        // etter lagring (redigering endrer bare navn og kategori), så
        // `id: activity.id` kan ikke bli stående med utdaterte tall.
        .task(id: activity.id) {
            let moving = activity.movingDuration
            stats = DerivedStats(
                moving: moving,
                // Avledet uten ny skanning – samme formler som pausedDuration
                // og averageMovingSpeed i Activity.swift.
                paused: max(0, activity.duration - moving),
                avgSpeed: moving > 0 ? activity.distance / moving : 0,
                maxSpeed: activity.maxSpeed,
                minAlt: activity.minAltitude,
                maxAlt: activity.maxAltitude,
                elevationPoints: computeElevationPoints()
            )
        }
    }

    private var backAction: (() -> Void)? {
        guard isEmbedded else { return nil }
        return { dismiss() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                actionsCard
                statsCard
                elevationCard
                detailsCard

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sm)
        }
        .sheet(isPresented: $showEditDialog) {
            EditNameCategorySheet(
                title: String(localized: "common.edit"),
                initialName: activity.name,
                initialCategory: activity.category ?? "",
                categorySuggestions: viewModel.categories,
                namePlaceholder: String(localized: "activity.save.namePlaceholder")
            ) { newName, newCategory in
                viewModel.edit(activity, name: newName, category: newCategory)
            }
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    // MARK: - Actions Card
    //
    // Høyrejustert ikon-bar – samme stil som Naviger-list-fanene og de
    // andre detail-arkene. Posisjon i HStack indikerer hierarki:
    // primær-handling (følg igjen) først, destruktiv (slett) sist.

    @ViewBuilder
    private var actionsCard: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            if activity.trackPoints.count >= 2 {
                TrakkeIconButton(
                    systemImage: "location.north.fill",
                    accessibilityLabel: String(localized: "activity.followAgain"),
                    action: {
                        dismiss()
                        onFollowAgain?(activity)
                    }
                )
            }

            TrakkeIconButton(
                systemImage: "pencil",
                accessibilityLabel: String(localized: "common.edit"),
                action: { showEditDialog = true }
            )

            if let startPoint = retraceDestination {
                TrakkeIconButton(
                    systemImage: "arrow.uturn.backward",
                    accessibilityLabel: String(localized: "activity.retrace"),
                    action: {
                        dismiss()
                        onRetrace?(startPoint)
                    }
                )
            }

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                accessibilityLabel: String(localized: "export.share"),
                action: {
                    if let url = viewModel.exportGPX(for: activity) {
                        shareURL = ShareableURL(url: url)
                    }
                }
            )

            TrakkeIconButton(
                systemImage: "trash",
                role: .destructive,
                accessibilityLabel: String(localized: "activity.delete"),
                action: { showDeleteConfirmation = true }
            )
            .accessibilityHint(String(localized: "accessibility.deleteHint"))
            .trakkeDialog(
                isPresented: $showDeleteConfirmation,
                title: String(localized: "activity.delete.title"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteActivity(activity)
                    dismiss()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }

    // MARK: - Stats Card

    /// Statistikken ligger i et rutenett med faste kolonner, ikke i rader av
    /// `HStack`.
    ///
    /// Med rader fikk hver celle sin egen bredde ut fra innholdet, så
    /// kolonnene i rad to og tre ikke sto under kolonnene i rad én. Med to
    /// felter på siste rad ble hele høyre halvdel dessuten stående tom.
    /// Et rutenett gir samme kolonnebredde uansett hvor mange felter turen
    /// har, og reflyter av seg selv ved store tekststørrelser.
    private var statsCard: some View {
        CardSection(String(localized: "activity.stats")) {
            LazyVGrid(columns: statColumns, alignment: .leading, spacing: .Trakke.md) {
                statItem(
                    icon: "arrow.left.and.right",
                    label: String(localized: "activity.distance"),
                    value: ActivityViewModel.formatDistance(activity.distance)
                )
                statItem(
                    icon: "timer",
                    label: String(localized: "activity.duration"),
                    value: ActivityViewModel.formatDuration(activity.duration)
                )
                statItem(
                    icon: "arrow.up.right",
                    label: String(localized: "elevation.gain"),
                    value: "\(Int(activity.elevationGain)) m"
                )
                statItem(
                    icon: "arrow.down.right",
                    label: String(localized: "elevation.loss"),
                    value: "\(Int(activity.elevationLoss)) m"
                )

                // Tallene som først ble mulige da sporet fikk oppløsning. De
                // vises bare når sporet faktisk bærer dem, så en gammel tur
                // ikke får felter med nuller.
                if let stats, stats.moving > 0 {
                    statItem(
                        icon: "figure.walk",
                        label: String(localized: "activity.movingTime"),
                        value: ActivityViewModel.formatDuration(stats.moving)
                    )
                    statItem(
                        icon: "pause.circle",
                        label: String(localized: "activity.pausedTime"),
                        value: ActivityViewModel.formatDuration(stats.paused)
                    )
                    statItem(
                        icon: "speedometer",
                        label: String(localized: "activity.averageSpeed"),
                        value: MeasurementService.formatSpeed(stats.avgSpeed)
                    )
                    // Enkelt strektegn som de øvrige. Måler-symbolene med
                    // nål og prikker er for tette til å leses på 12 punkt i
                    // tertiærfarge.
                    statItem(
                        icon: "bolt",
                        label: String(localized: "activity.maxSpeed"),
                        value: MeasurementService.formatSpeed(stats.maxSpeed)
                    )
                }

                if let lowest = stats?.minAlt, let highest = stats?.maxAlt {
                    statItem(
                        icon: "arrow.down.to.line",
                        label: String(localized: "activity.lowestPoint"),
                        value: "\(Int(lowest)) m"
                    )
                    statItem(
                        icon: "arrow.up.to.line",
                        label: String(localized: "activity.highestPoint"),
                        value: "\(Int(highest)) m"
                    )
                }
            }
            .padding(.vertical, .Trakke.rowVertical)
        }
    }

    /// Fire kolonner ved vanlig tekststørrelse, to når teksten er stor.
    /// Fire smale kolonner med «3:45:11» og «2,8 km/t» i seg blir uleselige
    /// lenge før tilgjengelighetsstørrelsene.
    private var statColumns: [GridItem] {
        let count = dynamicTypeSize >= .accessibility1 ? 2 : 4
        return Array(repeating: GridItem(.flexible(), alignment: .leading), count: count)
    }

    // MARK: - Elevation Card

    private var elevationCard: some View {
        CardSection(String(localized: "elevation.profile")) {
            // Tomtilstanden gates på at statistikken er beregnet, ikke på et
            // tomt array – ellers blinker «ingen høydedata» innom i den første
            // rammen, før grafen rekker å tegnes.
            if let stats {
                if stats.elevationPoints.count >= 2 {
                    elevationChart(points: stats.elevationPoints)
                } else {
                    Text(String(localized: "activity.noElevationData"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .padding(.vertical, .Trakke.rowVertical)
                }
            }
        }
    }

    @ViewBuilder
    private func elevationChart(points: [ElevPoint]) -> some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value(String(localized: "elevation.distance"), point.distance / 1000),
                    y: .value(String(localized: "elevation.altitude"), point.altitude)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.Trakke.brand.opacity(0.3), Color.Trakke.brand.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value(String(localized: "elevation.distance"), point.distance / 1000),
                    y: .value(String(localized: "elevation.altitude"), point.altitude)
                )
                .foregroundStyle(Color.Trakke.brand)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        // Uten et eksplisitt område runder Swift Charts x-aksen opp til neste
        // «pene» tall – en tur på 10,4 km fikk en akse til 15, og kurven
        // stoppet en tredjedel fra kanten med tomrom etter seg. Aksen skal
        // være så lang som turen, ikke lenger.
        .chartXScale(domain: 0...chartMaxDistance(for: points))
        .chartXAxisLabel(String(localized: "elevation.distanceKm"))
        .chartYAxisLabel("m")
        .frame(height: 160)
    }

    /// Turens lengde i kilometer, med et lite påslag så siste punkt ikke
    /// klistrer seg til aksen.
    private func chartMaxDistance(for points: [ElevPoint]) -> Double {
        let metres = points.last?.distance ?? 0
        guard metres > 0 else { return 1 }
        return (metres / 1000) * 1.02
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        CardSection(String(localized: "activity.details")) {
            // «Dato» sto her før, med et klokkeslett ved siden av som ikke
            // fortalte hva det var tidspunktet for. Raden viser starten på
            // turen, og da skal den hete det.
            detailRow(
                label: String(localized: "activity.started"),
                value: activity.startedAt.formatted(date: .long, time: .shortened)
            )
            if let endedAt = activity.endedAt {
                Divider().padding(.leading, .Trakke.dividerLeading)
                // Full dato, som start-raden. Utover at radene skal se like
                // ut: en tur som går over midnatt slutter på en annen dato,
                // og da er klokkeslettet alene direkte misvisende.
                detailRow(
                    label: String(localized: "activity.ended"),
                    value: endedAt.formatted(date: .long, time: .shortened)
                )
            }
            Divider().padding(.leading, .Trakke.dividerLeading)
            detailRow(
                label: String(localized: "activity.trackPoints"),
                value: "\(activity.trackPoints.count)"
            )
            // Her lå en «Snittfart» til, i min/km og regnet mot totaltid.
            // Kortet over har allerede snittfart – i km/t og mot bevegelsestid.
            // To rader med samme navn, ulik enhet og ulikt tall er ikke mer
            // informasjon, det er tvil om hvilken som gjelder.
        }
    }

    /// Startpunkt for tur – der bruker vil retrace-navigere tilbake til.
    private var retraceDestination: CLLocationCoordinate2D? {
        guard let first = activity.trackPoints.first, first.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: first[1], longitude: first[0])
    }

    // MARK: - Helpers

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
            HStack(spacing: .Trakke.xs) {
                Image(systemName: icon)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .accessibilityHidden(true)
                Text(value)
                    .font(Font.Trakke.bodyMedium)
                    .monospacedDigit()
                    // Tallet skal krympe framfor å brekke. «3:45:11» over to
                    // linjer i en smal kolonne er verre enn litt mindre tekst.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .foregroundStyle(Color.Trakke.textTertiary)
                .font(Font.Trakke.captionSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

    private struct ElevPoint {
        let distance: Double
        let altitude: Double
    }

    /// Avledet statistikk, beregnet én gang per aktivitet i `.task(id:)` og
    /// lest fra body i stedet for de utregnede egenskapene på `Activity`.
    /// Formlene bor fortsatt i `Activity` – dette er bare visningens
    /// mellomlager, ikke en ny kilde til tallene.
    private struct DerivedStats {
        let moving: TimeInterval
        let paused: TimeInterval
        let avgSpeed: Double
        let maxSpeed: Double
        let minAlt: Double?
        let maxAlt: Double?
        let elevationPoints: [ElevPoint]
    }

    /// Høydeprofilen er høyde mot *distanse*, og da kan to punkter ikke dele
    /// samme x-verdi.
    ///
    /// Står du stille – en matpause – lagrer opptaket punkter uten at
    /// distansen øker. Swift Charts slår sammen marks med lik x ved å
    /// **summere** y, så en pause på 44 punkter i 1743 moh. ble tegnet som
    /// 76 000 meter og dro hele aksen med seg. Punkter som ikke flytter
    /// profilen framover, hører derfor ikke hjemme i den.
    ///
    /// Umålte høyder hoppes over av samme grunn som ellers: en 0 er ikke
    /// havnivå her, den er manglende data, og den ville laget en pigg rett ned.
    private func computeElevationPoints() -> [ElevPoint] {
        let points = activity.trackPoints
        guard points.count >= 2 else { return [] }

        var result: [ElevPoint] = []
        var cumulativeDistance: Double = 0
        var lastPlottedDistance: Double?

        for (index, point) in points.enumerated() {
            if index > 0, points[index - 1].count >= 2, point.count >= 2 {
                let prev = CLLocationCoordinate2D(
                    latitude: points[index - 1][1],
                    longitude: points[index - 1][0]
                )
                let curr = CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                cumulativeDistance += Haversine.distance(from: prev, to: curr)
            }

            guard let altitude = Activity.altitude(of: point) else { continue }
            if let last = lastPlottedDistance, cumulativeDistance - last < Self.minProfileStep {
                continue
            }
            lastPlottedDistance = cumulativeDistance
            result.append(ElevPoint(distance: cumulativeDistance, altitude: altitude))
        }

        return result
    }

    /// Minste avstand mellom to punkter i profilen. Holder også antall marks
    /// nede på lange turer, der sporet kan ha flere tusen punkter.
    private static let minProfileStep: Double = 15
}
