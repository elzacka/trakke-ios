import SwiftUI

// MARK: - Current Conditions Card
//
// Ett kort svar over folden («er det greit nå?») + nøkkeltall
// + valgfri akkordeon for sekundære detaljer. Ingen popovers.

struct CurrentConditionsCard: View {
    let data: WeatherData
    var hourlyData: [WeatherData] = []
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
                .accessibilityElement(children: .combine)

                Spacer()
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

            Divider()

            VStack(spacing: 0) {
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
                            value: String(format: "%.1f°", spot.temperature)
                        )
                    } else if let ocean = water.oceanTemperature {
                        statRow(
                            label: String(localized: "weather.seaTemperature"),
                            value: String(format: "%.1f°", ocean.temperature)
                        )
                    }
                }
            }

            disclosureToggle

            if showMore {
                detailsContent
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Stats

    private var windValue: String {
        let dir = WeatherService.windDirectionFullName(data.windDirection)
        let base = String(format: "%.0f m/s %@", data.windSpeed, dir)
        if let gust = data.windGust, gust > data.windSpeed * 1.2 {
            return base + " · " + String(localized: "weather.wind.gustLabel \(String(format: "%.0f", gust))")
        }
        return base
    }

    private var precipValue: String {
        if data.precipitation > 0.05 {
            return String(format: "%.1f mm", data.precipitation)
                + " · "
                + String(format: "%.0f %%", data.precipitationProbability)
        } else if data.precipitationProbability > 30 {
            return String(format: "%.0f %% sjanse", data.precipitationProbability)
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
            HStack(spacing: .Trakke.xs) {
                Text(showMore
                    ? String(localized: "common.showLess")
                    : String(localized: "common.showMore"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.brand)
                Image(systemName: "chevron.down")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.brandLight)
                    .rotationEffect(.degrees(showMore ? 180 : 0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, .Trakke.xs)
        }
        .buttonStyle(.plain)
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
                    value: String(format: "%.0f hPa", pressure)
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
                value: String(format: "%.0f %%", data.humidity)
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
