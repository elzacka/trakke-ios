import SwiftUI

struct KnowledgePackRow: View {
    let pack: InstalledPackInfo
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(pack.countyName)
                    .font(Font.Trakke.bodyRegular)

                HStack(spacing: .Trakke.xs) {
                    if let theme = KnowledgeTheme(rawValue: pack.theme) {
                        Text(theme.displayName)
                    }
                    Text(ByteCountFormatter.string(fromByteCount: pack.fileSize, countStyle: .file))
                }
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.Trakke.red)
            }
            .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
            .accessibilityLabel(String(localized: "common.delete"))
        }
        .padding(.vertical, .Trakke.xs)
    }
}
