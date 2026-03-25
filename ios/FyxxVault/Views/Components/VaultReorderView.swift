import SwiftUI

struct VaultReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    var body: some View {
        NavigationStack {
            List {
                ForEach(vaultStore.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(entry.username).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
                .onMove(perform: vaultStore.reorderEntries)
            }
            .navigationTitle(String(localized: "reorder.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.close")) { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
        }
    }
}
