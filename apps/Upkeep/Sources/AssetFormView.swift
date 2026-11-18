import SwiftUI
import UpkeepCore

struct AssetFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss

    let original: Asset?
    @State private var typeID: String
    @State private var name: String
    @State private var icon: String?
    @State private var color: String?
    @State private var notes: String
    @State private var initialMeter: String
    @State private var attributes: [String: String]
    @State private var createdOn: DayDate
    @State private var mountOn: String?
    @State private var showAppearance = false

    init(original: Asset?, presetTypeID: String?) {
        self.original = original
        let o = original
        _typeID = State(initialValue: o?.typeID ?? presetTypeID ?? "")
        _name = State(initialValue: o?.name ?? "")
        _icon = State(initialValue: o?.icon)
        _color = State(initialValue: o?.color)
        _notes = State(initialValue: o?.notes ?? "")
        _initialMeter = State(initialValue: o.map { Fmt.editable($0.initialMeter, decimals: 1) } ?? "")
        _attributes = State(initialValue: o?.attributes ?? [:])
        _createdOn = State(initialValue: o?.createdOn ?? .today())
        _mountOn = State(initialValue: nil)
    }

    var body: some View {
        let data = store.data
        let type = data.assetType(typeID)
        let effectiveIcon = icon ?? type?.icon ?? "shippingbox.fill"
        let effectiveColor = color ?? type?.color ?? Palette.defaultAccent
        let meterValid = initialMeter.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.parseNumber(initialMeter) != nil
        let canSave = type != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty && meterValid

        SheetScaffold(original == nil ? "Nuovo oggetto" : "Modifica oggetto", canSave: canSave, onSave: save) {
            HStack {
                Spacer()
                IconBadge(icon: effectiveIcon, tones: m3.tones(effectiveColor), size: 84, cookie: true)
                    .onTapGesture { withAnimation(.snappy) { showAppearance.toggle() } }
                Spacer()
            }
            .padding(.top, 4)

            FormSection("Tipo") {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(data.assetTypes) { t in
                        FilterChip(label: t.name, icon: t.icon, selected: t.id == typeID) {
                            withAnimation(.snappy) { typeID = t.id }
                        }
                    }
                }
                if data.assetTypes.isEmpty {
                    Text("Crea prima un tipo di oggetto nelle Opzioni.").font(.m3BodySmall).foregroundStyle(m3.error)
                }
            }

            FormSection("Generale") {
                M3TextField(label: "Nome", text: $name, icon: "textformat", placeholder: placeholderName(type))
                if let type, type.tracksMeter {
                    M3TextField(
                        label: original == nil ? "\(type.meterUnit.capitalized) attuali" : "Valore iniziale (\(type.meterUnit))",
                        text: $initialMeter,
                        icon: "gauge.with.dots.needle.33percent",
                        placeholder: "0",
                        suffix: type.meterUnit,
                        keyboard: .decimalPad
                    )
                }
                M3DateField(label: "Aggiunto il", day: $createdOn)
            }

            if let type, !type.fields.isEmpty {
                FormSection(type.name) {
                    ForEach(type.fields) { f in
                        AttributeField(field: f, values: $attributes)
                    }
                }
            }

            if original == nil, let type, type.isComponent {
                let hosts = data.sortedAssets().filter { !data.isComponent($0) }
                if !hosts.isEmpty {
                    FormSection("Monta subito su", footer: "Mentre è montato accumula i \(type.meterUnit.isEmpty ? "valori" : type.meterUnit) dell'oggetto su cui si trova.") {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            FilterChip(label: "Non montato", selected: mountOn == nil) { mountOn = nil }
                            ForEach(hosts) { h in
                                FilterChip(label: h.name, icon: data.icon(of: h), selected: mountOn == h.id) { mountOn = h.id }
                            }
                        }
                    }
                }
            }

            FormSection("Aspetto") {
                Button {
                    withAnimation(.snappy) { showAppearance.toggle() }
                } label: {
                    M3Row("Icona e colore", subtitle: icon == nil && color == nil ? "Quelli del tipo" : "Personalizzati", icon: "paintpalette") {
                        Image(systemName: showAppearance ? "chevron.up" : "chevron.down")
                            .foregroundStyle(m3.onSurfaceVariant)
                    }
                }
                .buttonStyle(.plain)
                if showAppearance {
                    ColorRow(selection: Binding(get: { effectiveColor }, set: { color = $0 }))
                    IconPicker(selection: Binding(get: { effectiveIcon }, set: { icon = $0 }), tint: effectiveColor)
                    if icon != nil || color != nil {
                        Button("Usa quelli del tipo") { icon = nil; color = nil }
                            .buttonStyle(.m3Text)
                    }
                }
            }

            FormSection("Note") {
                M3TextField(label: "Note", text: $notes, icon: "note.text", placeholder: "Facoltative", multiline: true)
            }
        }
    }

    private func placeholderName(_ type: AssetType?) -> String {
        switch type?.id {
        case Defaults.TypeID.car: return "es. Golf 8"
        case Defaults.TypeID.tyres: return "es. Gomme invernali"
        case Defaults.TypeID.ski: return "es. Sci da pista"
        case Defaults.TypeID.bike: return "es. Bici da corsa"
        default: return "Nome"
        }
    }

    private func save() {
        guard let type = store.data.assetType(typeID) else { return }
        var asset = original ?? Asset(typeID: typeID, name: "", createdOn: createdOn)
        asset.typeID = typeID
        asset.name = name.trimmingCharacters(in: .whitespaces)
        asset.icon = icon == type.icon ? nil : icon
        asset.color = color?.lowercased() == type.color.lowercased() ? nil : color
        asset.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        asset.initialMeter = Fmt.parseNumber(initialMeter) ?? 0
        asset.attributes = attributes.filter { key, value in
            type.fields.contains { $0.id == key } && !value.trimmingCharacters(in: .whitespaces).isEmpty
        }
        asset.createdOn = createdOn
        let host = mountOn
        let day = createdOn
        let saved = asset
        store.update { data in
            data.saveAsset(saved)
            if let host { data.mount(componentID: saved.id, on: host, date: day) }
        }
        store.celebrate()
        store.showToast(original == nil ? "\(saved.name) aggiunto" : "Modifiche salvate")
        dismiss()
    }
}
