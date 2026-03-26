import SwiftUI

struct VaultTrashView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if vaultStore.trashEntries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "trash.slash").font(.system(size: 36)).foregroundStyle(.white.opacity(0.7))
                            Text(String(localized: "trash.empty")).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 48).fvGlass()
                    } else {
                        ForEach(vaultStore.trashEntries.sorted(by: { $0.deletedAt > $1.deletedAt })) { trash in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(trash.entry.title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Text(trash.entry.username).foregroundStyle(.white.opacity(0.72))
                                Text(String(format: NSLocalizedString("trash.deletionIn %lld", comment: ""), max(0, Calendar.current.dateComponents([.day], from: Date(), to: trash.expiresAt).day ?? 0)))
                                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.58))
                                HStack {
                                    Button(String(localized: "trash.restore")) { vaultStore.restoreFromTrash(trash.id) }.foregroundStyle(FVColor.cyan)
                                    Spacer()
                                    Button(String(localized: "trash.deletePermanently"), role: .destructive) { vaultStore.permanentlyDeleteFromTrash(trash.id) }
                                }
                            }.fvGlass()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 22)
            }
            .navigationTitle(String(localized: "trash.title")).fvInlineNavTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.close")) { dismiss() }.foregroundStyle(FVColor.cyan) } }
            .background(FVAnimatedBackground())
        }
    }
}
