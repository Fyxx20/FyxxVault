import SwiftUI
import UniformTypeIdentifiers

struct ActivityLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vaultStore: VaultStore
    @State private var showExporter = false
    @State private var logDocument: TextFileDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if vaultStore.activityLog.isEmpty {
                        Text("Aucune activité").foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity).padding(.vertical, 40).fvGlass()
                    } else {
                        ForEach(vaultStore.activityLog.prefix(500)) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.action).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                                    Text(item.target).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.72))
                                }
                                Spacer()
                                Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.56))
                            }.fvGlass()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 22)
            }
            .navigationTitle("Journal (\(vaultStore.activityLog.count))").fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan) }
                ToolbarItem(placement: .primaryAction) {
                    Button("Exporter") {
                        logDocument = TextFileDocument(text: vaultStore.exportActivityLogText())
                        showExporter = true
                    }
                    .foregroundStyle(FVColor.cyan)
                }
            }
            .fileExporter(isPresented: $showExporter, document: logDocument, contentType: .plainText, defaultFilename: "FyxxVault-ActivityLog-\(Int(Date().timeIntervalSince1970))") { _ in }
            .background(FVAnimatedBackground())
        }
    }
}
