import SwiftUI

/// Pille-formet søkefelt med inline magnifyingglass-ikon. Matcher PWA-en sitt
/// `.search-sheet-input-wrapper`. Brukes i toppen av Hjem-fanen.
///
/// Støtter en valgfri roterende placeholder der `prefix` står konstant og
/// `rotatingWords` veksles ut hver `rotationInterval` sekund.
struct TrakkeSearchField: View {
    @Binding var text: String
    var placeholder: String
    /// Hvis satt sammen med `rotatingWords` brukes en roterende placeholder
    /// i stedet for den statiske `placeholder`-strengen.
    var rotatingPrefix: String? = nil
    var rotatingWords: [String] = []
    var rotationInterval: Duration = .seconds(2)
    var onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool
    @State private var rotatingIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var useRotating: Bool {
        rotatingPrefix != nil && !rotatingWords.isEmpty
    }

    var body: some View {
        HStack(spacing: .Trakke.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.Trakke.textSoft)
                .accessibilityHidden(true)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    placeholderView
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextField("", text: $text)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }
            }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "common.clear"))
            }
        }
        .padding(.horizontal, .Trakke.md)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.surface)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: .TrakkeRadius.lg)
                .strokeBorder(Color.Trakke.border, lineWidth: 1)
        )
        .task(id: useRotating) {
            guard useRotating, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: rotationInterval)
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.3)) {
                    rotatingIndex = (rotatingIndex + 1) % rotatingWords.count
                }
            }
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        if useRotating, let prefix = rotatingPrefix {
            HStack(spacing: 4) {
                Text(prefix)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSoft)

                Text(rotatingWords[rotatingIndex])
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .id(rotatingIndex)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
            }
            .lineLimit(1)
        } else {
            Text(placeholder)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textSoft)
                .lineLimit(1)
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    return VStack {
        TrakkeSearchField(text: $text, placeholder: "Søk etter steder")
        TrakkeSearchField(
            text: $text,
            placeholder: "Søk",
            rotatingPrefix: "Søk på",
            rotatingWords: ["sted", "adresse", "koordinat"]
        )
    }
    .padding()
    .background(Color.Trakke.background)
}
