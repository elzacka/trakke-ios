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
                    if let dayIndex = viewModel.selectedDayIndex {
                        dayDetailView(dayIndex: dayIndex)
                    } else {
                        forecastList(forecast)
                    }
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
            .navigationTitle(String(localized: "weather.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Forecast List

    private func forecastList(_ forecast: WeatherForecast) -> some View {
        List {
            // Current conditions
            Section(String(localized: "weather.current")) {
                currentWeatherRow(forecast.current)
            }

            // 7-day forecast
            Section(String(localized: "weather.forecast")) {
                ForEach(Array(forecast.daily.enumerated()), id: \.offset) { index, day in
                    Button {
                        viewModel.selectDay(index)
                    } label: {
                        dailyRow(day)
                    }
                }
            }

            // Attribution
            Section {
                HStack {
                    Text("MET Norway")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "weather.updated \(formatTime(forecast.fetchedAt))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Current Weather

    private func currentWeatherRow(_ data: WeatherData) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: WeatherViewModel.sfSymbol(for: data.symbol))
                    .font(.system(size: 40))
                    .foregroundStyle(symbolColor(for: data.symbol))

                Text("\(Int(data.temperature.rounded()))°")
                    .font(.system(size: 48, weight: .light, design: .rounded))

                Spacer()
            }

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
        .padding(.vertical, 4)
    }

    private func weatherStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily Row

    private func dailyRow(_ day: WeatherData) -> some View {
        HStack(spacing: 12) {
            Text(formatDayName(day.time))
                .font(.subheadline)
                .frame(width: 50, alignment: .leading)

            Image(systemName: WeatherViewModel.sfSymbol(for: day.symbol))
                .foregroundStyle(symbolColor(for: day.symbol))
                .frame(width: 24)

            Text("\(Int(day.temperature.rounded()))°")
                .font(.subheadline.monospacedDigit())
                .frame(width: 32, alignment: .trailing)

            Spacer()

            HStack(spacing: 8) {
                Label(String(format: "%.0f m/s", day.windSpeed), systemImage: "wind")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if day.precipitationProbability > 0 {
                    Label(String(format: "%.0f%%", day.precipitationProbability), systemImage: "drop")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Day Detail

    private func dayDetailView(dayIndex: Int) -> some View {
        List {
            if let day = viewModel.selectedDay {
                Section {
                    HStack {
                        Button {
                            viewModel.clearDaySelection()
                        } label: {
                            Label(String(localized: "weather.back"), systemImage: "chevron.left")
                        }
                        Spacer()
                        Text(formatFullDate(day.time))
                            .font(.headline)
                        Spacer()
                    }
                }

                let hours = viewModel.hoursForSelectedDay
                if hours.isEmpty {
                    Section(String(localized: "weather.daySummary")) {
                        currentWeatherRow(day)
                    }
                } else {
                    Section(String(localized: "weather.hourly")) {
                        ForEach(hours, id: \.time) { hour in
                            hourlyRow(hour)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hourly Row

    private func hourlyRow(_ hour: WeatherData) -> some View {
        HStack(spacing: 12) {
            Text(formatHour(hour.time))
                .font(.subheadline.monospacedDigit())
                .frame(width: 44, alignment: .leading)

            Image(systemName: WeatherViewModel.sfSymbol(for: hour.symbol))
                .foregroundStyle(symbolColor(for: hour.symbol))
                .frame(width: 24)

            Text("\(Int(hour.temperature.rounded()))°")
                .font(.subheadline.monospacedDigit())
                .frame(width: 32, alignment: .trailing)

            Spacer()

            HStack(spacing: 8) {
                Label(String(format: "%.0f m/s", hour.windSpeed), systemImage: "wind")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if hour.precipitation > 0 {
                    Label(String(format: "%.1f mm", hour.precipitation), systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Formatters

    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "EEE d."
        return formatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func symbolColor(for symbol: String) -> Color {
        if symbol.contains("clearsky") || symbol.contains("fair") {
            return .orange
        } else if symbol.contains("rain") || symbol.contains("sleet") {
            return .blue
        } else if symbol.contains("snow") {
            return .cyan
        } else if symbol.contains("thunder") {
            return .purple
        }
        return .secondary
    }
}
