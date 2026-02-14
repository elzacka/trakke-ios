import SwiftUI

struct WeatherWidgetView: View {
    let viewModel: WeatherViewModel
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let forecast = viewModel.forecast {
                    HStack(spacing: 4) {
                        Image(systemName: WeatherViewModel.sfSymbol(for: forecast.current.symbol))
                            .font(.system(size: 14))
                            .foregroundStyle(symbolColor(for: forecast.current.symbol))
                        Text("\(Int(forecast.current.temperature.rounded()))°")
                            .font(.caption.monospacedDigit().bold())
                    }
                } else if viewModel.error != nil {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "cloud")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let forecast = viewModel.forecast {
            return String(localized: "weather.accessibility \(Int(forecast.current.temperature.rounded()))")
        }
        return String(localized: "weather.title")
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
