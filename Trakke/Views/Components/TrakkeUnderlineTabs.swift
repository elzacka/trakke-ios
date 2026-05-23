import SwiftUI

/// Horisontal tab-rad med underline-stil (PWA-trofast).
/// Aktiv tab har brand-farget tekst og 2pt brand-underline.
/// Erstatter iOS-default Segmented Picker.
struct TrakkeUnderlineTabs: View {
    let titles: [String]
    @Binding var selectedIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                tabButton(index: index)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.Trakke.border)
                .frame(height: 1)
        }
    }

    private func tabButton(index: Int) -> some View {
        let isActive = (selectedIndex == index)

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedIndex = index
            }
        } label: {
            VStack(spacing: 0) {
                Text(titles[index])
                    .font(Font.Trakke.bodyMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(isActive ? Color.Trakke.brand : Color.Trakke.textSoft)
                    .padding(.vertical, .Trakke.md)
                    .padding(.horizontal, .Trakke.xs)

                Rectangle()
                    .fill(isActive ? Color.Trakke.brand : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(titles[index])
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = 0
    return VStack {
        TrakkeUnderlineTabs(
            titles: ["Ruter", "Steder", "Turer"],
            selectedIndex: $selection
        )
        Spacer()
    }
    .background(Color.Trakke.surface)
}
