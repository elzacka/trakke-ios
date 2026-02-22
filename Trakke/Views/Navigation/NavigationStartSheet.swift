import SwiftUI
import CoreLocation

struct NavigationStartSheet: View {
    let destination: CLLocationCoordinate2D
    let userLocation: CLLocation?
    let isConnected: Bool
    var onRouteNavigation: () -> Void
    var onCompassNavigation: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var straightLineDistance: Double? {
        guard let userLoc = userLocation else { return nil }
        return Haversine.distance(from: userLoc.coordinate, to: destination)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    if let distance = straightLineDistance {
                        CardSection(String(localized: "navigation.distance")) {
                            HStack {
                                Label(formatDistance(distance), systemImage: "location")
                                    .font(Font.Trakke.bodyRegular)
                                Spacer()
                                Text(String(localized: "navigation.straightLine"))
                                    .font(Font.Trakke.caption)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                        }
                    }

                    VStack(spacing: .Trakke.sm) {
                        Button {
                            dismiss()
                            onRouteNavigation()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "navigation.computeRoute"))
                                        .font(Font.Trakke.bodyMedium)
                                    Text(String(localized: "navigation.computeRouteDescription"))
                                        .font(Font.Trakke.caption)
                                        .foregroundStyle(Color.Trakke.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.trakkeSecondary)
                        .disabled(!isConnected)
                        .opacity(isConnected ? 1 : 0.5)

                        Button {
                            dismiss()
                            onCompassNavigation()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "navigation.compassBearing"))
                                        .font(Font.Trakke.bodyMedium)
                                    Text(String(localized: "navigation.compassDescription"))
                                        .font(Font.Trakke.caption)
                                        .foregroundStyle(Color.Trakke.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "safari")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.trakkeSecondary)
                    }

                    if !isConnected {
                        HStack(spacing: .Trakke.sm) {
                            Image(systemName: "wifi.slash")
                                .font(Font.Trakke.caption)
                            Text(String(localized: "navigation.offlineHint"))
                                .font(Font.Trakke.caption)
                        }
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, .Trakke.xs)
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "navigation.navigateHere"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        MeasurementService.formatDistance(meters)
    }
}
