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
                Text(String(localized: "totp.title")).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.68))
                if let snapshot {
                    HStack {
                        Text(formatted(snapshot.code))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(FVColor.cyan)
                            .privacySensitive()
                        Button {
                            ClipboardService.copy(snapshot.code); onCopy?()
                            fvHaptic(.light)
                            didCopyCode = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyCode = false }
                        } label: { Image(systemName: didCopyCode ? "checkmark.circle.fill" : "doc.on.doc") }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(didCopyCode ? FVColor.cyan : .white.opacity(0.82))
                        Spacer()
                        Text("\(snapshot.remainingSeconds)s").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.78))
                    }
                    GeometryReader { geo in
                        let progress = Double(snapshot.remainingSeconds) / 30.0
                        Capsule().fill(Color.white.opacity(0.14))
                            .overlay(alignment: .leading) { Capsule().fill(FVColor.cyan).frame(width: geo.size.width * progress) }
                    }
                    .frame(height: 6)
                } else {
                    Text(String(localized: "totp.invalid.key")).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.danger.opacity(0.9))
                }
            }
            .padding(10).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func formatted(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}
