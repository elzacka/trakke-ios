import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(Color.Trakke.textSoft)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.body)
                    .lineLimit(1)

                if let subtext = result.subtext {
                    Text(subtext)
                        .font(.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var iconName: String {
        switch result.type {
        case .place:
            return "mappin"
        case .address:
            return "house"
        case .coordinates:
            return "location.circle"
        }
    }

    private var accessibilityText: String {
        var text = result.displayName
        if let subtext = result.subtext {
            text += ", \(subtext)"
        }
        return text
    }
}
