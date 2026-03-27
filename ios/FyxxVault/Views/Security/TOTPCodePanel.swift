import SwiftUI

struct TOTPCodePanel: View {
    let secretInput: String
    var accentMode: Int = 0
    var onCopy: (() -> Void)? = nil
    @State private var didCopyCode = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let snapshot = TOTPService.snapshot(secretInput: secretInput, at: timeline.date)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    FVPulsingDot(color: FVColor.cyan, size: 5)
                    Text(String(localized: "totp.title"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(FVColor.smoke)
                }
                if let snapshot {
                    HStack {
                        Text(formatted(snapshot.code))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(FVColor.cyan)
                            .privacySensitive()
                        Button {
                            ClipboardService.copy(snapshot.code); onCopy?()
                            fvHaptic(.success)
                            didCopyCode = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyCode = false }
                        } label: {
                            Image(systemName: didCopyCode ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(didCopyCode ? FVColor.success : .white.opacity(0.82))
                        }
                        Spacer()

                        // Circular countdown timer
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                                .frame(width: 28, height: 28)
                            Circle()
                                .trim(from: 0, to: Double(snapshot.remainingSeconds) / 30.0)
                                .stroke(
                                    snapshot.remainingSeconds <= 5 ? FVColor.danger : FVColor.cyan,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: snapshot.remainingSeconds)

                            Text("\(snapshot.remainingSeconds)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(snapshot.remainingSeconds <= 5 ? FVColor.danger : .white.opacity(0.8))
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        let progress = Double(snapshot.remainingSeconds) / 30.0
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: snapshot.remainingSeconds <= 5
                                            ? [FVColor.danger, FVColor.rose]
                                            : [FVColor.cyan, FVColor.violet],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                                .shadow(color: (snapshot.remainingSeconds <= 5 ? FVColor.danger : FVColor.cyan).opacity(0.3), radius: 4, y: 1)
                        }
                    }
                    .frame(height: 5)
                    .clipShape(Capsule())
                } else {
                    Text(String(localized: "totp.invalid.key"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(FVColor.danger.opacity(0.9))
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(FVColor.cyan.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func formatted(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}
