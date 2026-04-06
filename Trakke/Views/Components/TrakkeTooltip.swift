import SwiftUI

/// Tooltip content view styled with Trakke design tokens.
struct TrakkeTooltipContent: View {
    let title: String
    let text: String
    var sections: [(header: String, text: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.sm) {
            if !title.isEmpty {
                Text(title)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)
            }

            if !text.isEmpty {
                Text(text)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }

            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                Text(section.header)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.text)
                    .padding(.top, .Trakke.xs)
                Text(section.text)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSecondary)
            }
        }
        .padding(.Trakke.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

typealias TrakkeTooltip = TrakkeTooltipContent

/// Presents a tooltip as a centered overlay card with controlled corner radius,
/// sized dynamically to fit content.
struct TrakkeTooltipModifier<TooltipContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let tooltipContent: () -> TooltipContent

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }

                    tooltipContent()
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340)
                        .background(Color.Trakke.brandTint)
                        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                        .trakkeControlShadow()
                        .padding(.horizontal, .Trakke.sheetHorizontal)
                }
                .presentationBackground(.clear)
            }
    }
}

extension View {
    func trakkeTooltip<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(TrakkeTooltipModifier(isPresented: isPresented, tooltipContent: content))
    }
}
