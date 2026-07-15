import SwiftUI

struct EmptyStateView: View {
    var icon: String?
    let title: String
    let subtitle: String
    /// Horisontal justering av tekstblokken. `.center` (standard) brukes
    /// f.eks. i KnowledgeSheet og DownloadManager. `.leading` brukes i
    /// list-fanene under Naviger for et mer rolig, vestre-justert uttrykk.
    var alignment: HorizontalAlignment = .center
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Text group: tightly coupled title + subtitle
            VStack(alignment: alignment, spacing: .Trakke.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(Font.Trakke.title)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .padding(.bottom, .Trakke.xs)
                }

                Text(title)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.textSecondary)
                    .multilineTextAlignment(textAlignment)

                Text(subtitle)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .multilineTextAlignment(textAlignment)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)

            // Action button: clear separation from text group
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .frame(maxWidth: .infinity)
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

    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}
