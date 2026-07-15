import SwiftUI

/// Tråkkes egen toggle-stil. Bruker brandLight-grønt for på-tilstand og en
/// varm, dempet salviegrønn (`Color.Trakke.toggleTrackOff`) for av-tilstand
/// – erstatter iOS-default systemgrå som bryter med appens palett.
///
/// Bevarer iOS-konvensjoner for størrelse (51×31pt) og tap/drag-feedback,
/// slik at brukere kjenner igjen mønsteret men opplever Tråkke-helhet.
struct TrakkeToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.Trakke.brandLight : Color.Trakke.toggleTrackOff)
                    .frame(width: 51, height: 31)
                    .overlay {
                        if !configuration.isOn {
                            Capsule().stroke(Color.Trakke.textSoft, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)
            }
        }
        // Hele raden (etikett + spacer + kapsel) er trykkbar, ikke bare kapselen.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                configuration.isOn.toggle()
            }
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }
}

extension ToggleStyle where Self == TrakkeToggleStyle {
    static var trakke: TrakkeToggleStyle { .init() }
}
