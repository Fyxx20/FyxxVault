import SwiftUI

struct LogoutConfirmSheet: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            FVAnimatedBackground()
            VStack(spacing: 16) {
                Circle()
                    .fill(FVGradient.violetToRose)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text(String(localized: "logout.title"))
                    .font(FVFont.heading(24))
                    .foregroundStyle(.white)

                Text(String(localized: "logout.message"))
                    .font(FVFont.body(14))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                HStack(spacing: 10) {
                    Button(String(localized: "logout.button.cancel"), action: onCancel)
                        .buttonStyle(FVSettingsButton(tint: FVColor.silver.opacity(0.45)))
                    Button(String(localized: "logout.button.confirm"), action: onConfirm)
                        .buttonStyle(FVSettingsButton(tint: FVColor.danger.opacity(0.92)))
                }
            }
            .padding(20)
        }
    }
}
