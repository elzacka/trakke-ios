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
                        .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                } else if let forecast = viewModel.forecast {
                    VStack(spacing: 2) {
                        Image(forecast.current.symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: .Trakke.xxl, height: .Trakke.xxl)
                        Text("\(Int(forecast.current.temperature.rounded()))°")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                } else if viewModel.error != nil {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                } else {
                    Image(systemName: "cloud")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                }
            }
            .background(Color.Trakke.background)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
            .trakkeControlShadow()
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let forecast = viewModel.forecast {
            return String(localized: "weather.accessibility \(Int(forecast.current.temperature.rounded()))")
        }
        return String(localized: "weather.title")
    }
}
