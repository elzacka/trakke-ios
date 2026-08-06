import SwiftUI

struct WeatherSheet: View {
    @Bindable var viewModel: WeatherViewModel
    /// Inline-modus: ingen NavigationStack/title – kalleren håndterer
    /// navigation-konteksten. Brukes når WeatherSheet embeddes som en
    /// underfane i Info-fanen.
    var inline = false

    var body: some View {
        if inline {
            weatherStates
                .tint(Color.Trakke.brand)
        } else {
            NavigationStack {
                weatherStates
                    .tint(Color.Trakke.brand)
                    .navigationTitle(String(localized: "weather.title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private var weatherStates: some View {
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

    // MARK: - Forecast Content

    @ViewBuilder
    private func forecastContent(_ forecast: WeatherForecast) -> some View {
        if inline {
            forecastVStack(forecast)
                .navigationDestination(for: Int.self) { dayIndex in
                    dayDetailView(dayIndex: dayIndex, forecast: forecast)
                }
        } else {
            ScrollView {
                forecastVStack(forecast)
            }
            .background(Color.Trakke.background)
            .navigationDestination(for: Int.self) { dayIndex in
                dayDetailView(dayIndex: dayIndex, forecast: forecast)
            }
        }
    }

    private func forecastVStack(_ forecast: WeatherForecast) -> some View {
        VStack(spacing: .Trakke.cardGap) {
            CardSection(String(localized: "weather.current")) {
                CurrentConditionsCard(
                    data: forecast.current,
                    water: viewModel.waterTemperature,
                    airQuality: viewModel.airQuality,
                    daylight: viewModel.daylight
                )
            }

            if hasAnyWarning(forecast: forecast) {
                warningsSection(forecast: forecast)
            }

            forecastSection(forecast)

            attributionFooter(forecast)
        }
        .padding(.horizontal, inline ? 0 : .Trakke.sheetHorizontal)
        .padding(.top, inline ? 0 : .Trakke.sheetTop)
    }

    // MARK: - Warnings Section
    //
    // Slår sammen Varsom + UV ≥ 3 + endringsvarsel + dårlig luftkvalitet
    // i én seksjon – der dukker bare opp hvis det FAKTISK er noe å varsle.

    private func hasAnyWarning(forecast: WeatherForecast) -> Bool {
        if !viewModel.varsomWarnings.isEmpty { return true }
        if let uv = forecast.current.uvIndex, uv >= 3 { return true }
        if WeatherService.upcomingChange(current: forecast.current, hourly: forecast.hourly) != nil { return true }
        if let aq = viewModel.airQuality, aq.aqiClass.rawValue >= 3 { return true }
        return false
    }

    @ViewBuilder
    private func warningsSection(forecast: WeatherForecast) -> some View {
        CardSection(String(localized: "weather.warnings")) {
            VStack(spacing: 0) {
                let warnings = viewModel.varsomWarnings
                ForEach(warnings) { warning in
                    if warnings.first?.id != warning.id {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    varsomRow(warning)
                }

                if let change = WeatherService.upcomingChange(current: forecast.current, hourly: forecast.hourly) {
                    if !warnings.isEmpty {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    upcomingChangeRow(change)
                }

                if let uv = forecast.current.uvIndex, uv >= 3 {
                    if !warnings.isEmpty || WeatherService.upcomingChange(current: forecast.current, hourly: forecast.hourly) != nil {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    uvRow(uv: uv)
                }

                if let aq = viewModel.airQuality, aq.aqiClass.rawValue >= 3 {
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    airQualityWarningRow(aq)
                }
            }
        }
    }

    private func varsomRow(_ warning: VarsomWarning) -> some View {
        HStack(spacing: .Trakke.md) {
            Image(systemName: warning.type == .avalanche ? "mountain.2.fill" : "drop.triangle.fill")
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(varsomColor(warning.dangerLevel))
                .frame(width: .Trakke.iconSlot)
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
                if !warning.mainText.isEmpty {
                    Text(warning.mainText
                        .replacingOccurrences(of: "!", with: ".")
                        .replacingOccurrences(of: "..", with: ".")
                        .trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Text(String(warning.dangerLevel))
                .font(Font.Trakke.bodyMedium.monospacedDigit())
                .foregroundStyle(Color.Trakke.textInverse)
                .frame(width: 28, height: 28)
                .background(varsomColor(warning.dangerLevel))
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
    }

    private func upcomingChangeRow(_ change: WeatherService.UpcomingChange) -> some View {
        let color: Color = switch change.severity {
        case .danger, .extreme: Color.Trakke.red
        case .caution: Color.Trakke.warning
        case .none: Color.Trakke.textSecondary
        }
        return HStack(spacing: .Trakke.md) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(color)
                .frame(width: .Trakke.iconSlot)
                .accessibilityHidden(true)

            Text(change.description)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)

            Spacer()
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(change.description)
    }

    private func uvRow(uv: Double) -> some View {
        let color: Color = uv >= 6 ? Color.Trakke.warning : Color.Trakke.textSecondary
        let advice: String = uv >= 8
            ? String(localized: "weather.uv.high.advice")
            : uv >= 6
                ? String(localized: "weather.uv.moderate.advice")
                : String(localized: "weather.uv.low.advice")
        return HStack(spacing: .Trakke.md) {
            Image(systemName: "sun.max.fill")
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(color)
                .frame(width: .Trakke.iconSlot)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(String(localized: "weather.uv.label \(String(format: "%.0f", uv))"))
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)
                Text(advice)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
    }

    private func airQualityWarningRow(_ aq: AirQualityData) -> some View {
        HStack(spacing: .Trakke.md) {
            Image(systemName: "aqi.medium")
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(aq.aqiClass.color)
                .frame(width: .Trakke.iconSlot)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(aq.aqiClass.norwegianName)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)
                Text(aq.aqiClass.healthAdvice)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, .Trakke.sm)
        .accessibilityElement(children: .combine)
    }

    private func varsomColor(_ level: Int) -> Color {
        switch level {
        // Nivå 1 («lavt») bruker en mørkere grønn enn Color.Trakke.green
        // slik at hvit badge-tekst når ≥4.5:1 kontrast (WCAG 1.4.3).
        // Nivåene 2–5 passer allerede og er uendret.
        case 1: return Color(hex: "217a45")
        case 2: return Color.Trakke.yellow
        case 3: return Color.Trakke.warning
        case 4, 5: return Color.Trakke.red
        default: return Color(hex: "217a45")
        }
    }

    // MARK: - Weekly Section

    private func weeklyList(forecast: WeatherForecast) -> some View {
        let scores = forecast.daily.map { outdoorScore($0) }
        let bestScore = scores.max() ?? 0
        let bestIndex = scores.firstIndex(of: bestScore)

        return VStack(spacing: 0) {
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

    // MARK: - Attribution Footer

    private func attributionFooter(_ forecast: WeatherForecast) -> some View {
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

    // MARK: - Outdoor Score (for 7-day "beste tur-dag")

    private func outdoorScore(_ day: WeatherData) -> Double {
        var score = 100.0

        let windLevel = WeatherService.windWarningLevel(day.windSpeed)
        let gustLevel = WeatherService.gustWarningLevel(day.windGust ?? day.windSpeed)
        let worstWind = max(windLevel, gustLevel)
        switch worstWind {
        case .extreme: score -= 60
        case .danger: score -= 40
        case .caution: score -= 20
        case .none: break
        }

        if day.precipitationProbability > 70 { score -= 20 }
        else if day.precipitationProbability > 40 { score -= 10 }

        let wc = WeatherService.windChill(temperature: day.temperature, windSpeedMs: day.windSpeed)
        let effective = wc ?? day.temperature
        if effective < -10 { score -= 25 }
        else if effective < 0 { score -= 10 }

        return max(0, min(100, score))
    }

    // MARK: - Daily Row

    /// 7-dagers-seksjon. Forklaringsarket er borte sammen med kolonnene det
    /// forklarte: raden viser nå dag, symbol og temperatur, og det trenger
    /// ingen legende.
    @ViewBuilder
    private func forecastSection(_ forecast: WeatherForecast) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "weather.forecast"))
                .font(Font.Trakke.sectionHeader)
                .foregroundStyle(Color.Trakke.textSoft)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .Trakke.xs)
                .padding(.bottom, .Trakke.sm)

            VStack(alignment: .leading, spacing: 0) {
                weeklyList(forecast: forecast)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .Trakke.cardPadH)
            .padding(.vertical, .Trakke.cardPadV)
            .background(Color.Trakke.surface)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
    }

    private func dailyRow(_ day: WeatherData, isBestDay: Bool) -> some View {
        let gustLevel = WeatherService.gustWarningLevel(day.windGust ?? day.windSpeed)
        let windLevel = WeatherService.windWarningLevel(day.windSpeed)
        // Vindnivået står igjen fordi raden fortsatt dempes ved farlig vind,
        // selv om selve vindtallet er flyttet til dagsvisningen.
        let worstWind = max(windLevel, gustLevel)

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

                if let nightLow = day.overnightLow, nightLow < 5 {
                    Text(String(localized: "weather.overnightLow \(Int(nightLow.rounded()))"))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(nightLow < -5 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        // Ukevarselet svarer på ett spørsmål: hvilken dag skal jeg gå? Dag,
        // symbol og temperatur er nok til å velge. Nedbør, vind, kast og UV
        // står i dagsvisningen og under «Akkurat nå», der du er når du
        // først har valgt dag.
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
        // Raden dempes visuelt ved farlig vind. Det er et signal VoiceOver
        // ikke kan se, så det må sies. Vindkast som ikke gir demping nevnes
        // ikke lenger – da ville skjermleseren fortalt om noe raden ikke
        // viser, etter at vindtallet flyttet til dagsvisningen.
        let worstWind = max(
            WeatherService.windWarningLevel(day.windSpeed),
            WeatherService.gustWarningLevel(day.windGust ?? day.windSpeed)
        )
        if worstWind >= .danger, let gust = day.windGust {
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

        return ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection(summaryTitle) {
                    CurrentConditionsCard(
                        data: day,
                        water: isToday ? viewModel.waterTemperature : nil,
                        airQuality: isToday ? viewModel.airQuality : nil,
                        daylight: isToday ? viewModel.daylight : nil
                    )
                }

                if !hours.isEmpty {
                    CardSection(String(localized: "weather.hourly")) {
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.time) { hour in
                                if hours.first?.time != hour.time {
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
        .background(Color.Trakke.background)
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

            // Temp og føles-som vises som én linje for å unngå rad-linjeskift.
            HStack(spacing: .Trakke.labelGap) {
                Text("\(Int(hour.temperature.rounded()))°")
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)

                if let wc = WeatherService.windChill(temperature: hour.temperature, windSpeedMs: hour.windSpeed) {
                    Text(String(format: "(%d°)", Int(wc.rounded())))
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(wc < -10 ? Color.Trakke.red : Color.Trakke.textTertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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

// CurrentConditionsCard moved to its own file (Views/Weather/CurrentConditionsCard.swift).
