import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @ObservedObject var vaultStore: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: ImportStep = .selectFormat
    @State private var csvText = ""
    @State private var selectedFormat: ImportFormat = .bitwardenCSV
    @State private var previewEntries: [VaultEntry] = []
    @State private var duplicateStrategy: ImportDuplicateStrategy = .skip
    @State private var columnMapping = CSVColumnMapping()
    @State private var headers: [String] = []
    @State private var importResult: ImportResult?
    @State private var showFileImporter = false
    @State private var parseError = ""

    enum ImportStep {
        case selectFormat
        case columnMapping
        case preview
        case result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    switch step {
                    case .selectFormat:
                        formatSelectionStep
                    case .columnMapping:
                        columnMappingStep
                    case .preview:
                        previewStep
                    case .result:
                        resultStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle(String(localized: "import.nav.title"))
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        csvText = text
                        processCSV()
                    }
                case .failure:
                    parseError = String(localized: "import.error.file_read")
                }
            }
        }
    }

    // MARK: - Step 1: Format Selection

    private var formatSelectionStep: some View {
        VStack(spacing: 16) {
            FVSectionHeader(icon: "square.and.arrow.down", title: String(localized: "import.section.format"))

            Text(String(localized: "import.format.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(ImportFormat.allCases) { format in
                Button {
                    selectedFormat = format
                } label: {
                    HStack {
                        Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedFormat == format ? FVColor.cyan : FVColor.mist.opacity(0.5))
                        Text(format.rawValue)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            if !parseError.isEmpty {
                Text(parseError)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FVButton(title: String(localized: "import.button.choose_file")) {
                showFileImporter = true
            }

            Text(String(localized: "import.format.hint"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.7))
        }
        .fvGlass()
    }

    // MARK: - Step 2: Column Mapping (Generic CSV only)

    private var columnMappingStep: some View {
        VStack(spacing: 16) {
            FVSectionHeader(icon: "tablecells", title: String(localized: "import.section.column_mapping"))

            Text(String(localized: "import.mapping.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist)
                .frame(maxWidth: .infinity, alignment: .leading)

            mappingPicker(String(localized: "import.mapping.title"), selection: $columnMapping.titleColumn)
            mappingPicker(String(localized: "import.mapping.username"), selection: $columnMapping.usernameColumn)
            mappingPicker(String(localized: "import.mapping.password"), selection: $columnMapping.passwordColumn)
            mappingPicker(String(localized: "import.mapping.website"), selection: $columnMapping.websiteColumn)
            mappingPicker(String(localized: "import.mapping.notes"), selection: $columnMapping.notesColumn)
            mappingPicker(String(localized: "import.mapping.folder"), selection: $columnMapping.folderColumn)
            mappingPicker("TOTP", selection: $columnMapping.totpColumn)

            FVButton(title: String(localized: "import.button.continue")) {
                previewEntries = ImportService.parseGenericCSV(csvText, mapping: columnMapping)
                step = .preview
            }
        }
        .fvGlass()
    }

    private func mappingPicker(_ label: String, selection: Binding<Int?>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 100, alignment: .leading)
            Picker("", selection: Binding(
                get: { selection.wrappedValue ?? -1 },
                set: { selection.wrappedValue = $0 == -1 ? nil : $0 }
            )) {
                Text("—").tag(-1)
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    Text(header).tag(idx)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(FVColor.cyan)
        }
    }

    // MARK: - Step 3: Preview

    private var previewStep: some View {
        VStack(spacing: 16) {
            FVSectionHeader(icon: "eye", title: String(localized: "import.section.preview"))

            Text(String(format: NSLocalizedString("import.preview.entries_detected %lld", comment: ""), previewEntries.count))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Show first 10 entries
            ForEach(previewEntries.prefix(10)) { entry in
                HStack {
                    Image(systemName: entry.category.iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.category.iconColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(entry.username)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(FVColor.mist)
                    }
                    Spacer()
                    if !entry.website.isEmpty {
                        Text(entry.website)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(FVColor.cyan.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }

            if previewEntries.count > 10 {
                Text(String(format: NSLocalizedString("import.preview.more %lld", comment: ""), previewEntries.count - 10))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(FVColor.mist.opacity(0.6))
            }

            // Duplicate strategy
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "import.preview.duplicates"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Picker(String(localized: "import.preview.strategy"), selection: $duplicateStrategy) {
                    ForEach(ImportDuplicateStrategy.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(FVColor.cyan)
            }

            FVButton(title: String(format: NSLocalizedString("import.button.import %lld", comment: ""), previewEntries.count)) {
                let result = ImportService.deduplicate(
                    imported: previewEntries,
                    existing: vaultStore.entries,
                    strategy: duplicateStrategy
                )
                if !result.entries.isEmpty {
                    vaultStore.importEntries(result.entries)
                }
                importResult = result
                step = .result
            }
        }
        .fvGlass()
    }

    // MARK: - Step 4: Result

    private var resultStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(FVColor.success)

            Text(String(localized: "import.result.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if let result = importResult {
                VStack(spacing: 8) {
                    resultRow(String(localized: "import.result.imported"), value: "\(result.entries.count)", color: FVColor.success)
                    if result.duplicateCount > 0 {
                        resultRow(String(localized: "import.result.duplicates"), value: "\(result.duplicateCount)", color: FVColor.warning)
                    }
                    if result.skippedCount > 0 {
                        resultRow(String(localized: "import.result.skipped"), value: "\(result.skippedCount)", color: FVColor.mist)
                    }
                }
            }

            FVButton(title: String(localized: "import.button.finish")) {
                dismiss()
            }
        }
        .fvGlass()
    }

    private func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    // MARK: - Processing

    private func processCSV() {
        parseError = ""

        // Auto-detect if no format chosen
        if let detected = ImportService.detectFormat(from: csvText) {
            selectedFormat = detected
        }

        switch selectedFormat {
        case .bitwardenCSV:
            previewEntries = ImportService.parseBitwardenCSV(csvText)
            if previewEntries.isEmpty {
                parseError = String(localized: "import.error.no_entries")
            } else {
                step = .preview
            }
        case .onePasswordCSV:
            previewEntries = ImportService.parseOnePasswordCSV(csvText)
            if previewEntries.isEmpty {
                parseError = String(localized: "import.error.no_entries")
            } else {
                step = .preview
            }
        case .genericCSV:
            headers = ImportService.extractHeaders(from: csvText)
            if headers.isEmpty {
                parseError = String(localized: "import.error.empty_file")
            } else {
                // Auto-map common column names
                for (idx, h) in headers.enumerated() {
                    let lower = h.lowercased()
                    if lower.contains("title") || lower.contains("name") || lower.contains("titre") || lower.contains("nom") {
                        columnMapping.titleColumn = idx
                    } else if lower.contains("username") || lower.contains("user") || lower.contains("email") || lower.contains("identifiant") {
                        columnMapping.usernameColumn = idx
                    } else if lower.contains("password") || lower.contains("mot de passe") {
                        columnMapping.passwordColumn = idx
                    } else if lower.contains("url") || lower.contains("website") || lower.contains("site") {
                        columnMapping.websiteColumn = idx
                    } else if lower.contains("note") {
                        columnMapping.notesColumn = idx
                    } else if lower.contains("folder") || lower.contains("dossier") {
                        columnMapping.folderColumn = idx
                    } else if lower.contains("totp") || lower.contains("otp") || lower.contains("2fa") {
                        columnMapping.totpColumn = idx
                    }
                }
                step = .columnMapping
            }
        }
    }
}
