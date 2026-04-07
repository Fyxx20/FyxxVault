import SwiftUI

struct FVDeleteConfirmSheet: View {
    let title: String
    let icon: String
    let message: String
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
                        .fill(FVColor.danger.opacity(0.1))
                        .frame(width: 110, height: 110)
                        .scaleEffect(appear ? 1.0 : 0.5)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [FVColor.danger, FVColor.rose],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .shadow(color: FVColor.danger.opacity(0.4), radius: 20, y: 6)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                // Title
                VStack(spacing: 8) {
                    Text(String(localized: "vault.dialog.delete.title"))
                        .font(FVFont.heading(26))
                        .foregroundStyle(.white)

                    // Entry name
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(FVColor.cyan)
                        Text(title)
                            .font(FVFont.body(16))
                            .foregroundStyle(FVColor.cyan)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(FVColor.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)

                // Message
                Text(message)
                    .font(FVFont.body(14))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .opacity(appear ? 1 : 0)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        fvHaptic(.medium)
                        onConfirm()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(localized: "vault.action.delete"))
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

                    Button {
                        onCancel()
                    } label: {
                        Text(String(localized: "vault.action.cancel"))
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
