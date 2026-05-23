import SwiftUI

struct WeatherWidgetView: View {
    let viewModel: WeatherViewModel
    var onTap: () -> Void

    /// Samme størrelse som de andre kart-knappene (kompass, zoom, FAB).
    private let buttonSize: CGFloat = 56

    var body: some View {
        Button(action: onTap) {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: buttonSize, height: buttonSize)
                } else if let forecast = viewModel.forecast {
                    VStack(spacing: .Trakke.labelGap) {
                        Image(forecast.current.symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text("\(Int(forecast.current.temperature.rounded()))°")
                            .font(Font.Trakke.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.Trakke.text)
                    }
                    .frame(width: buttonSize, height: buttonSize)
                } else if viewModel.error != nil {
                    Image(systemName: "cloud.slash")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(width: buttonSize, height: buttonSize)
                } else {
                    Image(systemName: "cloud")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(width: buttonSize, height: buttonSize)
                }
            }
            .background(Color.Trakke.surface)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
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
