import SwiftUI

// MARK: - Announcements View

struct AnnouncementsView: View {
    @ObservedObject var announcementsService: AnnouncementsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if announcementsService.isLoading {
                        ProgressView().tint(FVColor.cyan).padding(.top, 60)
                    } else if announcementsService.announcements.isEmpty {
                        FVEmptyState(
                            icon: "bell.slash",
                            title: "Aucune annonce",
                            subtitle: "Les annonces de FyxxVault apparaîtront ici"
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(announcementsService.announcements) { announcement in
                            AnnouncementCard(
                                announcement: announcement,
                                onRead: { announcementsService.markRead(announcement.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(FVAnimatedBackground())
            .navigationTitle("Annonces")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(FVColor.cyan)
                }
                if announcementsService.unreadCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Tout lire") { announcementsService.markAllRead() }
                            .foregroundStyle(FVColor.mist)
                            .font(FVFont.caption(13))
                    }
                }
            }
            .task { await announcementsService.fetch() }
        }
    }
}

struct AnnouncementCard: View {
    let announcement: FVAnnouncement
    let onRead: () -> Void

    private var accentColor: Color {
        switch announcement.type {
        case "warning": return FVColor.warning
        case "success": return FVColor.success
        case "new": return FVColor.cyan
        default: return FVColor.violet
        }
    }

    private var icon: String {
        switch announcement.type {
        case "warning": return "exclamationmark.triangle.fill"
        case "success": return "checkmark.circle.fill"
        case "new": return "sparkles"
        default: return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(accentColor)
                    .font(.system(size: 18))

                Text(announcement.title)
                    .font(FVFont.heading(15))
                    .foregroundStyle(.white)

                Spacer()

                if !announcement.isRead {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                }
            }

            Text(announcement.content)
                .font(FVFont.body(13))
                .foregroundStyle(FVColor.mist)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(formatDate(announcement.createdAt))
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.smoke)
                Spacer()
                if !announcement.isRead {
                    Button("Marquer comme lu") {
                        withAnimation { onRead() }
                    }
                    .font(FVFont.caption(12))
                    .foregroundStyle(accentColor)
                }
            }
        }
        .padding(16)
        .background(accentColor.opacity(announcement.isRead ? 0.03 : 0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(announcement.isRead ? 0.1 : 0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(announcement.isRead ? 0.7 : 1)
    }

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.dateStyle = .medium
            df.timeStyle = .none
            return df.string(from: date)
        }
        return ""
    }
}
