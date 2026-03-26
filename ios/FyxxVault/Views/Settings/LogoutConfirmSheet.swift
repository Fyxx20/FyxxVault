import SwiftUI

struct LogoutConfirmSheet: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            FVAnimatedBackground()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(FVColor.danger.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .scaleEffect(appear ? 1.0 : 0.6)

                    Circle()
                        .fill(FVGradient.violetToRose)
                        .frame(width: 72, height: 72)
                        .shadow(color: FVColor.rose.opacity(0.35), radius: 20, y: 6)

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                // Title
                Text(String(localized: "logout.title"))
                    .font(FVFont.heading(28))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                // Message
                VStack(spacing: 8) {
                    Text(String(localized: "logout.message"))
                        .font(FVFont.body(15))
                        .foregroundStyle(FVColor.mist)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "logout.data.safe"))
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.smoke)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(appear ? 1 : 0)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    // Confirm (destructive)
                    Button {
                        onConfirm()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 16, weight: .semibold))
                            Text(String(localized: "logout.button.confirm"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [FVColor.danger, FVColor.rose],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: FVColor.danger.opacity(0.3), radius: 12, y: 4)
                    }

                    // Cancel
                    Button {
                        onCancel()
                    } label: {
                        Text(String(localized: "logout.button.cancel"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(FVColor.mist)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 20)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 30)
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}
