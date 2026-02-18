import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: .Trakke.md) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.Trakke.textSoft)

            Text(title)
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(Color.Trakke.textMuted)

            Text(subtitle)
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textSoft)
                .multilineTextAlignment(.center)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .padding(.top, .Trakke.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
