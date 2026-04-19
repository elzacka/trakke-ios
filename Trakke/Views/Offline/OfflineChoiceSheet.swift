import SwiftUI

struct OfflineChoiceSheet: View {
    var onCustom: () -> Void
    var onKommune: () -> Void
    var onManageDownloads: (() -> Void)?
    var hasDownloads = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    choiceCard(
                        icon: "rectangle.dashed",
                        title: String(localized: "offline.choice.custom"),
                        subtitle: String(localized: "offline.choice.custom.subtitle")
                    ) {
                        dismiss()
                        onCustom()
                    }

                    choiceCard(
                        icon: "mappin.and.ellipse",
                        title: String(localized: "offline.choice.kommune"),
                        subtitle: String(localized: "offline.choice.kommune.subtitle")
                    ) {
                        dismiss()
                        onKommune()
                    }

                    if hasDownloads {
                        choiceCard(
                            icon: "arrow.down.circle",
                            title: String(localized: "offline.choice.downloads"),
                            subtitle: String(localized: "offline.choice.downloads.subtitle")
                        ) {
                            dismiss()
                            onManageDownloads?()
                        }
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "offline.choice.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func choiceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .Trakke.lg) {
                Image(systemName: icon)
                    .font(Font.Trakke.numeralLarge)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.iconSlotLarge)

                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(title)
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)
                    Text(subtitle)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            .padding(.horizontal, .Trakke.cardPadH)
            .padding(.vertical, .Trakke.buttonPadV)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
