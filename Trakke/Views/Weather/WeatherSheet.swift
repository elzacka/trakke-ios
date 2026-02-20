import SwiftUI

struct WeatherSheet: View {
    @Bindable var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Forecast Content

    private func forecastContent(_ forecast: WeatherForecast) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current conditions
                CardSection(String(localized: "weather.current")) {
                    currentWeatherCard(forecast.current)
                }

                // 7-day forecast
                CardSection(String(localized: "weather.forecast")) {
                    VStack(spacing: 0) {
                        ForEach(Array(forecast.daily.enumerated()), id: \.offset) { index, day in
                            if index > 0 {
                                Divider().padding(.leading, .Trakke.dividerLeading)
                            }
                            NavigationLink(value: index) {
                                dailyRow(day)
                            }
                        }
                    }
                }

                // Attribution (CC BY 4.0 required by MET Norway ToS)
                VStack(spacing: 4) {
                    HStack {
                        Text("MET Norway")
                        Spacer()
                        Text(String(localized: "weather.updated \(formatHour(forecast.fetchedAt))"))
                    }
                    HStack {
                        Text("CC BY 4.0")
                        Spacer()
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.Trakke.textSoft)
                .padding(.horizontal, 4)
                .padding(.bottom, 16)
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

    private func currentWeatherCard(_ data: WeatherData) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(data.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(data.temperature.rounded()))°")
                        .font(.system(.largeTitle, design: .rounded, weight: .light))
                        .foregroundStyle(Color.Trakke.text)

                    Text(WeatherViewModel.conditionText(for: data.symbol))
                        .font(.subheadline)
                        .foregroundStyle(Color.Trakke.textMuted)
                }

                Spacer()
            }

            Divider()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                weatherStat(
                    icon: "wind",
                    value: String(format: "%.1f m/s", data.windSpeed),
                    label: WeatherService.windDirectionName(data.windDirection)
                )
                weatherStat(
                    icon: "drop",
                    value: String(format: "%.0f%%", data.precipitationProbability),
                    label: String(localized: "weather.precipitation")
                )
                weatherStat(
                    icon: "humidity",
                    value: String(format: "%.0f%%", data.humidity),
                    label: String(localized: "weather.humidity")
                )
            }
        }
    }

    private func weatherStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.Trakke.textSoft)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.Trakke.textSoft)
        }
    }

    // MARK: - Daily Row

    private func dailyRow(_ day: WeatherData) -> some View {
        HStack(spacing: 10) {
            Text(formatDayName(day.time))
                .font(.subheadline)
                .foregroundStyle(Color.Trakke.text)
                .frame(width: 62, alignment: .leading)

            Image(day.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            if let min = day.temperatureMin, let max = day.temperatureMax {
                HStack(spacing: 0) {
                    Text("\(Int(min.rounded()))°")
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(width: 40, alignment: .trailing)
                    Text("/")
                        .font(.subheadline)
                        .foregroundStyle(Color.Trakke.textSoft)
                    Text("\(Int(max.rounded()))°")
                        .foregroundStyle(Color.Trakke.text)
                        .frame(width: 40, alignment: .leading)
                }
                .font(.subheadline.monospacedDigit())
            } else {
                Text("\(Int(day.temperature.rounded()))°")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)
                    .frame(width: 82, alignment: .center)
            }

            Spacer()

            HStack(spacing: 6) {
                if day.precipitationProbability > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", day.precipitationProbability))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textMuted)
                }

                Text(String(format: "%.0f m/s", day.windSpeed))
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
            }

        }
        .padding(.vertical, 10)
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
            VStack(spacing: 24) {
                if hours.isEmpty {
                    CardSection(String(localized: "weather.daySummary")) {
                        currentWeatherCard(day)
                    }
                } else {
                    CardSection(summaryTitle) {
                        currentWeatherCard(day)
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
        HStack(spacing: 0) {
            Text(formatHour(hour.time))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.Trakke.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(hour.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .frame(maxWidth: .infinity)

            Text("\(Int(hour.temperature.rounded()))°")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.Trakke.text)
                .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                if hour.precipitation > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f mm", hour.precipitation))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textMuted)
                }

                Text(String(format: "%.0f m/s", hour.windSpeed))
                    .font(.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
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
