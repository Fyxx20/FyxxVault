import SwiftUI

struct VaultListView: View {
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var subscriptionService: SubscriptionService
    @Binding var quickAction: VaultQuickAction?

    @State private var showAddSheet = false
    @State private var showPaywall = false
    @State private var query = ""
    @State private var pendingDeleteEntry: VaultEntry?
    @State private var editingEntry: VaultEntry?
    @State private var lastDeletedTrashID: UUID?
    @State private var showUndoDeleteToast = false
    @State private var selectionMode = false
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showBulkTagPrompt = false
    @State private var showBulkFolderPrompt = false
    @State private var bulkTagText = ""
    @State private var bulkFolderText = ""
    @State private var sortMode: VaultSortMode = .recent
    @State private var filterMode: VaultFilterMode = .all
    @State private var selectedCategory: VaultCategory? = nil
    @State private var fabPressed = false
    @State private var fabRotation: Double = 0
    @AppStorage("fyxxvault.compact.cards") private var compactCards = false
    @AppStorage("fyxxvault.accent.mode") private var accentMode = 0
    @FocusState private var isSearchFocused: Bool

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 18 ? String(localized: "vault.greeting.morning") : String(localized: "vault.greeting.evening")
    }

    private var filteredEntries: [VaultEntry] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var source = vaultStore.entries
        switch filterMode {
        case .all: break
        case .favorites: source = source.filter { $0.isFavorite }
        case .weak: source = source.filter { [.faible, .moyen].contains(PasswordToolkit.strength(for: $0.password)) }
        case .mfa: source = source.filter { $0.mfaEnabled }
        case .expired: source = source.filter { $0.isExpired || $0.isExpiringSoon }
        case .byCategory:
            if let cat = selectedCategory {
                source = source.filter { $0.category == cat }
            }
        }
        let queried = cleanQuery.isEmpty ? source : source.filter {
            $0.title.localizedCaseInsensitiveContains(cleanQuery)
            || $0.username.localizedCaseInsensitiveContains(cleanQuery)
            || $0.website.localizedCaseInsensitiveContains(cleanQuery)
            || $0.notes.localizedCaseInsensitiveContains(cleanQuery)
        }
        switch sortMode {
        case .recent:        return queried.sorted { $0.lastModifiedAt > $1.lastModifiedAt }
        case .alphabetical:  return queried.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .strength:
            let w: (PasswordStrength) -> Int = { switch $0 { case .faible: 0; case .moyen: 1; case .fort: 2; case .excellent: 3 } }
            return queried.sorted { w(PasswordToolkit.strength(for: $0.password)) < w(PasswordToolkit.strength(for: $1.password)) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Premium Header
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Text(String(localized: "vault.title"))
                                    .font(FVFont.display(32))
                                    .fvAnimatedGradient()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                FVCountBadge(count: vaultStore.entries.count)
                            }

                            Text(String(localized: "vault.subtitle"))
                                .font(FVFont.caption(11))
                                .kerning(0.8)
                                .foregroundStyle(FVColor.mist.opacity(0.78))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer(minLength: 8)

                        VStack(spacing: 2) {
                            if subscriptionService.isProUser {
                                Text("\(vaultStore.entries.count)")
                                    .font(FVFont.display(28))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            } else {
                                Text("\(vaultStore.entries.count)/5")
                                    .font(FVFont.display(28))
                                    .foregroundStyle(vaultStore.entries.count >= 5 ? FVColor.warning : .white)
                                    .contentTransition(.numericText())
                            }
                            Text(String(localized: "vault.header.accounts"))
                                .font(FVFont.caption(10))
                                .kerning(1.8)
                                .foregroundStyle(FVColor.mist.opacity(0.86))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), FVColor.violet.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }

                    if !vaultStore.persistenceError.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FVColor.danger)
                            Text(vaultStore.persistenceError)
                                .font(FVFont.caption(12))
                                .foregroundStyle(FVColor.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fvGlass()
                    }

                    // MARK: - Search Bar with Glow
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSearchFocused ? FVColor.cyan : FVColor.mist.opacity(0.75))
                            .scaleEffect(isSearchFocused ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSearchFocused)
                        TextField(String(localized: "vault.list.search"), text: $query)
                            .fvPlatformTextEntry()
                            .foregroundStyle(.white)
                            .focused($isSearchFocused)
                        if isSearchFocused || !query.isEmpty {
                            Button {
                                query = ""
                                isSearchFocused = false
                            } label: {
                                Text(String(localized: "vault.action.cancel"))
                                    .font(FVFont.caption(12))
                                    .foregroundStyle(FVColor.cyan)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(
                            LinearGradient(
                                colors: [
                                    isSearchFocused ? FVColor.cyan.opacity(0.5) : Color.white.opacity(0.14),
                                    FVColor.violet.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSearchFocused ? 1.5 : 1
                        )
                    )
                    .shadow(color: isSearchFocused ? FVColor.cyan.opacity(0.15) : .clear, radius: 12, y: 4)
                    .fvGlass(cornerRadius: 18, padding: 0)

                    // MARK: - Filter Chips
                    HStack(spacing: 10) {
                        Menu {
                            ForEach(VaultFilterMode.allCases) { f in
                                Button(f.rawValue) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filterMode = f }
                                    fvHaptic(.light)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease")
                                Text(filterMode.rawValue)
                            }
                            .font(FVFont.caption(12))
                            .foregroundStyle(filterMode != .all ? .white : FVColor.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Group {
                                    if filterMode != .all {
                                        FVGradient.cyanToViolet.opacity(0.5)
                                    } else {
                                        FVColor.cyan.opacity(0.08)
                                    }
                                }
                            )
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(filterMode != .all ? FVColor.cyan.opacity(0.4) : FVColor.cyan.opacity(0.15)))
                            .scaleEffect(filterMode != .all ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: filterMode)
                        }

                        Menu {
                            ForEach(VaultSortMode.allCases) { m in
                                Button(m.rawValue) {
                                    sortMode = m
                                    fvHaptic(.light)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text(sortMode.rawValue)
                            }
                            .font(FVFont.caption(12))
                            .foregroundStyle(FVColor.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(FVColor.cyan.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.15)))
                        }
                        Spacer()
                        Button(selectionMode ? String(localized: "vault.list.done") : String(localized: "vault.list.select")) {
                            selectionMode.toggle()
                            if !selectionMode { selectedEntryIDs.removeAll() }
                            fvHaptic(.light)
                        }
                        .font(FVFont.caption(11))
                        .foregroundStyle(FVColor.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FVColor.cyan.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.15)))
                    }
                    .fvGlass(cornerRadius: 14, padding: 12)

                    // MARK: - Category Chips (horizontal scroll with snap)
                    if filterMode == .byCategory {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VaultCategory.allCases) { cat in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = (selectedCategory == cat) ? nil : cat
                                        }
                                        fvHaptic(.light)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: cat.iconName).font(.system(size: 10))
                                            Text(cat.label).font(FVFont.caption(11))
                                        }
                                        .foregroundStyle(selectedCategory == cat ? .white : FVColor.mist)
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(
                                            Group {
                                                if selectedCategory == cat {
                                                    LinearGradient(
                                                        colors: [cat.iconColor.opacity(0.4), FVColor.violet.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                } else {
                                                    Color.white.opacity(0.05)
                                                }
                                            }
                                        )
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(selectedCategory == cat ? cat.iconColor.opacity(0.4) : Color.white.opacity(0.08)))
                                        .scaleEffect(selectedCategory == cat ? 1.05 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectedCategory)
                                    }
                                }
                            }
                        }
                        .fvGlass(cornerRadius: 14, padding: 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: - Bulk Selection Bar
                    if selectionMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                Text(String(format: NSLocalizedString("vault.list.selected %lld", comment: ""), selectedEntryIDs.count))
                                    .font(FVFont.caption(11))
                                    .kerning(1.2)
                                    .foregroundStyle(FVColor.mist.opacity(0.9))
                                Button(String(localized: "vault.list.tag")) { showBulkTagPrompt = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.cyan)
                                Button(String(localized: "vault.list.move")) { showBulkFolderPrompt = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.cyan)
                                Button(String(localized: "vault.list.favorite")) { vaultStore.bulkSetFavorite(entryIDs: selectedEntryIDs, value: true) }.font(FVFont.caption(12)).foregroundStyle(.yellow.opacity(0.9))
                                Button(String(localized: "vault.list.delete")) { showBulkDeleteConfirm = true }.font(FVFont.caption(12)).foregroundStyle(FVColor.danger.opacity(0.9))
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fvGlass(cornerRadius: 14, padding: 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if !vaultStore.integrityWarning.isEmpty {
                        Text(vaultStore.integrityWarning)
                            .font(FVFont.caption(12))
                            .foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fvGlass()
                    }

                    // MARK: - Entry List or Empty State
                    if filteredEntries.isEmpty {
                        // Premium Empty State
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [FVColor.cyan.opacity(0.12), FVColor.violet.opacity(0.06), .clear],
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 80
                                        )
                                    )
                                    .frame(width: 160, height: 160)

                                Image(systemName: "lock.rectangle.stack")
                                    .font(.system(size: 52, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [FVColor.cyan.opacity(0.6), FVColor.violet.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("Ton coffre est vide")
                                .font(FVFont.heading(20))
                                .foregroundStyle(FVColor.silver)

                            Text(String(localized: "vault.list.empty.subtitle"))
                                .font(FVFont.body(14))
                                .foregroundStyle(FVColor.smoke)
                                .multilineTextAlignment(.center)

                            Button {
                                fvHaptic(.medium)
                                if !subscriptionService.isProUser && vaultStore.entries.count >= 5 {
                                    showPaywall = true
                                } else {
                                    showAddSheet = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Ajouter ton premier mot de passe")
                                        .font(FVFont.label(14))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(FVGradient.cyanToViolet)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: FVColor.cyan.opacity(0.3), radius: 12, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .fvPremiumCard()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                VaultEntryCard(
                                    entry: entry,
                                    onDelete: { pendingDeleteEntry = entry },
                                    onEdit: { editingEntry = entry },
                                    onCopyPassword: { vaultStore.markCopied("mot de passe", title: entry.title) },
                                    onCopyMFA: { vaultStore.markCopied("MFA", title: entry.title) },
                                    selectionMode: selectionMode,
                                    isSelected: selectedEntryIDs.contains(entry.id),
                                    onTapCard: {
                                        guard selectionMode else { return }
                                        if selectedEntryIDs.contains(entry.id) { selectedEntryIDs.remove(entry.id) }
                                        else { selectedEntryIDs.insert(entry.id) }
                                    },
                                    compact: compactCards,
                                    accentMode: accentMode
                                )
                                .fvAppear(delay: Double(index) * 0.05)
                            }
                        }
                    }

                    Color.clear.frame(height: 130)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)

            // MARK: - Undo Toast
            if showUndoDeleteToast {
                HStack {
                    Text(String(localized: "vault.list.toast.deleted")).font(FVFont.caption(13)).foregroundStyle(.white)
                    Spacer()
                    Button(String(localized: "vault.action.cancel")) {
                        if let id = lastDeletedTrashID { vaultStore.restoreFromTrash(id) }
                        showUndoDeleteToast = false
                        lastDeletedTrashID = nil
                    }
                    .font(FVFont.caption(13))
                    .foregroundStyle(FVColor.cyan)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16).padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: - FAB with Premium Effects
            Button {
                fvHaptic(.medium)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    fabRotation += 90
                }
                if !subscriptionService.isProUser && vaultStore.entries.count >= 5 {
                    showPaywall = true
                } else {
                    showAddSheet = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(FVColor.cyan.opacity(0.15))
                        .frame(width: 68, height: 68)

                    Circle()
                        .fill(FVGradient.cyanToViolet)
                        .frame(width: 54, height: 54)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2))
                        .shadow(color: FVColor.cyan.opacity(0.4), radius: 14, y: 4)
                        .shadow(color: FVColor.violet.opacity(0.2), radius: 8, y: 6)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(fabRotation))
                }
                .scaleEffect(fabPressed ? 0.9 : 1.0)
            }
            .buttonStyle(.plain)
            .pressEvents {
                withAnimation(.easeOut(duration: 0.1)) { fabPressed = true }
            } onRelease: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { fabPressed = false }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 68)
        }
        .sheet(isPresented: $showAddSheet) { AddVaultEntryView(vaultStore: vaultStore) }
        .sheet(isPresented: $showPaywall) { PaywallView(subscriptionService: subscriptionService) }
        .sheet(item: $editingEntry) { entry in EditVaultEntryView(vaultStore: vaultStore, entry: entry) }
        .sheet(isPresented: Binding(get: { pendingDeleteEntry != nil }, set: { if !$0 { pendingDeleteEntry = nil } })) {
            FVDeleteConfirmSheet(
                title: pendingDeleteEntry?.title ?? "",
                icon: pendingDeleteEntry?.category.iconName ?? "trash",
                message: String(localized: "vault.dialog.delete.message"),
                onCancel: { pendingDeleteEntry = nil },
                onConfirm: { if let e = pendingDeleteEntry { delete(entry: e) }; pendingDeleteEntry = nil }
            )
        }
        .sheet(isPresented: $showBulkDeleteConfirm) {
            FVDeleteConfirmSheet(
                title: String(format: NSLocalizedString("vault.bulk.count %lld", comment: ""), selectedEntryIDs.count),
                icon: "trash.fill",
                message: String(localized: "vault.dialog.bulk.delete.message"),
                onCancel: { showBulkDeleteConfirm = false },
                onConfirm: { vaultStore.bulkMoveToTrash(entryIDs: selectedEntryIDs); selectedEntryIDs.removeAll(); selectionMode = false; showBulkDeleteConfirm = false }
            )
        }
        .alert(String(localized: "vault.dialog.tag.title"), isPresented: $showBulkTagPrompt) {
            TextField(String(localized: "vault.dialog.tag.placeholder"), text: $bulkTagText)
            Button(String(localized: "vault.action.apply")) { vaultStore.bulkApplyTag(entryIDs: selectedEntryIDs, tag: bulkTagText); bulkTagText = "" }
            Button(String(localized: "vault.action.cancel"), role: .cancel) { bulkTagText = "" }
        }
        .alert(String(localized: "vault.dialog.folder.title"), isPresented: $showBulkFolderPrompt) {
            TextField(String(localized: "vault.dialog.folder.placeholder"), text: $bulkFolderText)
            Button(String(localized: "vault.list.move")) { vaultStore.bulkMoveToFolder(entryIDs: selectedEntryIDs, folder: bulkFolderText); bulkFolderText = "" }
            Button(String(localized: "vault.action.cancel"), role: .cancel) { bulkFolderText = "" }
        }
        .onAppear {
            if let action = quickAction {
                applyQuickAction(action)
                quickAction = nil
            }
        }
        .onChange(of: quickAction) { _, newValue in
            guard let action = newValue else { return }
            applyQuickAction(action)
            quickAction = nil
        }
    }

    private func delete(entry: VaultEntry) {
        lastDeletedTrashID = vaultStore.moveToTrash(entryID: entry.id)
        showUndoDeleteToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            showUndoDeleteToast = false
            lastDeletedTrashID = nil
        }
    }

    private func applyQuickAction(_ action: VaultQuickAction) {
        query = ""
        selectionMode = false
        selectedEntryIDs.removeAll()

        switch action {
        case .weakPasswords:
            filterMode = .weak
            sortMode = .strength
            editingEntry = vaultStore.entries.first {
                [.faible, .moyen].contains(PasswordToolkit.strength(for: $0.password))
            }
        case .expiredPasswords:
            filterMode = .expired
            sortMode = .recent
            editingEntry = vaultStore.entries
                .filter { $0.isExpired || $0.isExpiringSoon }
                .sorted { ($0.daysUntilExpiration ?? .max) < ($1.daysUntilExpiration ?? .max) }
                .first
        case .missingMFA:
            filterMode = .all
            sortMode = .recent
            editingEntry = vaultStore.entries.first { !$0.mfaEnabled }
        case .reusedPasswords:
            filterMode = .all
            sortMode = .recent
            editingEntry = firstDuplicatedPasswordEntry()
        }
    }

    private func firstDuplicatedPasswordEntry() -> VaultEntry? {
        var counts: [String: Int] = [:]
        for entry in vaultStore.entries where !entry.password.isEmpty {
            counts[entry.password, default: 0] += 1
        }
        let duplicated = Set(counts.filter { $0.value > 1 }.map(\.key))
        return vaultStore.entries.first { duplicated.contains($0.password) }
    }
}
