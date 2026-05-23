import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct ActivityListSheet: View {
    @Bindable var viewModel: ActivityViewModel
    var routeViewModel: RouteViewModel?
    var onActivitySelected: (Activity) -> Void
    var onStartRecording: () -> Void
    var onRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onFollowAgain: ((Activity) -> Void)?
    var isEmbedded = false
    var dismissSheet: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDeleteAllConfirmation = false
    @State private var showFileImporter = false
    @State private var editingActivity: Activity?
    @State private var shareURL: ShareableURL?
    @State private var expandedCategories: Set<String> = []

    private func dismissFully() {
        if let dismissSheet { dismissSheet() } else { dismiss() }
    }

    var body: some View {
        if isEmbedded {
            activityContent
        } else {
            NavigationStack {
                activityContent
            }
        }
    }

    private var activityContent: some View {
        activityList
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "activity.title"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.gpx, .geoJSON],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await viewModel.importFileAsync(from: url) }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.importMessage != nil {
                importBanner
            }
        }
        .sheet(item: $editingActivity) { activity in
            EditNameCategorySheet(
                title: String(localized: "common.edit"),
                initialName: activity.name,
                initialCategory: activity.category ?? "",
                categorySuggestions: viewModel.categories,
                namePlaceholder: String(localized: "activity.save.namePlaceholder")
            ) { newName, newCategory in
                viewModel.edit(activity, name: newName, category: newCategory)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .navigationDestination(for: Activity.self) { activity in
            ActivityDetailSheet(
                viewModel: viewModel,
                activity: activity,
                onRetrace: { coordinate in
                    onRetrace?(coordinate)
                    dismissFully()
                },
                onFollowAgain: { activity in
                    onFollowAgain?(activity)
                    dismissFully()
                },
                isEmbedded: true
            )
        }
        .onAppear {
            viewModel.loadActivities()
        }
    }

    private var importBanner: some View {
        Text(viewModel.importMessage ?? "")
            .font(Font.Trakke.caption)
            .foregroundStyle(Color.Trakke.textInverse)
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

    private var activityList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Primær handling
                Button {
                    dismissFully()
                    onStartRecording()
                } label: {
                    Label(
                        String(localized: "activity.log"),
                        systemImage: "plus"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.trakkeSecondary)

                // Turhistorikk rett under primær handling
                ForEach(viewModel.categories, id: \.self) { category in
                    activityGroup(title: category, category: category, items: viewModel.activities(for: category))
                }

                if !viewModel.uncategorizedActivities.isEmpty {
                    activityGroup(
                        title: viewModel.categories.isEmpty
                            ? String(localized: "activity.history")
                            : String(localized: "activity.uncategorized"),
                        category: nil,
                        items: viewModel.uncategorizedActivities
                    )
                }

                // Sekundærhandlinger — importer, eksporter, slett.
                // Ikon-bar høyrejustert: signaliserer at dette er
                // utility-handlinger, ikke primær-flyten.
                secondaryActionBar

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    private func activityGroup(title: String, category: String?, items: [Activity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader(title: title, category: category, count: items.count)

            if expandedCategories.contains(title) {
                VStack(spacing: 0) {
                    ForEach(items) { activity in
                        if items.first?.id != activity.id {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
                        activityRow(activity)
                    }
                }
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.cardPadV)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                .padding(.top, .Trakke.sm)
            }
        }
    }

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: 0) {
            NavigationLink(value: activity) {
                VStack(alignment: .leading, spacing: .Trakke.xs) {
                    HStack {
                        Text(activity.name)
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.text)
                        Spacer()
                        Text(activity.startedAt, style: .date)
                            .font(Font.Trakke.captionSoft)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }

                    // Én sentral verdi i listen: distanse. Varighet og høydemeter
                    // lever i ActivityDetailSheet — listen skal hjelpe deg finne
                    // «den jeg gikk på søndag», ikke vise hele statistikken.
                    Text(ActivityViewModel.formatDistance(activity.distance))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
                .padding(.vertical, .Trakke.rowVertical)
                .opacity(activity.isVisible ? 1 : 0.45)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    editingActivity = activity
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "pencil")
                }

                if let routeViewModel {
                    Button {
                        viewModel.convertToRoute(activity, using: routeViewModel)
                    } label: {
                        Label(
                            String(localized: "activity.convertToRoute"),
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                    }
                }

                Button(role: .destructive) {
                    viewModel.deleteActivity(activity)
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(activityAccessibilityLabel(activity))

            VisibilityToggleButton(
                isVisible: activity.isVisible,
                accessibilityLabel: activity.isVisible
                    ? String(localized: "activity.hideFromMap")
                    : String(localized: "activity.showOnMap")
            ) {
                viewModel.toggleVisibility(activity)
            }
        }
    }

    private func activityAccessibilityLabel(_ activity: Activity) -> String {
        let parts = [
            activity.name,
            ActivityViewModel.formatDistance(activity.distance),
            ActivityViewModel.formatDuration(activity.duration),
            "+\(Int(activity.elevationGain)) m",
        ]
        return parts.joined(separator: ", ")
    }

    // MARK: - Category Header

    /// Header with three discrete tap targets: collapse on title, eye toggle
    /// for the whole category, chevron also collapses (accessibility-hidden
    /// since the title button already announces collapsed/expanded).
    @ViewBuilder
    private func categoryHeader(title: String, category: String?, count: Int) -> some View {
        let allVisible = viewModel.isCategoryAllVisible(category)
        HStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(title) {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(title.uppercased())
                        .font(Font.Trakke.sectionHeader)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Text(" (\(count))")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Spacer()
                }
                .padding(.leading, .Trakke.xs)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count)")
            .accessibilityAddTraits(expandedCategories.contains(title) ? .isSelected : [])

            Button {
                viewModel.setCategoryVisibility(category, visible: !allVisible)
            } label: {
                Group {
                    if allVisible {
                        Image(systemName: "checkmark")
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.brand)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                allVisible
                    ? String(localized: "list.category.hideAll \(title)")
                    : String(localized: "list.category.showAll \(title)")
            )

            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(title) {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .rotationEffect(expandedCategories.contains(title) ? .degrees(90) : .degrees(0))
                    .padding(.trailing, .Trakke.xs)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Secondary action bar (importer / eksporter / slett)

    private var secondaryActionBar: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            TrakkeIconButton(
                systemImage: "square.and.arrow.up",
                isLoading: viewModel.isImporting,
                accessibilityLabel: viewModel.isImporting
                    ? String(localized: "import.inProgress")
                    : String(localized: "import.file"),
                action: { showFileImporter = true }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                isEnabled: !viewModel.activities.isEmpty,
                accessibilityLabel: String(localized: "import.exportAll"),
                action: {
                    if let url = viewModel.exportAllGPX() {
                        shareURL = ShareableURL(url: url)
                    }
                }
            )

            TrakkeIconButton(
                systemImage: "trash",
                role: .destructive,
                isEnabled: !viewModel.activities.isEmpty,
                accessibilityLabel: String(localized: "activity.deleteAll"),
                action: { showDeleteAllConfirmation = true }
            )
            .trakkeDialog(
                isPresented: $showDeleteAllConfirmation,
                title: String(localized: "activity.deleteAll.title"),
                message: String(localized: "activity.deleteAll.message"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteAllActivities()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }
}
