import SwiftUI

struct MoreSheet: View {
    // ViewModels for pushed destinations
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var activityViewModel: ActivityViewModel
    @Bindable var mapViewModel: MapViewModel

    // Callbacks that dismiss the entire sheet and trigger map actions
    var onMeasurementTapped: (() -> Void)?
    var onOfflineTapped: (() -> Void)?
    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var onActivitySelected: ((Activity) -> Void)?
    var onStartRecording: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var selectedDetent: PresentationDetent = .medium

    enum Destination: Hashable {
        case knowledge
        case routes
        case activities
        case info
        case preferences
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            moreList
                .tint(Color.Trakke.brand)
                .navigationTitle(String(localized: "more.title"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .knowledge:
                        KnowledgeSheet(viewModel: knowledgeViewModel, isEmbedded: true)
                    case .routes:
                        RouteListSheet(
                            viewModel: routeViewModel,
                            onRouteSelected: { route in
                                onRouteSelected?(route)
                                dismiss()
                            },
                            onNewRoute: {
                                onNewRoute?()
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    case .activities:
                        ActivityListSheet(
                            viewModel: activityViewModel,
                            onActivitySelected: { activity in
                                onActivitySelected?(activity)
                                dismiss()
                            },
                            onStartRecording: {
                                onStartRecording?()
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    case .info:
                        InfoSheet(isEmbedded: true)
                    case .preferences:
                        PreferencesSheet(mapViewModel: mapViewModel, knowledgeViewModel: knowledgeViewModel, isEmbedded: true)
                    }
                }
                .navigationDestination(for: KnowledgeDestination.self) { destination in
                    switch destination {
                    case .category(let category):
                        KnowledgeCategoryView(category: category, viewModel: knowledgeViewModel)
                    case .article(let article):
                        ArticleDetailView(article: article)
                    }
                }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .onChange(of: navigationPath.count) {
            if navigationPath.count == 0 {
                selectedDetent = .medium
            }
        }
    }

    // MARK: - Menu List

    private var moreList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection {
                    moreLink(icon: "book.closed", label: String(localized: "knowledge.title"), destination: .knowledge, expandSheet: true)
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    moreLink(icon: "point.topleft.down.to.point.bottomright.curvepath", label: String(localized: "routes.title"), destination: .routes)
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    moreLink(icon: "figure.hiking", label: String(localized: "activity.title"), destination: .activities)
                }

                CardSection {
                    moreButton(icon: "ruler", label: String(localized: "measurement.title")) {
                        dismiss()
                        onMeasurementTapped?()
                    }
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    moreButton(icon: "arrow.down.circle", label: String(localized: "offline.title")) {
                        dismiss()
                        onOfflineTapped?()
                    }
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    moreLink(icon: "info.circle", label: String(localized: "info.title"), destination: .info, expandSheet: true)
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    moreLink(icon: "gearshape", label: String(localized: "settings.title"), destination: .preferences, expandSheet: true)
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Row Views

    private func moreLink(icon: String, label: String, destination: Destination, expandSheet: Bool = false) -> some View {
        Button {
            if expandSheet { selectedDetent = .large }
            navigationPath.append(destination)
        } label: {
            moreRowContent(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    private func moreButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            moreRowContent(icon: icon, label: label, showChevron: false)
        }
    }

    private func moreRowContent(icon: String, label: String, showChevron: Bool = true) -> some View {
        HStack(spacing: .Trakke.md) {
            Image(systemName: icon)
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(Color.Trakke.brand)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(label)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
        }
        .frame(minHeight: .Trakke.touchMin)
        .contentShape(Rectangle())
    }
}
