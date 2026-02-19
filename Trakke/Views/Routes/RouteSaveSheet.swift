import SwiftUI

struct RouteSaveSheet: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor = RouteViewModel.routeColors[0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    summaryCard
                    detailsCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "route.save"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.Trakke.textSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.save")) {
                        viewModel.finishDrawing(name: name, color: selectedColor)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        CardSection(String(localized: "route.info")) {
            HStack {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(Color.Trakke.textSoft)
                Text(viewModel.formattedDrawingDistance)
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Text(String(localized: "route.pointCount \(viewModel.drawingCoordinates.count)"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
            }
        }
    }

    // MARK: - Details

    private var detailsCard: some View {
        CardSection(String(localized: "route.details")) {
            TextField(String(localized: "routes.namePlaceholder"), text: $name)
                .font(.subheadline)
                .padding(.vertical, 6)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "route.color"))
                    .font(.subheadline)
                HStack(spacing: 8) {
                    ForEach(RouteViewModel.routeColors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.primary, lineWidth: selectedColor == color ? 2 : 0)
                            )
                            .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                            .contentShape(Circle())
                            .onTapGesture { selectedColor = color }
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}
