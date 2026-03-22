import SwiftUI
import CoreLocation

struct EmergencyCoordinatesSheet: View {
    let userLocation: CLLocation?
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    private var coordinate: CLLocationCoordinate2D? {
        guard let loc = userLocation,
              loc.coordinate.latitude.isFinite,
              loc.coordinate.longitude.isFinite else { return nil }
        return loc.coordinate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    if let coord = coordinate {
                        coordinateCards(for: coord)
                    } else {
                        noPositionView
                    }

                    instructionCard
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "emergency.coordinates.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Coordinate Cards

    @ViewBuilder
    private func coordinateCards(for coord: CLLocationCoordinate2D) -> some View {
        let utm = CoordinateService.format(coordinate: coord, format: .utm)
        let dd = CoordinateService.format(coordinate: coord, format: .dd)

        CardSection("UTM") {
            coordinateRow(formatted: utm)
        }

        CardSection(String(localized: "emergency.coordinates.decimal")) {
            coordinateRow(formatted: dd)
        }

        if let accuracy = userLocation?.horizontalAccuracy, accuracy > 0 {
            Text(String(localized: "emergency.coordinates.accuracy \(Int(accuracy))"))
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func coordinateRow(formatted: FormattedCoordinate) -> some View {
        HStack(alignment: .center) {
            Text(formatted.display)
                .font(Font.Trakke.title)
                .foregroundStyle(Color.Trakke.text)
                .accessibilityLabel(formatted.copyText)

            Spacer()

            Button {
                UIPasteboard.general.string = formatted.copyText
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.copy"))
        }
    }

    // MARK: - No Position

    private var noPositionView: some View {
        CardSection("") {
            VStack(spacing: .Trakke.sm) {
                Image(systemName: "location.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.Trakke.textTertiary)
                Text(String(localized: "emergency.coordinates.noPosition"))
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Trakke.xl)
        }
    }

    // MARK: - Instruction

    private var instructionCard: some View {
        CardSection("") {
            Text(String(localized: "emergency.coordinates.instruction"))
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
