import SwiftUI

// MARK: - Current Conditions Card
//
// Ett kort svar over folden («er det greit nå?») + nøkkeltall
// + valgfri akkordeon for sekundære detaljer. Ingen popovers.

struct CurrentConditionsCard: View {
    let data: WeatherData
    var water: WaterTemperatureResult? = nil
    var airQuality: AirQualityData? = nil
    var daylight: SolarCalculator.DaylightInfo? = nil

    @State private var showMore = false
    @State private var showTemperatureTooltip = false
    @State private var showWindTooltip = false
    @State private var showPrecipitationTooltip = false
    @State private var showPressureTooltip = false
    @State private var showHumidityTooltip = false
    @State private var showUVTooltip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Apparent Temperature (Australian Bureau of Meteorology) dekker
        // hele temperatur-spennet. Vises bare når den avviker med ≥1° fra
        // målt temperatur – ingen redundant linje når vind og fuktighet
        // ikke gir merkbar forskjell.
        let apparentTemp = WeatherService.apparentTemperature(
            temperature: data.temperature,
            windSpeedMs: data.windSpeed,
            humidity: data.humidity
        )
        let tempRounded = Int(data.temperature.rounded())
        let apparentRounded = Int(apparentTemp.rounded())
        let showFeelsLike = tempRounded != apparentRounded

