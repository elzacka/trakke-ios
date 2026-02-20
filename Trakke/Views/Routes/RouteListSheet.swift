import SwiftUI
import UniformTypeIdentifiers

struct RouteListSheet: View {
    @Bindable var viewModel: RouteViewModel
    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.routes.isEmpty {
                    EmptyStateView(
                        title: String(localized: "routes.empty.title"),
                        subtitle: String(localized: "routes.empty.subtitle"),
                        actionLabel: String(localized: "routes.importGPX"),
                        actionIcon: "square.and.arrow.up",
                        action: { showFileImporter = true }
                    )
                } else {
                    routeList
                }
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "routes.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onNewRoute?()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "routes.new"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.gpx],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    viewModel.importGPX(from: url)
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.importMessage != nil {
                    importBanner
                }
            }
        }
    }

    private var routeList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection(String(localized: "routes.saved")) {
                    ForEach(Array(viewModel.routes.enumerated()), id: \.element.id) { index, route in
                        if index > 0 {
                            Divider().padding(.leading, 4)
                        }
                        Button {
                            onRouteSelected?(route)
                            dismiss()
                        } label: {
                            routeRow(route)
                        }
                        .contextMenu {
                            Button {
                                viewModel.toggleVisibility(route)
                            } label: {
                                Label(
                                    route.isVisible
                                        ? String(localized: "routes.hideFromMap")
                                        : String(localized: "routes.showOnMap"),
                                    systemImage: route.isVisible ? "eye.slash" : "eye"
                                )
                            }

                            Button(role: .destructive) {
                                viewModel.deleteRoute(route)
                            } label: {
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }

                VStack(spacing: .Trakke.sm) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(String(localized: "routes.importGPX"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeSecondary)
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func routeRow(_ route: Route) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: route.color ?? "#3e4533"))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(viewModel.formattedDistance(route.distance))
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.textSoft)

                    if let gain = route.elevationGain, gain > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                            Text("\(Int(gain)) m")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.Trakke.textSoft)
                    }
                }
            }

            Spacer()

            Image(systemName: route.isVisible ? "chevron.right" : "eye.slash")
                .font(.caption2)
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, 6)
        .opacity(route.isVisible ? 1 : 0.45)
    }

    // MARK: - Import Banner

    private var importBanner: some View {
        Text(viewModel.importMessage ?? "")
            .font(Font.Trakke.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.brand)
            .clipShape(Capsule())
            .padding(.bottom, .Trakke.lg)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(reduceMotion ? nil : .default) {
                    viewModel.importMessage = nil
                }
            }
    }
}
