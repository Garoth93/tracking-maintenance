import SwiftUI
import UpkeepCore

// MARK: - Object types

struct AssetTypesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var editing: AssetType?
    @State private var creating = false

    var body: some View {
        let data = store.data
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Definisci cosa vuoi tracciare: unità del contatore (km, ore, uscite…), campi personalizzati e se è un componente montabile (es. gomme).")
                    .font(.m3BodyMedium)
                    .foregroundStyle(m3.onSurfaceVariant)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                ForEach(data.assetTypes) { t in
                    let count = data.assets.filter { $0.typeID == t.id }.count
                    Button {
                        editing = t
                    } label: {
                        M3Card(padding: 14, corner: 22) {
                            HStack(spacing: 14) {
                                IconBadge(icon: t.icon, tones: m3.tones(t.color), size: 46, cookie: t.isComponent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                                    Text(details(t, count: count)).font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(m3.onSurfaceVariant)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .m3Screen(m3)
        .navigationTitle("Tipi di oggetto")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            FAB(icon: "plus", label: "Nuovo tipo") { creating = true }.padding(16)
        }
        .sheet(item: $editing) { t in AssetTypeFormView(original: t) }
        .sheet(isPresented: $creating) { AssetTypeFormView(original: nil) }
    }

    private func details(_ t: AssetType, count: Int) -> String {
        var parts: [String] = [t.tracksMeter ? "Contatore: \(t.meterUnit)" : "Senza contatore"]
        if t.isComponent { parts.append("componente") }
        if !t.fields.isEmpty { parts.append("\(t.fields.count) campi") }
        parts.append(count == 1 ? "1 oggetto" : "\(count) oggetti")
        return parts.joined(separator: " · ")
    }
}

struct AssetTypeFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let original: AssetType?
    @State private var draft: AssetType
    @State private var confirmDelete = false

    init(original: AssetType?) {
        self.original = original
        _draft = State(initialValue: original ?? AssetType(name: "", icon: "shippingbox.fill", color: Palette.colors[1], meterUnit: ""))
    }

    var body: some View {
        let canSave = !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
        SheetScaffold(original == nil ? "Nuovo tipo" : "Modifica tipo", canSave: canSave, onSave: save) {
            HStack {
                Spacer()
                IconBadge(icon: draft.icon, tones: m3.tones(draft.color), size: 80, cookie: true)
                Spacer()
            }
            FormSection("Nome") {
                M3TextField(label: "Nome del tipo", text: $draft.name, icon: "textformat", placeholder: "es. Monopattino")
            }
            FormSection("Contatore", footer: "L'unità con cui misuri l'uso: km per i mezzi, uscite per gli sci, ore per un motore… Lascia vuoto se non serve.") {
                M3TextField(label: "Unità", text: $draft.meterUnit, icon: "gauge.with.dots.needle.33percent", placeholder: "nessuna")
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(["km", "mi", "ore", "uscite", "utilizzi"], id: \.self) { u in
                        FilterChip(label: u, selected: draft.meterUnit == u) { draft.meterUnit = u }
                    }
                    FilterChip(label: "Nessuno", selected: draft.meterUnit.isEmpty) { draft.meterUnit = "" }
                }
            }
            FormCard {
                Toggle(isOn: $draft.isComponent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Componente montabile").font(.m3BodyLarge).foregroundStyle(m3.onSurface)
                        Text("Si monta su un altro oggetto e ne accumula il contatore (es. gomme sull'auto, ruote sulla bici).")
                            .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                    }
                }
                .toggleStyle(.m3)
            }
            FormSection("Campi personalizzati", footer: "Compaiono nella scheda di ogni oggetto di questo tipo (es. Targa, Misura, DOT).") {
                FieldsEditor(fields: $draft.fields)
            }
            FormSection("Colore") {
                ColorRow(selection: $draft.color)
            }
            FormSection("Icona") {
                IconPicker(selection: $draft.icon, tint: draft.color)
            }
            if original != nil {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Elimina tipo", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.m3Danger)
            }
        }
        .confirmationDialog("Eliminare il tipo “\(draft.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { delete() }
        }
    }

    private func save() {
        var t = draft
        t.name = t.name.trimmingCharacters(in: .whitespaces)
        t.meterUnit = t.meterUnit.trimmingCharacters(in: .whitespaces)
        t.fields = t.fields
            .map { f in var f = f; f.name = f.name.trimmingCharacters(in: .whitespaces); return f }
            .filter { !$0.name.isEmpty }
        let saved = t
        store.update { $0.saveAssetType(saved) }
        store.showToast(original == nil ? "Tipo “\(saved.name)” creato" : "Tipo aggiornato")
        dismiss()
    }

    private func delete() {
        guard let id = original?.id else { return }
        var blocked: DeleteBlock?
        store.update { blocked = $0.deleteAssetType(id: id) }
        if let blocked {
            store.errorMessage = "Impossibile eliminare il tipo. \(blocked.message) Sposta o elimina prima quegli oggetti."
        } else {
            store.showToast("Tipo eliminato")
            dismiss()
        }
    }
}

