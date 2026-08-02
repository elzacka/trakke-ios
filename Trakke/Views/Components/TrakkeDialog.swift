import SwiftUI

/// Tråkkes egen dialog – dempet, kompakt, iOS-alert-inspirert layout med
/// tekst-knapper og delere mellom. Brukes for bekreftelser (Ja/Nei),
/// informasjonsmeldinger (OK) og kontekstmenyer (flere valg).
///
/// Designprinsipper:
/// - Innholdet styrer størrelsen – ingen unødvendig luft eller dominerende fyll.
/// - Tekst-knapper (ingen fylte pille-knapper) som speiler iOS-konvensjon.
/// - To valg = horisontal rad. Tre eller flere = vertikal stabel.
/// - Brand-farge for primær, rød for destruktiv, dempet tekst for avbryt.
struct TrakkeDialogButton {
    enum Role { case primary, destructive, cancel }
    let title: String
    let role: Role
    let action: (() -> Void)?

    static func primary(_ title: String, action: @escaping () -> Void) -> TrakkeDialogButton {
        TrakkeDialogButton(title: title, role: .primary, action: action)
    }

    static func destructive(_ title: String, action: @escaping () -> Void) -> TrakkeDialogButton {
        TrakkeDialogButton(title: title, role: .destructive, action: action)
    }

    static func cancel(_ title: String = String(localized: "common.cancel"), action: (() -> Void)? = nil) -> TrakkeDialogButton {
        TrakkeDialogButton(title: title, role: .cancel, action: action)
    }
}

struct TrakkeDialog: View {
    @Binding var isPresented: Bool
    let title: String?
    let message: String?
    let buttons: [TrakkeDialogButton]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                if title != nil || message != nil {
                    content
                    Divider().overlay(Color.Trakke.border)
                }
                buttonBar
            }
            .frame(maxWidth: 280)
            .background(Color.Trakke.surface)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 6)
            .padding(.horizontal, .Trakke.xl)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: .Trakke.xs) {
            if let title {
                Text(title)
                    .font(Font.Trakke.dialogTitle)
                    .foregroundStyle(Color.Trakke.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            if let message {
                Text(message)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, .Trakke.lg)
        .padding(.vertical, .Trakke.md)
    }

    @ViewBuilder
    private var buttonBar: some View {
        if buttons.count == 2 {
            HStack(spacing: 0) {
                dialogButton(buttons[1])
                Divider()
                    .overlay(Color.Trakke.border)
                    .frame(height: 44)
                dialogButton(buttons[0])
            }
        } else {
            VStack(spacing: 0) {
                ForEach(buttons.indices, id: \.self) { idx in
                    if idx > 0 {
                        Divider().overlay(Color.Trakke.border)
                    }
                    dialogButton(buttons[idx])
                }
            }
        }
    }

    private func dialogButton(_ button: TrakkeDialogButton) -> some View {
        Button {
            // Viktig: kjør action FØR vi nuller isPresented, ellers kan
            // setteren i parent-bindingen rydde tilstand som action trenger
            // (f.eks. longPressCoordinate i ContentView).
            button.action?()
            isPresented = false
        } label: {
            Text(button.title)
                .font(buttonFont(for: button.role))
                .foregroundStyle(buttonColor(for: button.role))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func buttonFont(for role: TrakkeDialogButton.Role) -> Font {
        switch role {
        case .primary, .destructive: Font.Trakke.bodyMedium
        case .cancel: Font.Trakke.bodyRegular
        }
    }

    private func buttonColor(for role: TrakkeDialogButton.Role) -> Color {
        switch role {
        case .primary: Color.Trakke.brand
        case .destructive: Color.Trakke.red
        case .cancel: Color.Trakke.textSoft
        }
    }
}

// MARK: - View Modifier

private struct TrakkeDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String?
    let message: String?
    let buttons: [TrakkeDialogButton]

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                TrakkeDialog(
                    isPresented: $isPresented,
                    title: title,
                    message: message,
                    buttons: buttons
                )
                .presentationBackground(.clear)
            }
            .transaction { transaction in
                if isPresented {
                    transaction.disablesAnimations = true
                }
            }
    }
}

extension View {
    /// Standard bekreftelse: spørsmål + Ja/Nei eller Slett/Avbryt.
    func trakkeDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        primary: TrakkeDialogButton,
        cancel: TrakkeDialogButton? = nil
    ) -> some View {
        let cancelButton = cancel ?? TrakkeDialogButton.cancel()
        return modifier(
            TrakkeDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                buttons: [primary, cancelButton]
            )
        )
    }

    /// Variant med flere handlinger (kontekstmeny). Vertikal stabel med delere.
    /// Tittel er valgfri – for selvforklarende handlingsmenyer (long-press)
    /// klarer dialogen seg uten tittel, slik som iOS action sheets.
    func trakkeDialog(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String? = nil,
        buttons: [TrakkeDialogButton]
    ) -> some View {
        modifier(
            TrakkeDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                buttons: buttons
            )
        )
    }
}
