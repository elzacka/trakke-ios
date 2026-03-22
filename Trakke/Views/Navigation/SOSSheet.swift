import SwiftUI

struct SOSSheet: View {
    @Bindable var viewModel: SOSViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: .Trakke.cardGap) {
                Spacer()

                if viewModel.isActive {
                    activeState
                } else {
                    inactiveState
                }

                Spacer()

                infoNote
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .background(viewModel.isActive ? Color.Trakke.brandDark : Color(.systemGroupedBackground))
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: viewModel.isActive)
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "sos.menu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.isActive {
                        Button(String(localized: "common.close")) { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isActive)
        }
    }

    // MARK: - Inactive State

    private var inactiveState: some View {
        VStack(spacing: .Trakke.xl) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.Trakke.textTertiary)
                .accessibilityHidden(true)

            Text(String(localized: "sos.description"))
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $viewModel.audioEnabled) {
                Label {
                    Text(String(localized: "sos.audio"))
                        .font(Font.Trakke.bodyRegular)
                } icon: {
                    Image(systemName: "speaker.wave.2")
                }
            }
            .tint(Color.Trakke.brand)
            .padding(.horizontal, .Trakke.lg)

            Button {
                viewModel.activate()
            } label: {
                Text(String(localized: "sos.activate"))
                    .font(Font.Trakke.title)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(Color.Trakke.brand)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            }
            .accessibilityLabel(String(localized: "sos.activate"))
        }
    }

    // MARK: - Active State

    private var activeState: some View {
        VStack(spacing: .Trakke.xl) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text("··· — — — ···")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityLabel("SOS")

            Text(String(localized: "sos.signalActive"))
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                viewModel.deactivate()
            } label: {
                Text(String(localized: "sos.stop"))
                    .font(Font.Trakke.title)
                    .foregroundStyle(Color.Trakke.brandDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            }
            .accessibilityLabel(String(localized: "sos.stop"))

            Toggle(isOn: $viewModel.audioEnabled) {
                Label {
                    Text(String(localized: "sos.audio"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(.white.opacity(0.7))
                } icon: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .tint(Color.Trakke.brand)
            .disabled(true)
            .opacity(0.5)
            .padding(.horizontal, .Trakke.lg)
        }
    }

    // MARK: - Info

    private var infoNote: some View {
        Text(String(localized: "sos.callReminder"))
            .font(Font.Trakke.caption)
            .foregroundStyle(viewModel.isActive ? .white.opacity(0.6) : Color.Trakke.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, .Trakke.lg)
    }
}