        VStack(alignment: .leading, spacing: .Trakke.md) {
            // Symbol og temperatur til venstre, tilstand og følt temperatur
            // høyre. Før sto alt stablet inntil venstre kant med en Spacer som
            // spiste høyre halvdel: tre linjer i høyden og halve bredden tom.
            // To linjer fyller bredden og gir tilbake omtrent 30 punkter, som
            // er en rad mer synlig når arket åpner på halv skjerm.
            //
            // Venstre/høyre er samme oppdeling som stat-radene under, så
            // toppraden leses som en del av samme kort.
            //
            // `ViewThatFits` faller tilbake til den stablede varianten når
            // teksten ikke får plass ved siden av. Ved store tekststørrelser
            // ville temperaturen ellers presset tilstanden ut av kortet.
            ViewThatFits(in: .horizontal) {
                heroSideBySide(
                    tempRounded: tempRounded,
                    apparentRounded: apparentRounded,
                    apparentTemp: apparentTemp,
                    showFeelsLike: showFeelsLike
                )
                heroStacked(
                    tempRounded: tempRounded,
                    apparentRounded: apparentRounded,
                    apparentTemp: apparentTemp,
                    showFeelsLike: showFeelsLike
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { showTemperatureTooltip = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
            .trakkeTooltip(isPresented: $showTemperatureTooltip) {
                TrakkeTooltipContent(
                    title: String(localized: "weather.temperature"),
                    text: String(localized: "weather.temperature.tooltip")
                )
                TooltipArticleLink(articleId: 38)
            }

            // Alle skillelinjene ligger i samme stabel med `spacing: 0`, så de
            // får identisk innrykk og identisk luft. Linja under toppraden lå
            // tidligere utenfor stabelen og arvet kortets md-mellomrom, som ga
            // den mer luft enn de andre.
            VStack(spacing: 0) {
                Divider().padding(.leading, .Trakke.dividerLeading)

                statRow(
                    label: String(localized: "weather.wind"),
                    value: windValue
                )
                .contentShape(Rectangle())
                .onTapGesture { showWindTooltip = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
                .trakkeTooltip(isPresented: $showWindTooltip) {
                    TrakkeTooltipContent(
                        title: String(localized: "weather.wind"),
                        text: String(localized: "weather.wind.tooltip")
                    )
                    TooltipArticleLink(articleId: 37)
                }

                Divider().padding(.leading, .Trakke.dividerLeading)
                statRow(
                    label: String(localized: "weather.precipitation"),
                    value: precipValue
                )
                .contentShape(Rectangle())
                .onTapGesture { showPrecipitationTooltip = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
                .trakkeTooltip(isPresented: $showPrecipitationTooltip) {
                    TrakkeTooltipContent(
                        title: String(localized: "weather.precipitation"),
                        text: String(localized: "weather.precipitation.tooltip")
                    )
                    TooltipArticleLink(articleId: 35)
                }

                if let water, !water.bathingSpots.isEmpty || water.oceanTemperature != nil {
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    if let spot = water.bathingSpots.first {
                        statRow(
                            label: spot.name ?? String(localized: "weather.bathingSpot"),
                            value: MeasurementService.decimal(spot.temperature, digits: 1) + "\u{00B0}"
                        )
                    } else if let ocean = water.oceanTemperature {
                        statRow(
                            label: String(localized: "weather.seaTemperature"),
                            value: MeasurementService.decimal(ocean.temperature, digits: 1) + "\u{00B0}"
                        )
                    }
                }

                // Linje over chevronen: den avslutter radene, og sier at det
                // som eventuelt kommer under er noe annet.
                Divider().padding(.leading, .Trakke.dividerLeading)

                disclosureToggle

                if showMore {
                    // Og en under, når det faktisk er noe der. Uten den ville
                    // chevronen hengt fast i den første detaljraden.
                    Divider().padding(.leading, .Trakke.dividerLeading)

                    detailsContent
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: Toppraden

    private func heroSideBySide(
        tempRounded: Int,
        apparentRounded: Int,
        apparentTemp: Double,
        showFeelsLike: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: .Trakke.md) {
            Image(data.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: .Trakke.touchComfortable, height: .Trakke.touchComfortable)
                .accessibilityHidden(true)

            Text("\(tempRounded)\u{00B0}")
                .font(Font.Trakke.temperature)
                .foregroundStyle(Color.Trakke.text)
                .fixedSize()

            Spacer(minLength: .Trakke.md)

            VStack(alignment: .trailing, spacing: .Trakke.labelGap) {
                Text(WeatherViewModel.conditionText(for: data.symbol))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)

                if showFeelsLike {
                    Text(String(localized: "weather.feelsLike \(apparentRounded)"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(apparentTemp < -10 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }
            }
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func heroStacked(
        tempRounded: Int,
        apparentRounded: Int,
        apparentTemp: Double,
        showFeelsLike: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: .Trakke.lg) {
            Image(data.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: .Trakke.touchComfortable, height: .Trakke.touchComfortable)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text("\(tempRounded)\u{00B0}")
                    .font(Font.Trakke.temperature)
                    .foregroundStyle(Color.Trakke.text)

                if showFeelsLike {
                    Text(String(localized: "weather.feelsLike \(apparentRounded)"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(apparentTemp < -10 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }

                Text(WeatherViewModel.conditionText(for: data.symbol))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Stats

    private var windValue: String {
        let dir = WeatherService.windDirectionFullName(data.windDirection)
        let base = MeasurementService.withUnit(MeasurementService.decimal(data.windSpeed, digits: 0), "m/s") + " " + dir
        if let gust = data.windGust, gust > data.windSpeed * 1.2 {
            return base + " · " + String(localized: "weather.wind.gustLabel \(MeasurementService.decimal(gust, digits: 0))")
        }
        return base
    }

    private var precipValue: String {
        if data.precipitation > 0.05 {
            return MeasurementService.withUnit(MeasurementService.decimal(data.precipitation, digits: 1), "mm")
                + " · "
                + MeasurementService.withUnit(MeasurementService.decimal(data.precipitationProbability, digits: 0), "%")
        } else if data.precipitationProbability > 30 {
            return MeasurementService.withUnit(MeasurementService.decimal(data.precipitationProbability, digits: 0), "%") + " sjanse"
        } else {
            return String(localized: "weather.precipitation.none")
        }
    }

    /// Formaterer UV-indeksen som "{heltall} – {kategori}" basert på WHO/DSA-
    /// nivå-inndeling. F.eks. 0–2 = «Lav», 3–5 = «Moderat», 6–7 = «Sterk»,
    /// 8–10 = «Svært sterk», 11+ = «Ekstrem». Kategori-navnet gir mening til
    /// tallet, særlig viktig på lave verdier der «0» alene ble misforstått
    /// som «ingen data».
    private func uvValueText(_ uv: Double) -> String {
        let rounded = Int(uv.rounded())
        let category: String = switch rounded {
        case ..<3: String(localized: "weather.uv.low")
        case 3...5: String(localized: "weather.uv.moderate")
        case 6...7: String(localized: "weather.uv.high")
        case 8...10: String(localized: "weather.uv.veryHigh")
        default: String(localized: "weather.uv.extreme")
        }
        return "\(rounded) – \(category)"
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: .Trakke.md) {
            Text(label)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: .Trakke.sm)

            Text(value)
                .font(Font.Trakke.bodyRegular.monospacedDigit())
                .foregroundStyle(Color.Trakke.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: Akkordeon (sekundære detaljer)

    private var disclosureToggle: some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                showMore.toggle()
            }
        } label: {
            // Bare en chevron. Retningen sier alt teksten sa, og «Vis mer»
            // gjentok det pila allerede viste. Sentrert, fordi en ensom pil
            // i venstre kant leses som en listerad og ikke som en bryter for
            // kortet over.
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Trakke.brandLight)
                .rotationEffect(.degrees(showMore ? 180 : 0))
                .frame(maxWidth: .infinity, minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Uten synlig tekst må navnet komme herfra, ellers annonserer
        // VoiceOver bare «knapp».
        .accessibilityLabel(showMore
            ? String(localized: "common.showLess")
            : String(localized: "common.showMore"))
        .accessibilityHint(showMore
            ? String(localized: "accessibility.tapToCollapse")
            : String(localized: "accessibility.tapToExpand"))
    }

    @ViewBuilder
    private var detailsContent: some View {
        VStack(spacing: 0) {
            // UV-indeks vises alltid (også på nivå 0) – tooltipet
            // forklarer hva nivåene betyr i praksis. Varsler-seksjonen
            // viser UV separat kun ved nivå >= 3 (anbefalt beskyttelse).
            //
            // Format: "{tall} – {kategori}" (f.eks. "0 – Lav", "6 – Sterk").
            // Tallet alene ble misforstått som "ingen data" på lave nivåer
            // (sen kveld i Norge gir typisk UV 0–1 – sola er for lavt på
            // himmelen for at UV-B når bakken).
            if let uv = data.uvIndex {
                statRow(
                    label: String(localized: "weather.uv"),
                    value: uvValueText(uv)
                )
                .contentShape(Rectangle())
                .onTapGesture { showUVTooltip = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
                .trakkeTooltip(isPresented: $showUVTooltip) {
                    TrakkeTooltipContent(
                        title: String(localized: "weather.uv"),
                        text: String(localized: "weather.uv.tooltip")
                    )
                }
                Divider().padding(.leading, .Trakke.dividerLeading)
            }

            if let pressure = data.pressure {
                statRow(
                    label: String(localized: "weather.pressure"),
                    value: MeasurementService.withUnit(MeasurementService.decimal(pressure, digits: 0), "hPa")
                )
                .contentShape(Rectangle())
                .onTapGesture { showPressureTooltip = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
                .trakkeTooltip(isPresented: $showPressureTooltip) {
                    TrakkeTooltipContent(
                        title: String(localized: "weather.pressure"),
                        text: String(localized: "weather.pressure.tooltip")
                    )
                    TooltipArticleLink(articleId: 34)
                }
                Divider().padding(.leading, .Trakke.dividerLeading)
            }

            statRow(
                label: String(localized: "weather.humidity"),
                value: MeasurementService.withUnit(MeasurementService.decimal(data.humidity, digits: 0), "%")
            )
            .contentShape(Rectangle())
            .onTapGesture { showHumidityTooltip = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "accessibility.tapForExplanation"))
            .trakkeTooltip(isPresented: $showHumidityTooltip) {
                TrakkeTooltipContent(
                    title: String(localized: "weather.humidity"),
                    text: String(localized: "weather.humidity.tooltip")
                )
                TooltipArticleLink(articleId: 39)
            }

            if let daylight {
                Divider().padding(.leading, .Trakke.dividerLeading)
                statRow(
                    label: String(localized: "weather.sunrise"),
                    value: daylight.sunriseFormatted
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                statRow(
                    label: String(localized: "weather.sunset"),
                    value: daylight.sunsetFormatted
                )
            }

            if let aq = airQuality, aq.aqiClass.rawValue < 3 {
                Divider().padding(.leading, .Trakke.dividerLeading)
                statRow(
                    label: String(localized: "weather.airQuality"),
                    value: aq.aqiClass.norwegianName
                )
            }

            Divider().padding(.leading, .Trakke.dividerLeading)
            naafLinkRow
        }
    }

    /// NAAF-pollen-rad: full bredde, hele raden trykkbar, samme padding
    /// som statRow over. Eneste forskjell mot data-rader er pil-ikonet
    /// til høyre som signaliserer at lenken åpner ekstern side.
    private var naafLinkRow: some View {
        Link(destination: URL(string: "https://www.naaf.no/pollenvarsel")!) {
            HStack(spacing: .Trakke.md) {
                Text("NAAF – Pollenvarsel")
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)
                    .lineLimit(1)

                Spacer(minLength: .Trakke.sm)

                Image(systemName: "arrow.up.right")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            .padding(.vertical, .Trakke.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("NAAF – Pollenvarsel")
        .accessibilityHint(String(localized: "accessibility.opensExternalLink"))
    }
}