// MARK: - Operation types

struct OperationTypesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var editing: OperationType?
    @State private var creating = false
    @State private var filter: String?

    var body: some View {
        let data = store.data
        let list = data.operationTypes.filter { filter == nil || $0.applies(to: filter!) }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Le categorie di operazioni che registri. Con un intervallo (mesi e/o contatore) generano le scadenze.")
                    .font(.m3BodyMedium)
                    .foregroundStyle(m3.onSurfaceVariant)
                    .padding(.horizontal, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "Tutte", selected: filter == nil) { filter = nil }
                        ForEach(data.assetTypes) { t in
                            FilterChip(label: t.name, icon: t.icon, selected: filter == t.id) { filter = filter == t.id ? nil : t.id }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .padding(.bottom, 4)

                ForEach(list) { t in
                    Button {
                        editing = t
                    } label: {
                        M3Card(padding: 14, corner: 22) {
                            HStack(spacing: 14) {
                                IconBadge(icon: t.icon, tones: m3.tones(t.color), size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                                    Text(details(t, data: data)).font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(m3.onSurfaceVariant)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .m3Screen(m3)
        .navigationTitle("Tipi di operazione")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            FAB(icon: "plus", label: "Nuova") { creating = true }.padding(16)
        }
        .sheet(item: $editing) { t in OperationTypeFormView(original: t, presetAssetTypeID: nil) }
        .sheet(isPresented: $creating) { OperationTypeFormView(original: nil, presetAssetTypeID: filter) }
    }

    private func details(_ t: OperationType, data: AppData) -> String {
        let names = t.assetTypeIDs.compactMap { data.assetType($0)?.name }
        let unit = t.assetTypeIDs.compactMap { data.assetType($0)?.meterUnit }.first { !$0.isEmpty } ?? ""
        var parts = [names.isEmpty ? "Tutti i tipi" : names.joined(separator: ", ")]
        if !t.interval.isEmpty { parts.append(Fmt.interval(t.interval, unit: unit)) }
        return parts.joined(separator: " · ")
    }
}

struct OperationTypeFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let original: OperationType?
    @State private var draft: OperationType
    @State private var months: String
    @State private var meter: String
    @State private var confirmDelete = false

    init(original: OperationType?, presetAssetTypeID: String?) {
        self.original = original
        let base = original ?? OperationType(name: "", icon: "wrench.and.screwdriver.fill", color: Palette.colors[3],
                                             assetTypeIDs: presetAssetTypeID.map { [$0] } ?? [])
        _draft = State(initialValue: base)
        _months = State(initialValue: base.interval.months.map(String.init) ?? "")
        _meter = State(initialValue: Fmt.editable(base.interval.meter, decimals: 1))
    }

    var body: some View {
        let data = store.data
        let units = Set(draft.assetTypeIDs.compactMap { data.assetType($0)?.meterUnit }.filter { !$0.isEmpty })
        let unitLabel = units.count == 1 ? units.first! : (units.isEmpty ? "contatore" : units.sorted().joined(separator: "/"))
        let valid = !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && (months.isEmpty || Int(months) != nil)
            && (meter.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.parseNumber(meter) != nil)

        SheetScaffold(original == nil ? "Nuova operazione" : "Modifica operazione", canSave: valid, onSave: save) {
            HStack {
                Spacer()
                IconBadge(icon: draft.icon, tones: m3.tones(draft.color), size: 80, cookie: true)
                Spacer()
            }
            FormSection("Nome") {
                M3TextField(label: "Nome", text: $draft.name, icon: "textformat", placeholder: "es. Cambio pastiglie")
            }
            FormSection("Per quali oggetti", footer: draft.assetTypeIDs.isEmpty ? "Nessuna selezione: disponibile per tutti i tipi." : nil) {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    FilterChip(label: "Tutti", selected: draft.assetTypeIDs.isEmpty) { draft.assetTypeIDs = [] }
                    ForEach(data.assetTypes) { t in
                        let on = draft.assetTypeIDs.contains(t.id)
                        FilterChip(label: t.name, icon: t.icon, selected: on) {
                            if on { draft.assetTypeIDs.removeAll { $0 == t.id } } else { draft.assetTypeIDs.append(t.id) }
                        }
                    }
                }
            }
            FormSection("Intervallo e scadenza", footer: "La prossima scadenza arriva alla prima delle due soglie. Lascia vuoto per non avere scadenze; potrai comunque impostarle a mano su ogni operazione (es. data di scadenza dell'assicurazione).") {
                M3TextField(label: "Ogni (mesi)", text: $months, icon: "calendar", placeholder: "es. 12", suffix: "mesi", keyboard: .numberPad)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach([1, 3, 6, 12, 24, 48], id: \.self) { m in
                        FilterChip(label: m % 12 == 0 ? (m == 12 ? "1 anno" : "\(m / 12) anni") : "\(m) mesi", selected: months == String(m)) {
                            months = months == String(m) ? "" : String(m)
                        }
                    }
                }
                M3TextField(label: "Ogni (\(unitLabel))", text: $meter, icon: "gauge.with.dots.needle.33percent",
                            placeholder: "es. 15000", suffix: units.count == 1 ? units.first! : nil, keyboard: .decimalPad)
            }
            FormSection("Campi personalizzati", footer: "Es. Officina, Compagnia, N. polizza, Litri.") {
                FieldsEditor(fields: $draft.fields)
            }
            FormSection("Colore") {
                ColorRow(selection: $draft.color)
            }
            FormSection("Icona") {
                IconPicker(selection: $draft.icon, tint: draft.color)
            }
            if original != nil {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Elimina tipo di operazione", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.m3Danger)
            }
        }
        .confirmationDialog("Eliminare “\(draft.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { delete() }
        }
    }

    private func save() {
        var t = draft
        t.name = t.name.trimmingCharacters(in: .whitespaces)
        let m = Int(months).flatMap { $0 > 0 ? $0 : nil }
        let v = Fmt.parseNumber(meter).flatMap { $0 > 0 ? $0 : nil }
        t.interval = Interval(months: m, meter: v)
        t.fields = t.fields
            .map { f in var f = f; f.name = f.name.trimmingCharacters(in: .whitespaces); return f }
            .filter { !$0.name.isEmpty }
        let saved = t
        store.update { $0.saveOperationType(saved) }
        store.showToast(original == nil ? "“\(saved.name)” creata" : "Operazione aggiornata")
        dismiss()
    }

    private func delete() {
        guard let id = original?.id else { return }
        var blocked: DeleteBlock?
        store.update { blocked = $0.deleteOperationType(id: id) }
        if let blocked {
            store.errorMessage = "Impossibile eliminare. \(blocked.message) Elimina prima quelle operazioni o rinomina questo tipo."
        } else {
            store.showToast("Tipo di operazione eliminato")
            dismiss()
        }
    }
}
