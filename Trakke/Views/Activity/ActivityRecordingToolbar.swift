import SwiftUI

struct ActivityRecordingToolbar: View {
    let formattedDistance: String
    let formattedDuration: String
    let formattedElevationGain: String
    var onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: .Trakke.lg) {
                recordingIndicator

                statItem(icon: "timer", value: formattedDuration)
                statItem(icon: "arrow.left.and.right", value: formattedDistance)
                statItem(icon: "arrow.up.right", value: formattedElevationGain)

                Spacer()

                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(.white)
                        .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                        .background(Color.Trakke.red)
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "activity.stop"))
            }
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            .trakkeControlShadow()
            .padding(.horizontal, .Trakke.lg)
            .padding(.bottom, .Trakke.sm)
        }
        .safeAreaPadding(.bottom)
    }

    private var recordingIndicator: some View {
        Circle()
            .fill(Color.Trakke.red)
            .frame(width: 10, height: 10)
            .modifier(PulseModifier(reduceMotion: reduceMotion))
            .accessibilityLabel(String(localized: "activity.recording"))
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: .Trakke.xs) {
            Image(systemName: icon)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
            Text(value)
                .font(Font.Trakke.bodyMedium)
                .monospacedDigit()
        }
    }
}

private struct PulseModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isPulsing ? 0.3 : 1))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
