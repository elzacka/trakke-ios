import SwiftUI

struct WeatherSheet: View {
    @Bindable var viewModel: WeatherViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView(String(localized: "weather.loading"))
                } else if let forecast = viewModel.forecast {
                    forecastContent(forecast)
                } else if let error = viewModel.error {
                    ContentUnavailableView(
                        String(localized: "weather.error"),
                        systemImage: "cloud.slash",
                        description: Text(error)
                    )
                } else {
                    ContentUnavailableView(
                        String(localized: "weather.noData"),
                        systemImage: "location.slash",
                        description: Text(String(localized: "weather.noDataDescription"))
                    )
                }
            }
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "weather.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Forecast Content

    private func forecastContent(_ forecast: WeatherForecast) -> some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Current conditions
                CardSection(String(localized: "weather.current")) {
                    CurrentWeatherCard(data: forecast.current, hourlyData: forecast.hourly)
                }

                // Varsom warnings (avalanche/flood)
                if !viewModel.varsomWarnings.isEmpty {
                    varsomCard(viewModel.varsomWarnings)
                }

                // Sunrise / sunset
                if let daylight = viewModel.daylight {
                    daylightCard(daylight)
                }

                // Water temperature
                if let water = viewModel.waterTemperature,
                   water.oceanTemperature != nil || !water.bathingSpots.isEmpty {
                    waterTemperatureCard(water)
                }

                // Air quality and pollen
                airQualityCard(viewModel.airQuality)

                // 7-day forecast
                CardSection(String(localized: "weather.forecast")) {
                    let scores = forecast.daily.map { outdoorScore($0) }
                    let bestScore = scores.max() ?? 0
                    let bestIndex = scores.firstIndex(of: bestScore)

                    VStack(spacing: 0) {
                        ForEach(Array(forecast.daily.enumerated()), id: \.offset) { index, day in
                            if index > 0 {
                                Divider().padding(.leading, .Trakke.dividerLeading)
                            }
                            NavigationLink(value: index) {
                                dailyRow(day, isBestDay: index == bestIndex && bestScore > 60)
                            }
                            .opacity(index >= 5 ? 0.55 : 1.0)
                        }

                        if forecast.daily.count > 5 {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                            Text(String(localized: "weather.forecast.uncertainty"))
                                .font(Font.Trakke.captionSoft)
                                .foregroundStyle(Color.Trakke.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, .Trakke.xs)
                        }
                    }
                }

                // Attribution (CC BY 4.0 required by MET Norway ToS)
                VStack(alignment: .leading, spacing: .Trakke.xs) {
                    if forecast.fetchedAt.timeIntervalSinceNow < -3600 {
                        Label(String(localized: "weather.mayBeOutdated"), systemImage: "exclamationmark.triangle")
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.warning)
                    }
                    HStack {
                        Text(String(localized: "weather.metAttribution"))
                        Spacer()
                        Text(String(localized: "weather.updated \(formatHour(forecast.fetchedAt))"))
                    }
                    HStack {
                        Text("CC BY 4.0")
                        Spacer()
                    }
                }
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
                .padding(.horizontal, .Trakke.xs)
                .padding(.bottom, .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: Int.self) { dayIndex in
            dayDetailView(dayIndex: dayIndex, forecast: forecast)
        }
    }

    // MARK: - Current Weather Card

    /// Standalone view with its own @State so popovers work independently
    /// in both the main sheet and pushed day detail views.
    private struct CurrentWeatherCard: View {
        let data: WeatherData
        var hourlyData: [WeatherData] = []
        var dayLabel: String?

        @State private var showWindDetail = false
        @State private var showPrecipDetail = false
        @State private var showPressureDetail = false
        @State private var showTempDetail = false
        @State private var showAssessmentDetail = false
        @State private var showUVDetail = false

        var body: some View {
            let wc = WeatherService.windChill(temperature: data.temperature, windSpeedMs: data.windSpeed)
            VStack(spacing: .Trakke.lg) {
                // Outdoor assessment — the "should I go?" answer
                assessmentBanner

                // Upcoming weather change — the "rain starts at 14:00" warning
                if let change = WeatherService.upcomingChange(current: data, hourly: hourlyData) {
                    upcomingChangeBanner(change)
                }

                // UV warning — only when actionable (UV ≥ 3)
                if let uv = data.uvIndex, uv >= 3 {
                    uvBanner(uv: uv)
                }

                HStack(spacing: .Trakke.lg) {
                    Image(data.symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: .Trakke.touchComfortable, height: .Trakke.touchComfortable)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                        Text("\(Int(data.temperature.rounded()))\u{00B0}")
                            .font(Font.Trakke.temperature)
                            .foregroundStyle(Color.Trakke.text)

                        if let wc {
                            Text(String(localized: "weather.feelsLike \(Int(wc.rounded()))"))
                                .font(Font.Trakke.caption)
                                .foregroundStyle(wc < -10 ? Color.Trakke.red : Color.Trakke.textTertiary)
                        }

                        tappableLabel(
                            WeatherViewModel.conditionText(for: data.symbol)
                        )
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showTempDetail = true }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(String(localized: "weather.tapHint"))
                    .trakkeTooltip(isPresented: $showTempDetail) {
                        temperatureTooltipContent(windChill: wc)
                        TooltipArticleLink(articleId: 26)
                    }

                    Spacer()
                }

                Divider()

                HStack(alignment: .top, spacing: .Trakke.sm) {
                    windStat.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    precipStat.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    pressureStat.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        // MARK: - Outdoor Assessment Banner

        private var assessmentBanner: some View {
            let wc = WeatherService.windChill(temperature: data.temperature, windSpeedMs: data.windSpeed)
            let assessment = WeatherService.outdoorAssessment(
                temperature: data.temperature,
                windSpeed: data.windSpeed,
                windGust: data.windGust,
                precipitation: data.precipitation,
                precipitationProbability: data.precipitationProbability
            )
            let gustLevel = WeatherService.gustWarningLevel(data.windGust ?? data.windSpeed)
            let windLevel = WeatherService.windWarningLevel(data.windSpeed)
            let worstLevel = max(gustLevel, windLevel)

            let bannerColor: Color = switch worstLevel {
            case .extreme, .danger: Color.Trakke.red
            case .caution: Color.Trakke.warning
            case .none:
                data.precipitationProbability > 70 && data.precipitation > 1
                    ? Color.Trakke.textSecondary
                    : Color.Trakke.brand
            }

            let icon: String = switch worstLevel {
            case .extreme, .danger: "exclamationmark.triangle.fill"
            case .caution: "exclamationmark.triangle"
            case .none: "figure.hiking"
            }

            return HStack(spacing: .Trakke.sm) {
                Image(systemName: icon)
                    .font(Font.Trakke.captionSoft)
                Text(assessment)
                    .font(Font.Trakke.caption)
                Spacer()
            }
            .foregroundStyle(bannerColor)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.xs)
            .background(bannerColor.opacity(0.08), in: RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { showAssessmentDetail = true }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "weather.assessment.title") + ": " + assessment)
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showAssessmentDetail) {
                assessmentTooltipContent(assessment: assessment, windChill: wc)
            }
        }

        private func assessmentTooltipContent(assessment: String, windChill: Double?) -> TrakkeTooltip {
            let title = dayLabel ?? String(localized: "weather.assessment.title")
            let dirFull = WeatherService.windDirectionFullName(data.windDirection)
            let windDesc = WeatherService.windDescription(data.windSpeed).lowercased()

            // "X betyr at..., Y betyr at..., X+Y fører til... derfor *konklusjon*"
            var parts: [String] = []

            // Temperature + wind chill explanation (cause → effect)
            if let wc = windChill {
                parts.append(String(
                    format: "Temperaturen er %.0f°. Vinden på %.0f meter i sekundet (%@, fra %@) kjøler kroppen ned, så det føles som %d°.",
                    data.temperature, data.windSpeed, windDesc, dirFull, Int(wc.rounded())
                ))
            } else if data.windSpeed >= 3.4 {
                parts.append(String(
                    format: "%.0f° med %@ fra %@.",
                    data.temperature, windDesc, dirFull
                ))
            } else {
                parts.append(String(format: "%.0f° og lite vind.", data.temperature))
            }

            // Gust impact
            if let gust = data.windGust, gust > data.windSpeed * 1.2 {
                parts.append(String(
                    format: "Vindkast opptil %.0f meter i sekundet kan komme brått.",
                    gust
                ))
            }

            // Precipitation — describe what it feels like
            if data.precipitation > 0.1 && data.precipitationProbability > 30 {
                let feelsLike = WeatherService.precipitationFeelsLike(data.precipitation)
                parts.append(String(
                    format: "%.0f %% sjanse for nedbør. %@",
                    data.precipitationProbability, feelsLike
                ))
            } else if data.precipitationProbability < 20 {
                parts.append("Ingen nedbør ventet.")
            }

            let explanation = parts.joined(separator: " ")

            return TrakkeTooltip(
                title: title,
                text: explanation,
                sections: [(header: "", text: assessment)]
            )
        }

        // MARK: - Upcoming Change Banner

        private func upcomingChangeBanner(_ change: WeatherService.UpcomingChange) -> some View {
            let color: Color = switch change.severity {
            case .danger, .extreme: Color.Trakke.red
            case .caution: Color.Trakke.warning
            case .none: Color.Trakke.textSecondary
            }
            return HStack(spacing: .Trakke.sm) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(Font.Trakke.captionSoft)
                Text(change.description)
                    .font(Font.Trakke.caption)
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.xs)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }

        // MARK: - UV Banner (contextual, only when UV ≥ 3)

        private func uvBanner(uv: Double) -> some View {
            let level = WeatherService.uvLevel(uv)
            let desc = WeatherService.uvDescription(uv)

            let color: Color = switch level {
            case .low: Color.Trakke.textTertiary
            case .moderate: Color.Trakke.warning
            case .high: Color.Trakke.warning
            case .veryHigh, .extreme: Color.Trakke.red
            }

            return HStack(spacing: .Trakke.sm) {
                Image(systemName: "sun.max.fill")
                    .font(Font.Trakke.captionSoft)
                Text(String(
                    format: "%@ %.0f (%@)",
                    String(localized: "weather.uv.title"),
                    uv,
                    desc
                ))
                    .font(Font.Trakke.caption)
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.xs)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { showUVDetail = true }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(
                format: "%@ %.0f, %@",
                String(localized: "weather.uv.title"),
                uv,
                desc
            ))
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showUVDetail) {
                uvTooltipContent(uv: uv)
                TooltipArticleLink(articleId: 25)
            }
        }

        private func uvTooltipContent(uv: Double) -> TrakkeTooltip {
            let desc = WeatherService.uvDescription(uv)
            let impact = WeatherService.uvOutdoorImpact(uv)
            let cloudNote = String(localized: "weather.uv.cloudNote")
            let snowNote = String(localized: "weather.uv.snowNote")

            let explanation = String(
                format: "UV-indeks %.0f betyr %@ UV-stråling. %@\n\n%@\n\n%@",
                uv, desc.lowercased(), impact, cloudNote, snowNote
            )

            return TrakkeTooltip(
                title: String(format: "%@ %.0f — %@", String(localized: "weather.uv.title"), uv, desc),
                text: explanation
            )
        }

        private func temperatureTooltipContent(windChill: Double?) -> TrakkeTooltip {
            let title = "\(Int(data.temperature.rounded()))\u{00B0}"
            let impact = WeatherService.temperatureOutdoorImpact(data.temperature, windChill: windChill)

            let explanation: String
            if let wc = windChill {
                explanation = String(
                    format: "Lufttemperaturen er %.0f°, men vinden på %.0f meter i sekundet gjør at kroppen kjøler seg ned raskere. Det føles som %d° på huden. %@",
                    data.temperature, data.windSpeed, Int(wc.rounded()), impact
                )
            } else {
                explanation = impact
            }

            return TrakkeTooltip(
                title: title,
                text: explanation
            )
        }

        // MARK: - Wind Stat (with gusts)

        private var windStat: some View {
            let dirName = WeatherService.windDirectionName(data.windDirection)
            let desc = WeatherService.windDescription(data.windSpeed)
            let windLevel = WeatherService.windWarningLevel(data.windSpeed)
            let gustLevel = data.windGust.map { WeatherService.gustWarningLevel($0) } ?? .none
            let worstLevel = max(windLevel, gustLevel)

            let color: Color = switch worstLevel {
            case .none: Color.Trakke.textTertiary
            case .caution: Color.Trakke.warning
            case .danger, .extreme: Color.Trakke.red
            }
            let valueColor: Color = switch worstLevel {
            case .none: Color.Trakke.text
            case .caution: Color.Trakke.warning
            case .danger, .extreme: Color.Trakke.red
            }

            return VStack(spacing: .Trakke.xs) {
                Image(systemName: "wind")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(color)

                // Sustained wind + direction
                Text(String(format: "%.0f m/s", data.windSpeed))
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(valueColor)

                // Wind direction as text (fra NV)
                Text(String(localized: "weather.wind.from \(dirName)"))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)

                // Gust line — only show when gusts are significantly stronger
                if let gust = data.windGust, gust > data.windSpeed * 1.2 {
                    let gustColor: Color = switch gustLevel {
                    case .none: Color.Trakke.textSecondary
                    case .caution: Color.Trakke.warning
                    case .danger, .extreme: Color.Trakke.red
                    }
                    Text(String(localized: "weather.wind.gustLabel \(String(format: "%.0f", gust))"))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(gustColor)
                }

                Spacer(minLength: 0)
                tappableLabel(desc, color: color)
            }
            .contentShape(Rectangle())
            .onTapGesture { showWindDetail = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showWindDetail) {
                windTooltipContent
                TooltipArticleLink(articleId: 22)
            }
        }

        private var windTooltipContent: TrakkeTooltip {
            let desc = WeatherService.windDescription(data.windSpeed)
            let dirFull = WeatherService.windDirectionFullName(data.windDirection)
            let landDesc = WeatherService.windLandDescription(data.windSpeed)
            let mountainDesc = WeatherService.windMountainDescription(data.windSpeed)
            let dirContext = WeatherService.windDirectionContext(data.windDirection)

            var parts: [String] = []

            // What the wind speed means
            parts.append(String(
                format: "%.0f meter i sekundet betyr %@.",
                data.windSpeed, desc.lowercased()
            ))

            // Why wind direction matters
            parts.append(String(
                format: "Vinden kommer fra %@. %@",
                dirFull, dirContext
            ))

            // What it means in practice — land and mountain
            parts.append("I lavlandet: \(landDesc)\n\nI fjellet: \(mountainDesc)")

            // Gust explanation with ratio
            if let gust = data.windGust, gust > data.windSpeed * 1.2 {
                let ratio = gust / data.windSpeed
                parts.append(String(
                    format: "Vindkastene kan bli opptil %.0f meter i sekundet — %.1f ganger sterkere enn den jevne vinden. Det betyr at vinden kan slå til plutselig og hardt.",
                    gust, ratio
                ))
            }

            return TrakkeTooltip(
                title: desc,
                text: parts.joined(separator: "\n\n")
            )
        }

        // MARK: - Precipitation Stat (probability + amount combined)

        private var precipStat: some View {
            let label = data.precipitation > 0
                ? WeatherService.precipitationDescription(data.precipitation)
                : String(localized: "weather.precipitation")

            // mm first — that's what determines clothing and safety
            let valueText: String
            if data.precipitation > 0.1 {
                valueText = String(format: "%.1f mm · %.0f%%", data.precipitation, data.precipitationProbability)
            } else if data.precipitationProbability > 0 {
                valueText = String(format: "%.0f%%", data.precipitationProbability)
            } else {
                valueText = String(localized: "weather.precipitation.none")
            }

            return VStack(spacing: .Trakke.xs) {
                Image(systemName: "drop")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                Text(valueText)
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)

                // Description of amount when there is precipitation
                if data.precipitation > 0 {
                    Text(label)
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }

                Spacer(minLength: 0)
                tappableLabel(String(localized: "weather.precipitation"))
            }
            .contentShape(Rectangle())
            .onTapGesture { showPrecipDetail = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showPrecipDetail) {
                precipTooltipContent(label: label)
                TooltipArticleLink(articleId: 23)
            }
        }

        // MARK: - Pressure Stat (replaces humidity)

        private var pressureStat: some View {
            let info = WeatherService.pressureInfo(current: data.pressure, hourly: hourlyData)
            // Show what the trend MEANS, not the measurement
            let trendText: String = switch info?.trend {
            case .rising: String(localized: "weather.pressure.meaning.rising")
            case .falling: String(localized: "weather.pressure.meaning.falling")
            case .stable: String(localized: "weather.pressure.meaning.stable")
            case .none: ""
            }
            let trendColor: Color = switch info?.trend {
            case .falling: Color.Trakke.warning
            case .rising: Color.Trakke.green
            case .stable, .none: Color.Trakke.textTertiary
            }

            return VStack(spacing: .Trakke.xs) {
                Image(systemName: "barometer")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(trendColor)

                if let info {
                    // Primary value — the number, consistent with wind/precip
                    Text(String(format: "%.0f hPa", info.currentHPa))
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                        .foregroundStyle(Color.Trakke.text)

                    // Trend meaning as secondary detail
                    Text(trendText)
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(trendColor)
                } else if let pressure = data.pressure {
                    Text(String(format: "%.0f hPa", pressure))
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                        .foregroundStyle(Color.Trakke.text)
                } else {
                    Text("–")
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }

                Spacer(minLength: 0)
                tappableLabel(String(localized: "weather.pressure"))
            }
            .contentShape(Rectangle())
            .onTapGesture { showPressureDetail = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showPressureDetail) {
                pressureTooltipContent(info: info)
                TooltipArticleLink(articleId: 24)
            }
        }

        private func precipTooltipContent(label: String) -> TrakkeTooltip {
            let feelsLike = WeatherService.precipitationFeelsLike(data.precipitation)
            let impact = WeatherService.precipitationOutdoorImpact(data.precipitation)

            let explanation: String
            if data.precipitationProbability < 10 {
                explanation = feelsLike
            } else if data.precipitation > 0.1 {
                // Lead with what it feels like, then the evidence
                explanation = String(
                    format: "%.0f %% sjanse for nedbør. %@\n\n%@",
                    data.precipitationProbability, feelsLike, impact
                )
            } else {
                explanation = String(
                    format: "%.0f %% sjanse for nedbør, men lite mengde ventet. %@",
                    data.precipitationProbability, feelsLike
                )
            }

            return TrakkeTooltip(
                title: label,
                text: explanation
            )
        }

        private func pressureTooltipContent(info: WeatherService.PressureInfo?) -> TrakkeTooltip {
            guard let info else {
                let text = data.pressure != nil
                    ? String(format: "Lufttrykket er %.0f hPa. ", data.pressure!) + String(localized: "weather.pressure.impact.noTrend")
                    : String(localized: "weather.pressure.impact.noTrend")
                return TrakkeTooltip(
                    title: String(localized: "weather.pressure"),
                    text: text
                )
            }
            let impactText = WeatherService.pressureOutdoorImpact(info.trend)
            let explanation: String
            if info.trend == .stable {
                explanation = String(
                    format: "Lufttrykket har holdt seg på %.0f hPa %@. %@",
                    info.currentHPa,
                    String(localized: "weather.pressure.last3h"),
                    impactText
                )
            } else {
                explanation = String(
                    format: "Lufttrykket har gått fra %.0f til %.0f hPa %@. %@",
                    info.earlierHPa, info.currentHPa,
                    String(localized: "weather.pressure.last3h"),
                    impactText
                )
            }
            return TrakkeTooltip(
                title: String(localized: "weather.pressure"),
                text: explanation
            )
        }

        private func tappableLabel(_ text: String, color: Color = Color.Trakke.textTertiary) -> some View {
            Text(text)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(color)
                .padding(.horizontal, .Trakke.sm)
                .padding(.vertical, .Trakke.labelGap)
                .background(color.opacity(0.12), in: Capsule())
        }

        private func tappableLabel(_ icon: String, _ text: String, color: Color) -> some View {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(text)
            }
            .font(Font.Trakke.captionSoft)
            .foregroundStyle(color)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.labelGap)
            .background(color.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Daylight Card

    private func daylightCard(_ daylight: SolarCalculator.DaylightInfo) -> some View {
        CardSection(String(localized: "weather.daylight")) {
            HStack(spacing: 0) {
                daylightStat(
                    icon: "sunrise.fill",
                    value: daylight.sunriseFormatted,
                    label: String(localized: "weather.sunrise")
                )
                .frame(maxWidth: .infinity)

                daylightStat(
                    icon: "sunset.fill",
                    value: daylight.sunsetFormatted,
                    label: String(localized: "weather.sunset")
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func daylightStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: .Trakke.xs) {
            Image(systemName: icon)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
            Text(value)
                .font(Font.Trakke.bodyRegular.monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
            Text(label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
    }

    // MARK: - Water Temperature Card

    private func waterTemperatureCard(_ water: WaterTemperatureResult) -> some View {
        CardSection(String(localized: "weather.waterTemperature")) {
            VStack(spacing: 0) {
                // Ocean temperature (MET Oceanforecast)
                if let ocean = water.oceanTemperature {
                    HStack(spacing: .Trakke.md) {
                        Image(systemName: "water.waves")
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        Text(String(localized: "weather.seaTemperature"))
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)

                        Spacer()

                        Text(String(format: "%.1f°", ocean.temperature))
                            .font(Font.Trakke.bodyRegular.monospacedDigit())
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .padding(.vertical, .Trakke.xs)
                }

                // Bathing spots (Havvarsel-Frost)
                ForEach(Array(water.bathingSpots.enumerated()), id: \.offset) { index, spot in
                    if water.oceanTemperature != nil || index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    HStack(spacing: .Trakke.md) {
                        Image(systemName: "figure.open.water.swim")
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        Text(spot.name ?? String(localized: "weather.bathingSpot"))
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                            .lineLimit(1)

                        Spacer()

                        Text(String(format: "%.1f°", spot.temperature))
                            .font(Font.Trakke.bodyRegular.monospacedDigit())
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .padding(.vertical, .Trakke.xs)
                }

            }
        }
    }

    // MARK: - Air Quality Card

    private func airQualityCard(_ aq: AirQualityData?) -> some View {
        CardSection(String(localized: "weather.airQuality")) {
            VStack(alignment: .leading, spacing: .Trakke.sm) {
                if let aq {
                    let color = aq.aqiClass.color
                    HStack(spacing: .Trakke.md) {
                        Image(systemName: "aqi.medium")
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(color)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                            Text(aq.aqiClass.norwegianName)
                                .font(Font.Trakke.bodyMedium)
                                .foregroundStyle(Color.Trakke.text)
                            Text(aq.aqiClass.healthAdvice)
                                .font(Font.Trakke.caption)
                                .foregroundStyle(Color.Trakke.textSecondary)
                        }
                    }

                    Divider()
                }

                Link(destination: URL(string: "https://www.naaf.no/pollenvarsel")!) {
                    HStack(spacing: .Trakke.xs) {
                        Text("NAAF — Pollenvarsel")
                            .font(Font.Trakke.caption)
                        Image(systemName: "arrow.up.right")
                            .font(Font.Trakke.captionSoft)
                    }
                    .foregroundStyle(Color.Trakke.brand)
                }
            }
        }
    }

    // MARK: - Varsom Warnings

    private func varsomCard(_ warnings: [VarsomWarning]) -> some View {
        CardSection(String(localized: "weather.varsom")) {
            VStack(spacing: 0) {
                ForEach(Array(warnings.enumerated()), id: \.element.id) { index, warning in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    VarsomWarningRow(warning: warning)
                }
            }
        }
    }

    private struct VarsomWarningRow: View {
        let warning: VarsomWarning
        @State private var showDetail = false

        var body: some View {
            HStack(spacing: .Trakke.md) {
                Image(systemName: warning.type == .avalanche ? "mountain.2.fill" : "drop.triangle.fill")
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(varsomColor(warning.dangerLevel))
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(warning.type == .avalanche
                        ? String(localized: "weather.varsom.avalanche")
                        : String(localized: "weather.varsom.flood"))
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)
                    Text("\(warning.dangerName) – \(warning.regionName)")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSecondary)
                }

                Spacer()

                Text(String(warning.dangerLevel))
                    .font(Font.Trakke.bodyMedium.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(varsomColor(warning.dangerLevel))
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
            }
            .padding(.vertical, .Trakke.xs)
            .contentShape(Rectangle())
            .onTapGesture { showDetail = true }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                (warning.type == .avalanche
                    ? String(localized: "weather.varsom.avalanche")
                    : String(localized: "weather.varsom.flood"))
                + ", " + warning.dangerName
                + ", " + warning.regionName
                + ", " + String(localized: "weather.varsom.level \(warning.dangerLevel)")
            )
            .accessibilityHint(String(localized: "weather.tapHint"))
            .trakkeTooltip(isPresented: $showDetail) {
                varsomTooltipContent
                TooltipSourceLink(label: "varsom.no", url: URL(string: "https://www.varsom.no/")!)
            }
        }

        private var varsomTooltipContent: TrakkeTooltip {
            let typeName = warning.type == .avalanche
                ? String(localized: "weather.varsom.avalanche")
                : String(localized: "weather.varsom.flood")
            let title = "\(typeName) – \(warning.dangerName)"

            let text = if warning.mainText.isEmpty {
                "\(warning.dangerName) i \(warning.regionName)."
            } else {
                // Tone down exclamation marks from Varsom API text
                warning.mainText
                    .replacingOccurrences(of: "!", with: ".")
                    .replacingOccurrences(of: "..", with: ".")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return TrakkeTooltip(
                title: title,
                text: text
            )
        }

        private func varsomColor(_ level: Int) -> Color {
            switch level {
            case 2: return Color.Trakke.yellow
            case 3: return Color.Trakke.warning
            case 4, 5: return Color.Trakke.red
            default: return Color.Trakke.green
            }
        }
    }

    // MARK: - Daily Row

    /// Compute a simple outdoor quality score (0–100) from weather data.
    /// Higher = better conditions. Used for visual hierarchy in the 7-day list.
    private func outdoorScore(_ day: WeatherData) -> Double {
        var score = 100.0

        // Wind penalty
        let windLevel = WeatherService.windWarningLevel(day.windSpeed)
        let gustLevel = WeatherService.gustWarningLevel(day.windGust ?? day.windSpeed)
        let worstWind = max(windLevel, gustLevel)
        switch worstWind {
        case .extreme: score -= 60
        case .danger: score -= 40
        case .caution: score -= 20
        case .none: break
        }

        // Precipitation penalty
        if day.precipitationProbability > 70 { score -= 20 }
        else if day.precipitationProbability > 40 { score -= 10 }

        // Temperature penalty (too cold or too hot)
        let wc = WeatherService.windChill(temperature: day.temperature, windSpeedMs: day.windSpeed)
        let effective = wc ?? day.temperature
        if effective < -10 { score -= 25 }
        else if effective < 0 { score -= 10 }

        return max(0, min(100, score))
    }

    private func dailyRow(_ day: WeatherData, isBestDay: Bool) -> some View {
        let gustLevel = WeatherService.gustWarningLevel(day.windGust ?? day.windSpeed)
        let windLevel = WeatherService.windWarningLevel(day.windSpeed)
        let worstWind = max(windLevel, gustLevel)

        let windColor: Color = switch worstWind {
        case .none: Color.Trakke.textTertiary
        case .caution: Color.Trakke.warning
        case .danger, .extreme: Color.Trakke.red
        }

        return HStack(spacing: .Trakke.sm) {
            Text(formatDayName(day.time))
                .font(isBestDay ? Font.Trakke.bodyMedium : Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(day.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(spacing: 1) {
                if let min = day.temperatureMin, let max = day.temperatureMax {
                    HStack(spacing: 0) {
                        Text("\(Int(min.rounded()))°")
                            .foregroundStyle(Color.Trakke.textTertiary)
                        Text("/")
                            .foregroundStyle(Color.Trakke.textTertiary)
                        Text("\(Int(max.rounded()))°")
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                } else {
                    Text("\(Int(day.temperature.rounded()))°")
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                        .foregroundStyle(Color.Trakke.text)
                }

                // Overnight low — critical for campers
                if let nightLow = day.overnightLow, nightLow < 5 {
                    Text(String(format: "natt: %d°", Int(nightLow.rounded())))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(nightLow < -5 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: .Trakke.sm) {
                    if day.precipitationProbability > 0 {
                        HStack(spacing: .Trakke.labelGap) {
                            Image(systemName: "drop")
                                .font(Font.Trakke.captionSoft)
                            Text(String(format: "%.0f%%", day.precipitationProbability))
                        }
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSecondary)
                    }

                    Text(String(format: "%.0f m/s", day.windSpeed))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(windColor)
                }

                // Show max gust for the day if significantly stronger than average
                if let gust = day.windGust, gust > day.windSpeed * 1.2 {
                    Text(String(localized: "weather.wind.gustLabel \(String(format: "%.0f", gust))"))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(windColor)
                }

                // UV when actionable
                if let uv = day.uvIndex, uv >= 3 {
                    HStack(spacing: .Trakke.labelGap) {
                        Image(systemName: "sun.max.fill")
                            .font(Font.Trakke.captionSoft)
                        Text(String(format: "UV %.0f", uv))
                    }
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(uv >= 6 ? Color.Trakke.warning : Color.Trakke.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, .Trakke.md)
        .opacity(worstWind >= .danger ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dailyAccessibilityLabel(day))
    }

    private func dailyAccessibilityLabel(_ day: WeatherData) -> String {
        let dayName = formatDayName(day.time)
        let condition = WeatherViewModel.conditionText(for: day.symbol)
        let temp: String
        if let min = day.temperatureMin, let max = day.temperatureMax {
            temp = "\(Int(min.rounded()))° / \(Int(max.rounded()))°"
        } else {
            temp = "\(Int(day.temperature.rounded()))°"
        }
        var label = "\(dayName), \(condition), \(temp)"
        if let gust = day.windGust, gust > day.windSpeed * 1.2 {
            label += ", \(String(localized: "weather.wind.gustLabel \(String(format: "%.0f", gust))"))"
        }
        return label
    }

    // MARK: - Day Detail

    private func dayDetailView(dayIndex: Int, forecast: WeatherForecast) -> some View {
        let day = forecast.daily[dayIndex]
        let hours = hoursForDay(dayIndex, forecast: forecast)
        let isToday = Calendar.current.isDateInToday(day.time)
        let summaryTitle = isToday
            ? String(localized: "weather.current")
            : String(localized: "weather.daySummary")

        // Day-specific assessment label: "I dag ute" / "Lørdag ute" / "Søndag ute"
        let assessmentLabel: String? = isToday ? nil : {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "nb_NO")
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: day.time).capitalized
            return "\(dayName) på tur"
        }()

        return ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                if hours.isEmpty {
                    CardSection(String(localized: "weather.daySummary")) {
                        CurrentWeatherCard(data: day, hourlyData: hours, dayLabel: assessmentLabel)
                    }
                } else {
                    CardSection(summaryTitle) {
                        CurrentWeatherCard(data: day, hourlyData: hours, dayLabel: assessmentLabel)
                    }

                    CardSection(String(localized: "weather.hourly")) {
                        VStack(spacing: 0) {
                            ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
                                if index > 0 {
                                    Divider().padding(.leading, .Trakke.dividerLeading)
                                }
                                hourlyRow(hour)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.lg)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(formatFullDate(day.time))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hoursForDay(_ dayIndex: Int, forecast: WeatherForecast) -> [WeatherData] {
        guard dayIndex < forecast.daily.count else { return [] }
        let dayDate = forecast.daily[dayIndex].time
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return forecast.hourly.filter { $0.time >= dayStart && $0.time < dayEnd }
    }

    // MARK: - Hourly Row

    private func hourlyRow(_ hour: WeatherData) -> some View {
        let gustLevel = WeatherService.gustWarningLevel(hour.windGust ?? hour.windSpeed)
        let windLevel = WeatherService.windWarningLevel(hour.windSpeed)
        let worstWind = max(windLevel, gustLevel)
        let windColor: Color = switch worstWind {
        case .none: Color.Trakke.textTertiary
        case .caution: Color.Trakke.warning
        case .danger, .extreme: Color.Trakke.red
        }

        return HStack(spacing: .Trakke.sm) {
            Text(formatHour(hour.time))
                .font(Font.Trakke.bodyRegular.monospacedDigit())
                .foregroundStyle(Color.Trakke.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(hour.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(spacing: 1) {
                Text("\(Int(hour.temperature.rounded()))°")
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)

                if let wc = WeatherService.windChill(temperature: hour.temperature, windSpeedMs: hour.windSpeed) {
                    Text(String(format: "(%d°)", Int(wc.rounded())))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(wc < -10 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: .Trakke.sm) {
                    if hour.precipitation > 0 {
                        HStack(spacing: .Trakke.labelGap) {
                            Image(systemName: "drop.fill")
                                .font(Font.Trakke.captionSoft)
                            Text(String(format: "%.1f mm", hour.precipitation))
                        }
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSecondary)
                    }

                    Text(String(format: "%.0f m/s", hour.windSpeed))
                        .font(Font.Trakke.caption.monospacedDigit())
                        .foregroundStyle(windColor)
                }

                if let gust = hour.windGust, gust > hour.windSpeed * 1.2 {
                    Text(String(localized: "weather.wind.gustLabel \(String(format: "%.0f", gust))"))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(windColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Formatters

    private static let dayNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "EEE d."
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateStyle = .long
        return formatter
    }()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func formatDayName(_ date: Date) -> String {
        Self.dayNameFormatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }

    private func formatHour(_ date: Date) -> String {
        Self.hourFormatter.string(from: date)
    }
}
