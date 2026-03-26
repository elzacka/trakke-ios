import SwiftUI

struct ActivityListSheet: View {
    @Bindable var viewModel: ActivityViewModel
    var onActivitySelected: (Activity) -> Void
    var onStartRecording: () -> Void
    var isEmbedded = false
    var dismissSheet: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAllConfirmation = false

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
        Group {
            if viewModel.activities.isEmpty {
                emptyState
            } else {
                activityList
            }
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "activity.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismissFully()
                    onStartRecording()
                } label: {
                    Image(systemName: "record.circle")
                }
                .accessibilityLabel(String(localized: "activity.startRecording"))
            }
        }
        .onAppear {
            viewModel.loadActivities()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "figure.hiking",
            title: String(localized: "activity.empty.title"),
            subtitle: String(localized: "activity.empty.subtitle")
        )
    }

    private var activityList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection(String(localized: "activity.history")) {
                    ForEach(viewModel.activities, id: \.id) { activity in
                        if activity != viewModel.activities.first {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
                        activityRow(activity)
                    }
                }

                Button {
                    showDeleteAllConfirmation = true
                } label: {
                    Label(String(localized: "activity.deleteAll"), systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.trakkeDanger)
                .confirmationDialog(
                    String(localized: "activity.deleteAll.title"),
                    isPresented: $showDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "activity.deleteAll.confirm"), role: .destructive) {
                        viewModel.deleteAllActivities()
                    }
                } message: {
                    Text(String(localized: "activity.deleteAll.message"))
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    private func activityRow(_ activity: Activity) -> some View {
        Button {
            onActivitySelected(activity)
        } label: {
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

                HStack(spacing: .Trakke.lg) {
                    statLabel(
                        icon: "arrow.left.and.right",
                        value: ActivityViewModel.formatDistance(activity.distance)
                    )
                    statLabel(
                        icon: "timer",
                        value: ActivityViewModel.formatDuration(activity.duration)
                    )
                    statLabel(
                        icon: "arrow.up.right",
                        value: "\(Int(activity.elevationGain)) m"
                    )
                }
            }
            .padding(.vertical, .Trakke.rowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func statLabel(icon: String, value: String) -> some View {
        HStack(spacing: .Trakke.labelGap) {
            Image(systemName: icon)
                .font(Font.Trakke.captionSoft)
            Text(value)
                .font(Font.Trakke.caption)
        }
        .foregroundStyle(Color.Trakke.textTertiary)
    }
}
