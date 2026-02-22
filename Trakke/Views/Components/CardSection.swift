import SwiftUI

struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(Font.Trakke.sectionHeader)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.horizontal, .Trakke.xs)
                    .padding(.bottom, .Trakke.sm)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .Trakke.cardPadH)
            .padding(.vertical, .Trakke.cardPadV)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
    }
}
