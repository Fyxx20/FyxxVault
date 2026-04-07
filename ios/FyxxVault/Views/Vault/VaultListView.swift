import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - VaultListView (1Password / Linear Quality Redesign)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VaultListView: View {
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var syncService: SyncService
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

    // MARK: - Filtered Entries

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

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainScrollContent
            undoToastOverlay
            fabButton
        }
        .vaultListSheets(
            showAddSheet: $showAddSheet,
            showPaywall: $showPaywall,
            editingEntry: $editingEntry,
            pendingDeleteEntry: $pendingDeleteEntry,
            showBulkDeleteConfirm: $showBulkDeleteConfirm,
            showBulkTagPrompt: $showBulkTagPrompt,
            showBulkFolderPrompt: $showBulkFolderPrompt,
            bulkTagText: $bulkTagText,
            bulkFolderText: $bulkFolderText,
            selectedEntryIDs: $selectedEntryIDs,
            selectionMode: $selectionMode,
            vaultStore: vaultStore,
            subscriptionService: subscriptionService,
            deleteFn: delete
        )
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

    // MARK: - Main Scroll Content

    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                vaultHeader
                    .padding(.bottom, 16)

                persistenceErrorBanner
                    .padding(.bottom, 12)

                searchBar
                    .padding(.bottom, 12)

                filterChipsRow
                    .padding(.bottom, 8)

                categoryChipsSection
                    .padding(.bottom, 8)

                bulkSelectionBar
                    .padding(.bottom, 8)

                integrityWarningBanner
                    .padding(.bottom, 8)

                entryListOrEmpty

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            guard syncService.isCloudAuthenticated else { return }
            let merged = try? await syncService.sync(localEntries: vaultStore.entries)
            if let merged { await MainActor.run { vaultStore.replaceEntries(merged) } }
        }
    }

    // MARK: - Actions

    private func delete(entry: VaultEntry) {
        lastDeletedTrashID = vaultStore.moveToTrash(entryID: entry.id)
        showUndoDeleteToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            showUndoDeleteToast = false
            lastDeletedTrashID = nil
        }
    }

    private func triggerAdd() {
        fvHaptic(.medium)
        if !subscriptionService.isProUser && vaultStore.entries.count >= 5 {
            showPaywall = true
        } else {
            showAddSheet = true
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Header
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    var vaultHeader: some View {
        VStack(spacing: 0) {
            if subscriptionService.isProUser {
                proHeader
            } else {
                freeHeader
            }
        }
    }

    // MARK: - Free Header
    var freeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Coffre-fort")
                    .font(FVFont.heading(28))
                    .foregroundStyle(.white)
                Spacer()
            }

            // Usage bar: X/5
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(vaultStore.entries.count)/5 comptes")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(vaultStore.entries.count >= 5 ? FVColor.warning : FVColor.smoke)
                    Spacer()
                    Text("Gratuit")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(FVColor.smoke)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                vaultStore.entries.count >= 5
                                    ? FVColor.warning
                                    : FVColor.cyan
                            )
                            .frame(width: geo.size.width * CGFloat(min(vaultStore.entries.count, 5)) / 5.0)
                            .animation(.spring(response: 0.4), value: vaultStore.entries.count)
                    }
                }
                .frame(height: 4)

                // Upgrade hint
                if vaultStore.entries.count >= 4 {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text("Passer \u{00E0} Pro \u{2014} comptes illimit\u{00E9}s")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(FVColor.gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Pro Header
    var proHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Coffre-fort")
                        .font(FVFont.heading(28))
                        .foregroundStyle(.white)

                    // Pro badge
                    HStack(spacing: 3) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                        Text("PRO")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .kerning(0.8)
                    }
                    .foregroundStyle(FVColor.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FVColor.gold.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("\(vaultStore.entries.count) \u{00E9}l\u{00E9}ments \u{00B7} Chiffrement AES-256")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FVColor.smoke)
            }

            Spacer()
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Search Bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSearchFocused ? FVColor.cyan : FVColor.smoke)

            TextField("Rechercher...", text: $query)
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
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSearchFocused ? FVColor.cyan.opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Filter Chips Row
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(VaultFilterMode.allCases) { f in
                    VaultFilterChip(
                        label: f.rawValue,
                        isActive: filterMode == f,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterMode = f
                            }
                            fvHaptic(.light)
                        }
                    )
                }

                // Sort menu inline
                Menu {
                    ForEach(VaultSortMode.allCases) { m in
                        Button {
                            sortMode = m
                            fvHaptic(.light)
                        } label: {
                            Label(m.rawValue, systemImage: sortMode == m ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text(sortMode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(FVColor.smoke)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Sort + Select Row
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    var sortAndSelectRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VaultSortMode.allCases) { m in
                    VaultSortChip(
                        mode: m,
                        isActive: sortMode == m,
                        onTap: {
                            sortMode = m
                            fvHaptic(.light)
                        }
                    )
                }

                VaultSelectChip(
                    isActive: selectionMode,
                    onTap: {
                        selectionMode.toggle()
                        if !selectionMode { selectedEntryIDs.removeAll() }
                        fvHaptic(.light)
                    }
                )
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Category Chips, Bulk Bar, Banners
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    @ViewBuilder
    var categoryChipsSection: some View {
        if filterMode == .byCategory {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VaultCategory.allCases) { cat in
                        VaultCategoryChip(
                            category: cat,
                            isSelected: selectedCategory == cat,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategory = (selectedCategory == cat) ? nil : cat
                                }
                                fvHaptic(.light)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    var bulkSelectionBar: some View {
        if selectionMode {
            VaultBulkBar(
                selectedCount: selectedEntryIDs.count,
                onTag: { showBulkTagPrompt = true },
                onMove: { showBulkFolderPrompt = true },
                onFavorite: { vaultStore.bulkSetFavorite(entryIDs: selectedEntryIDs, value: true) },
                onDelete: { showBulkDeleteConfirm = true }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    var persistenceErrorBanner: some View {
        if !vaultStore.persistenceError.isEmpty {
            VaultBannerView(
                icon: "exclamationmark.triangle.fill",
                text: vaultStore.persistenceError,
                color: FVColor.danger
            )
        }
    }

    @ViewBuilder
    var integrityWarningBanner: some View {
        if !vaultStore.integrityWarning.isEmpty {
            VaultBannerView(
                icon: "shield.exclamationmark",
                text: vaultStore.integrityWarning,
                color: FVColor.danger.opacity(0.9)
            )
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Entry List / Empty State
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    @ViewBuilder
    var entryListOrEmpty: some View {
        if filteredEntries.isEmpty {
            VaultEmptyState(
                isProUser: subscriptionService.isProUser,
                entryCount: vaultStore.entries.count,
                onAdd: { showAddSheet = true },
                onPaywall: { showPaywall = true }
            )
        } else {
            LazyVStack(spacing: 8) {
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
                    .fvAppear(delay: Double(index) * 0.04)
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Undo Toast
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    @ViewBuilder
    var undoToastOverlay: some View {
        if showUndoDeleteToast {
            VStack {
                Spacer()
                HStack {
                    Text(String(localized: "vault.list.toast.deleted"))
                        .font(FVFont.caption(13))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(String(localized: "vault.action.cancel")) {
                        if let id = lastDeletedTrashID { vaultStore.restoreFromTrash(id) }
                        showUndoDeleteToast = false
                        lastDeletedTrashID = nil
                    }
                    .font(FVFont.caption(13))
                    .foregroundStyle(FVColor.cyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - FAB
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension VaultListView {
    var fabButton: some View {
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
                    .fill(FVGradient.cyanToViolet)
                    .frame(width: 54, height: 54)
                    .shadow(color: FVColor.cyan.opacity(0.3), radius: 16, y: 6)

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
        .padding(.bottom, 24)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Count Pill
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultCountPill: View {
    let count: Int

    private var label: String {
        count == 1
            ? "1 element"
            : "\(count) elements"
    }

    var body: some View {
        Text(label)
            .font(FVFont.caption(11))
            .foregroundStyle(FVColor.smoke)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .contentTransition(.numericText())
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Filter Chip
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultFilterChip: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(FVFont.caption(12))
                .foregroundStyle(isActive ? FVColor.cyan : FVColor.smoke)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? FVColor.cyan.opacity(0.12) : Color.white.opacity(0.04))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? FVColor.cyan.opacity(0.3) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Sort Chip
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultSortChip: View {
    let mode: VaultSortMode
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                Text(mode.rawValue)
                    .font(FVFont.caption(12))
            }
            .foregroundStyle(isActive ? FVColor.cyan : FVColor.smoke)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? FVColor.cyan.opacity(0.12) : Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isActive ? FVColor.cyan.opacity(0.3) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Select Chip
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultSelectChip: View {
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isActive ? String(localized: "vault.list.done") : String(localized: "vault.list.select"))
                .font(FVFont.caption(12))
                .foregroundStyle(isActive ? FVColor.cyan : FVColor.smoke)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? FVColor.cyan.opacity(0.12) : Color.white.opacity(0.04))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? FVColor.cyan.opacity(0.3) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Category Chip
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultCategoryChip: View {
    let category: VaultCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: category.iconName)
                    .font(.system(size: 10))
                Text(category.label)
                    .font(FVFont.caption(12))
            }
            .foregroundStyle(isSelected ? .white : FVColor.smoke)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [category.iconColor.opacity(0.5), FVColor.violet.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.04)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : Color.white.opacity(0.06),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Banner View (reusable for errors/warnings)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultBannerView: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(FVFont.caption(12))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Bulk Selection Bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultBulkBar: View {
    let selectedCount: Int
    let onTag: () -> Void
    let onMove: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Text(String(format: NSLocalizedString("vault.list.selected %lld", comment: ""), selectedCount))
                    .font(FVFont.caption(11))
                    .kerning(1.2)
                    .foregroundStyle(FVColor.smoke)

                bulkButton(String(localized: "vault.list.tag"), color: FVColor.cyan, action: onTag)
                bulkButton(String(localized: "vault.list.move"), color: FVColor.cyan, action: onMove)
                bulkButton(String(localized: "vault.list.favorite"), color: .yellow.opacity(0.9), action: onFavorite)
                bulkButton(String(localized: "vault.list.delete"), color: FVColor.danger.opacity(0.9), action: onDelete)
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func bulkButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(FVFont.caption(12))
            .foregroundStyle(color)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Empty State
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultEmptyState: View {
    let isProUser: Bool
    let entryCount: Int
    let onAdd: () -> Void
    let onPaywall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)

            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(FVColor.smoke.opacity(0.3))
                .padding(.bottom, 4)

            Text("Ton coffre est vide")
                .font(FVFont.heading(20))
                .foregroundStyle(.white)

            Text(String(localized: "vault.list.empty.subtitle"))
                .font(FVFont.body(14))
                .foregroundStyle(FVColor.smoke)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                fvHaptic(.medium)
                if !isProUser && entryCount >= 5 {
                    onPaywall()
                } else {
                    onAdd()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Ajouter un premier element")
                        .font(FVFont.label(14))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(FVGradient.cyanToViolet)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Sheets Modifier
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct VaultListSheetsModifier: ViewModifier {
    @Binding var showAddSheet: Bool
    @Binding var showPaywall: Bool
    @Binding var editingEntry: VaultEntry?
    @Binding var pendingDeleteEntry: VaultEntry?
    @Binding var showBulkDeleteConfirm: Bool
    @Binding var showBulkTagPrompt: Bool
    @Binding var showBulkFolderPrompt: Bool
    @Binding var bulkTagText: String
    @Binding var bulkFolderText: String
    @Binding var selectedEntryIDs: Set<UUID>
    @Binding var selectionMode: Bool
    let vaultStore: VaultStore
    let subscriptionService: SubscriptionService
    let deleteFn: (VaultEntry) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAddSheet) { AddVaultEntryView(vaultStore: vaultStore) }
            .sheet(isPresented: $showPaywall) { PaywallView(subscriptionService: subscriptionService) }
            .sheet(item: $editingEntry) { entry in EditVaultEntryView(vaultStore: vaultStore, entry: entry) }
            .sheet(isPresented: Binding(get: { pendingDeleteEntry != nil }, set: { if !$0 { pendingDeleteEntry = nil } })) {
                FVDeleteConfirmSheet(
                    title: pendingDeleteEntry?.title ?? "",
                    icon: pendingDeleteEntry?.category.iconName ?? "trash",
                    message: String(localized: "vault.dialog.delete.message"),
                    onCancel: { pendingDeleteEntry = nil },
                    onConfirm: { if let e = pendingDeleteEntry { deleteFn(e) }; pendingDeleteEntry = nil }
                )
            }
            .sheet(isPresented: $showBulkDeleteConfirm) {
                FVDeleteConfirmSheet(
                    title: String(format: NSLocalizedString("vault.bulk.count %lld", comment: ""), selectedEntryIDs.count),
                    icon: "trash.fill",
                    message: String(localized: "vault.dialog.bulk.delete.message"),
                    onCancel: { showBulkDeleteConfirm = false },
                    onConfirm: {
                        vaultStore.bulkMoveToTrash(entryIDs: selectedEntryIDs)
                        selectedEntryIDs.removeAll()
                        selectionMode = false
                        showBulkDeleteConfirm = false
                    }
                )
            }
            .alert(String(localized: "vault.dialog.tag.title"), isPresented: $showBulkTagPrompt) {
                TextField(String(localized: "vault.dialog.tag.placeholder"), text: $bulkTagText)
                Button(String(localized: "vault.action.apply")) {
                    vaultStore.bulkApplyTag(entryIDs: selectedEntryIDs, tag: bulkTagText)
                    bulkTagText = ""
                }
                Button(String(localized: "vault.action.cancel"), role: .cancel) { bulkTagText = "" }
            }
            .alert(String(localized: "vault.dialog.folder.title"), isPresented: $showBulkFolderPrompt) {
                TextField(String(localized: "vault.dialog.folder.placeholder"), text: $bulkFolderText)
                Button(String(localized: "vault.list.move")) {
                    vaultStore.bulkMoveToFolder(entryIDs: selectedEntryIDs, folder: bulkFolderText)
                    bulkFolderText = ""
                }
                Button(String(localized: "vault.action.cancel"), role: .cancel) { bulkFolderText = "" }
            }
    }
}

private extension View {
    func vaultListSheets(
        showAddSheet: Binding<Bool>,
        showPaywall: Binding<Bool>,
        editingEntry: Binding<VaultEntry?>,
        pendingDeleteEntry: Binding<VaultEntry?>,
        showBulkDeleteConfirm: Binding<Bool>,
        showBulkTagPrompt: Binding<Bool>,
        showBulkFolderPrompt: Binding<Bool>,
        bulkTagText: Binding<String>,
        bulkFolderText: Binding<String>,
        selectedEntryIDs: Binding<Set<UUID>>,
        selectionMode: Binding<Bool>,
        vaultStore: VaultStore,
        subscriptionService: SubscriptionService,
        deleteFn: @escaping (VaultEntry) -> Void
    ) -> some View {
        modifier(VaultListSheetsModifier(
            showAddSheet: showAddSheet,
            showPaywall: showPaywall,
            editingEntry: editingEntry,
            pendingDeleteEntry: pendingDeleteEntry,
            showBulkDeleteConfirm: showBulkDeleteConfirm,
            showBulkTagPrompt: showBulkTagPrompt,
            showBulkFolderPrompt: showBulkFolderPrompt,
            bulkTagText: bulkTagText,
            bulkFolderText: bulkFolderText,
            selectedEntryIDs: selectedEntryIDs,
            selectionMode: selectionMode,
            vaultStore: vaultStore,
            subscriptionService: subscriptionService,
            deleteFn: deleteFn
        ))
    }
}
