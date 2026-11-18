import SwiftUI
import UniformTypeIdentifiers
import UpkeepCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var exportDocument: TextFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: AppData?
    @State private var confirmReset = false
    @State private var confirmDemo = false

    var body: some View {
        let data = store.data
        let settings = data.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: "Opzioni", subtitle: "Personalizza tipi, scadenze e aspetto")

                FormSection("Personalizza") {
                    VStack(spacing: 0) {
                        NavigationLink(value: Route.assetTypes) {
                            navRow("Tipi di oggetto", subtitle: "\(data.assetTypes.count) · auto, sci, gomme… con unità e campi", icon: "square.stack.3d.up.fill")
                        }
                        Divider().overlay(m3.outlineVariant).padding(.leading, 56)
                        NavigationLink(value: Route.operationTypes) {
                            navRow("Tipi di operazione", subtitle: "\(data.operationTypes.count) · intervalli e campi personalizzati", icon: "wrench.and.screwdriver.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .background(m3.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                FormSection("Aspetto") {
                    M3Card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                ForEach(ThemeMode.allCases, id: \.self) { mode in
                                    FilterChip(label: mode.label, icon: themeIcon(mode), selected: settings.theme == mode) {
                                        store.updateSettings { $0.theme = mode }
                                    }
                                }
                            }
                            Text("Colore principale").font(.m3LabelLarge).foregroundStyle(m3.onSurfaceVariant)
                            ColorRow(selection: binding(\.accent))
                        }
                    }
                }

                FormSection("Scadenze", footer: "Una scadenza diventa “a breve” quando mancano pochi giorni (anche stimati dai km medi) o una piccola parte dell'intervallo.") {
                    M3Card {
                        VStack(spacing: 14) {
                            M3Row("Avviso a breve", subtitle: "giorni prima della scadenza", icon: "clock") {
                                M3Stepper(value: binding(\.soonDays), range: 1...120, step: 1) { "\($0) g" }
                            }
                            M3Row("Soglia contatore", subtitle: "parte dell'intervallo rimasta", icon: "gauge.with.dots.needle.33percent") {
                                M3Stepper(value: binding(\.soonMeterPercent), range: 1...50, step: 1) { "\($0)%" }
                            }
                        }
                    }
                }

                FormSection("Notifiche", footer: "Promemoria locali per le scadenze con data (o stimata). Funzionano anche con l'account Apple gratuito.") {
                    M3Card {
                        VStack(spacing: 14) {
                            Toggle(isOn: notificationsBinding) {
                                Label("Promemoria", systemImage: "bell.badge").font(.m3BodyLarge).foregroundStyle(m3.onSurface)
                            }
                            .toggleStyle(.m3)
                            if settings.notificationsEnabled {
                                M3Row("Anticipo", subtitle: "oltre al giorno stesso", icon: "calendar") {
                                    M3Stepper(value: binding(\.notifyDaysBefore), range: 0...60, step: 1) { $0 == 0 ? "no" : "\($0) g" }
                                }
                                M3Row("Ora", icon: "alarm") {
                                    M3Stepper(value: binding(\.notifyHour), range: 6...22, step: 1) { String(format: "%02d:00", $0) }
                                }
                            }
                        }
                    }
                }

                FormSection("Valuta") {
                    M3Card {
                        M3Row("Simbolo", icon: "eurosign") {
                            HStack(spacing: 6) {
                                ForEach(["€", "CHF", "$", "£"], id: \.self) { s in
                                    FilterChip(label: s, selected: settings.currencySymbol == s) {
                                        store.updateSettings { $0.currencySymbol = s }
                                    }
                                }
                            }
                        }
                    }
                }

                FormSection("Dati", footer: "I dati restano solo su questo iPhone e sopravvivono alla rifirma dell'app. Se elimini l'app vanno persi: esporta un backup ogni tanto. \(data.assets.count) oggetti · \(data.operations.count) operazioni · \(data.readings.count) letture.") {
                    VStack(spacing: 0) {
                        actionRow("Backup JSON", icon: "externaldrive.fill") { startExport(json: true) }
                        Divider().overlay(m3.outlineVariant).padding(.leading, 56)
                        actionRow("Importa backup JSON", icon: "square.and.arrow.down.fill") { isImporting = true }
                        Divider().overlay(m3.outlineVariant).padding(.leading, 56)
                        actionRow("Esporta operazioni CSV", icon: "tablecells.fill") { startExport(json: false) }
                        Divider().overlay(m3.outlineVariant).padding(.leading, 56)
                        actionRow("Carica dati di esempio", icon: "sparkles") { confirmDemo = true }
                        Divider().overlay(m3.outlineVariant).padding(.leading, 56)
                        actionRow("Cancella tutto", icon: "trash.fill", destructive: true) { confirmReset = true }
                    }
                    .background(m3.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                Text("Upkeep \(appVersion)")
                    .font(.m3LabelMedium)
                    .foregroundStyle(m3.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .m3Screen(m3)
        .toolbar(.hidden, for: .navigationBar)
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
            switch result {
            case .success: store.showToast("File esportato")
            case .failure(let error): store.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .plainText]) { result in
            handleImport(result)
        }
        .alert(
            "Sostituire tutti i dati attuali con quelli del file?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            presenting: pendingImport
        ) { newData in
            Button("Sostituisci", role: .destructive) {
                store.replaceAll(with: newData)
                store.showToast("Dati importati")
            }
            Button("Annulla", role: .cancel) {}
        } message: { newData in
            Text("Il file contiene \(newData.assets.count) oggetti e \(newData.operations.count) operazioni.")
        }
        .confirmationDialog("Cancellare TUTTI gli oggetti e lo storico?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Cancella tutto", role: .destructive) {
                store.resetAll(withDemo: false)
                store.showToast("Dati cancellati")
            }
        } message: {
            Text("Anche i tipi personalizzati tornano a quelli predefiniti.")
        }
        .confirmationDialog("Sostituire tutto con i dati di esempio?", isPresented: $confirmDemo, titleVisibility: .visible) {
            Button("Carica esempio", role: .destructive) {
                store.resetAll(withDemo: true)
                store.showToast("Dati di esempio caricati")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func themeIcon(_ mode: ThemeMode) -> String {
        switch mode {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private func navRow(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(m3.onPrimaryContainer)
                .frame(width: 40, height: 40)
                .background(m3.primaryContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.m3BodyLarge).foregroundStyle(m3.onSurface)
                Text(subtitle).font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(m3.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func actionRow(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(destructive ? m3.error : m3.onSurfaceVariant)
                    .frame(width: 40)
                Text(title).font(.m3BodyLarge).foregroundStyle(destructive ? m3.error : m3.onSurface)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.data.settings[keyPath: keyPath] },
            set: { newValue in store.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.data.settings.notificationsEnabled },
            set: { on in
                store.updateSettings { $0.notificationsEnabled = on }
                guard on else { return }
                Task {
                    let granted = await Notifier.requestAuthorization()
                    if granted {
                        store.scheduleReminders()
                        store.showToast("Promemoria attivati")
                    } else {
                        store.updateSettings { $0.notificationsEnabled = false }
                        store.errorMessage = "Notifiche non consentite. Puoi abilitarle in Impostazioni → Notifiche → Upkeep."
                    }
                }
            }
        )
    }

    // MARK: - Import / export

    private func startExport(json: Bool) {
        let stamp = DayDate.today().iso
        do {
            if json {
                exportDocument = TextFileDocument(data: try JSONFileStore<AppData>.encoder.encode(store.data))
                exportType = .json
                exportName = "upkeep-backup-\(stamp)"
            } else {
                exportDocument = TextFileDocument(data: Data(store.data.operationsCSV().utf8))
                exportType = .commaSeparatedText
                exportName = "upkeep-operazioni-\(stamp)"
            }
            isExporting = true
        } catch {
            store.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try JSONFileStore<AppData>.decoder.decode(AppData.self, from: Data(contentsOf: url))
            } catch {
                store.errorMessage = "Impossibile importare: il file non è un backup valido di Upkeep."
            }
        case .failure(let error):
            store.errorMessage = "Impossibile importare: \(error.localizedDescription)"
        }
    }
}
