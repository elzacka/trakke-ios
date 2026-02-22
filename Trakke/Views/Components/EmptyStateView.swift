import SwiftUI

struct EmptyStateView: View {
    var icon: String?
    let title: String
    let subtitle: String
    var actionLabel: String?
    var actionIcon: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Text group: tightly coupled title + subtitle
            VStack(spacing: .Trakke.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(Font.Trakke.title)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .padding(.bottom, .Trakke.xs)
                }

                Text(title)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.textSecondary)

                Text(subtitle)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .multilineTextAlignment(.center)
            }

            // Action button: clear separation from text group
            if let actionLabel, let action {
                Button(action: action) {
                    Label(actionLabel, systemImage: actionIcon ?? "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.trakkeSecondary)
                .padding(.top, .Trakke.cardGap)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .frame(maxWidth: 500)
    }
}
