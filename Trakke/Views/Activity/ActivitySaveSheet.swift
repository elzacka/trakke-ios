import SwiftUI

struct ActivitySaveSheet: View {
    @Bindable var viewModel: ActivityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showDiscardConfirmation = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    CardSection(String(localized: "activity.save.name")) {
                        TextField(
                            String(localized: "activity.save.namePlaceholder"),
                            text: $name
                        )
                        .font(Font.Trakke.bodyRegular)
                        .textFieldStyle(.plain)
                        .focused($isNameFocused)
                        .padding(.vertical, .Trakke.rowVertical)
                    }

                    CardSection(String(localized: "activity.stats")) {
                        HStack(spacing: .Trakke.lg) {
                            statItem(
                                icon: "arrow.left.and.right",
                                value: viewModel.formattedDistance
                            )
                            statItem(
                                icon: "timer",
                                value: viewModel.formattedDuration
                            )
                            statItem(
                                icon: "arrow.up.right",
                                value: viewModel.formattedElevationGain
                            )
                        }
                        .padding(.vertical, .Trakke.xs)
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "activity.save.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "activity.discard")) {
                        showDiscardConfirmation = true
                    }
                    .foregroundStyle(Color.Trakke.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "activity.save")) {
                        let activityName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = activityName.isEmpty
                            ? defaultName
                            : activityName
                        Task {
                            await viewModel.stopAndSave(name: finalName)
                            dismiss()
                        }
                    }
                }
            }
            .confirmationDialog(
                String(localized: "activity.discard.title"),
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "activity.discard.confirm"), role: .destructive) {
                    viewModel.stopWithoutSaving()
                    dismiss()
                }
            } message: {
                Text(String(localized: "activity.discard.message"))
            }
            .onAppear {
                name = defaultName
                isNameFocused = true
            }
        }
    }

    private var defaultName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMMM yyyy"
        return String(localized: "activity.defaultName \(formatter.string(from: Date()))")
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: .Trakke.xs) {
            Image(systemName: icon)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
            Text(value)
                .font(Font.Trakke.bodyMedium)
                .monospacedDigit()
        }
    }
}
