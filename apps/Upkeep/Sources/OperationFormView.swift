import SwiftUI
import UpkeepCore

struct OperationFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss

    let assetID: String
    let original: OperationRecord?
    @State private var typeID: String?
    @State private var date: DayDate
    @State private var meter: String
    @State private var cost: String
    @State private var notes: String
    @State private var attributes: [String: String]
    @State private var manualDue: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: DayDate
    @State private var dueMeter: String
    @State private var noFollowUp: Bool
    @State private var confirmDelete = false
    @State private var didPrefill = false

    init(assetID: String, original: OperationRecord?, presetTypeID: String?) {
        self.assetID = assetID
        self.original = original
        let o = original
        _typeID = State(initialValue: o?.typeID ?? presetTypeID)
        _date = State(initialValue: o?.date ?? .today())
        _meter = State(initialValue: Fmt.editable(o?.meter, decimals: 1))
        _cost = State(initialValue: Fmt.editable(o?.cost, decimals: 2))
        _notes = State(initialValue: o?.notes ?? "")
        _attributes = State(initialValue: o?.attributes ?? [:])
        _manualDue = State(initialValue: o?.dueDate != nil || o?.dueMeter != nil)
        _hasDueDate = State(initialValue: o?.dueDate != nil)
        _dueDate = State(initialValue: o?.dueDate ?? DayDate.today().adding(months: 12))
        _dueMeter = State(initialValue: Fmt.editable(o?.dueMeter, decimals: 1))
        _noFollowUp = State(initialValue: o?.noFollowUp ?? false)
        _didPrefill = State(initialValue: o != nil)
    }

    var body: some View {
        let data = store.data
        let asset = data.asset(assetID)
        let unit = data.unit(of: assetID)
        let types = availableTypes(data, asset: asset)
        let type = typeID.flatMap { data.operationType($0) }
        let numbersValid = isValid(meter) && isValid(cost) && isValid(dueMeter)
        let canSave = type != nil && numbersValid

        SheetScaffold(original == nil ? "Registra operazione" : "Modifica operazione", canSave: canSave, onSave: save) {
            if let asset {
                HStack(spacing: 12) {
                    IconBadge(icon: data.icon(of: asset), tones: m3.tones(data.color(of: asset)), size: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(asset.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                        if !unit.isEmpty {
                            Text("Attuale: \(Fmt.meter(data.meter(of: assetID), unit: unit))")
                                .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                }
            }

            FormSection("Operazione") {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(types) { t in
                        FilterChip(label: t.name, icon: t.icon, selected: t.id == typeID) {
                            withAnimation(.snappy) { typeID = t.id }
                        }
                    }
                }
                if let type, !type.interval.isEmpty {
                    Label(Fmt.interval(type.interval, unit: unit).capitalized(firstOnly: true), systemImage: "repeat")
                        .font(.m3BodySmall)
                        .foregroundStyle(m3.onSurfaceVariant)
                        .padding(.horizontal, 4)
                }
            }

            FormSection("Dati") {
                M3DateField(label: "Data", day: $date)
                if !unit.isEmpty {
                    M3TextField(label: "Contatore", text: $meter, icon: "gauge.with.dots.needle.33percent",
                                placeholder: Fmt.editable(data.meter(of: assetID), decimals: 1), suffix: unit, keyboard: .decimalPad)
                }
                M3TextField(label: "Costo", text: $cost, icon: "eurosign", placeholder: "0,00",
                            suffix: data.settings.currencySymbol, keyboard: .decimalPad)
                if let type {
                    ForEach(type.fields) { f in
                        AttributeField(field: f, values: $attributes)
                    }
                }
                M3TextField(label: "Note", text: $notes, icon: "note.text", placeholder: "Facoltative", multiline: true)
            }

            if type != nil {
                dueSection(unit: unit)
            }

            if original != nil {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Elimina operazione", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.m3Danger)
                .padding(.top, 6)
            }
        }
        .onAppear(perform: prefill)
        .confirmationDialog("Eliminare questa operazione?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let id = original?.id {
                    dismiss()
                    store.updateUndoable("Operazione eliminata") { $0.deleteOperation(id: id) }
                }
            }
        }
    }

    // MARK: - Next deadline

    @ViewBuilder
    private func dueSection(unit: String) -> some View {
        let preview = previewDeadline()
        FormSection("Prossima scadenza", footer: noFollowUp ? "Questa operazione chiude la ricorrenza: non verranno create scadenze." : nil) {
            FormCard {
                if !noFollowUp {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: preview == nil ? "calendar.badge.minus" : "calendar.badge.clock")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(m3.primary)
                        VStack(alignment: .leading, spacing: 3) {
                            if let p = preview {
                                if let due = p.dueDate {
                                    Text(Fmt.longDate(due)).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                                }
                                if let dm = p.dueMeter {
                                    Text((p.dueDate == nil ? "" : "oppure ") + "a \(Fmt.meter(dm, unit: unit))")
                                        .font(p.dueDate == nil ? .m3TitleSmall : .m3BodyMedium)
                                        .foregroundStyle(p.dueDate == nil ? m3.onSurface : m3.onSurfaceVariant)
                                }
                                Text(manualDue ? "Impostata manualmente" : "Calcolata dall'intervallo del tipo")
                                    .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                            } else {
                                Text("Nessuna scadenza").font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                                Text(unit.isEmpty || !meter.isEmpty ? "Il tipo non ha un intervallo: imposta una data se serve." : "Inserisci il contatore o imposta una scadenza.")
                                    .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                            }
                        }
                    }
                    Toggle("Imposta scadenza manuale", isOn: $manualDue.animation(.snappy))
                        .toggleStyle(.m3)
                        .font(.m3BodyLarge)
                    if manualDue {
                        Toggle("Data di scadenza", isOn: $hasDueDate.animation(.snappy))
                            .toggleStyle(.m3)
                            .font(.m3BodyMedium)
                        if hasDueDate {
                            M3DateField(label: "Scade il", day: $dueDate, icon: "calendar.badge.exclamationmark")
                        }
                        if !unit.isEmpty {
                            M3TextField(label: "Scade a", text: $dueMeter, icon: "flag.checkered", placeholder: "facoltativo",
                                        suffix: unit, keyboard: .decimalPad)
                        }
                    }
                }
                Toggle("Nessuna scadenza successiva", isOn: $noFollowUp.animation(.snappy))
                    .toggleStyle(.m3)
                    .font(.m3BodyMedium)
            }
        }
    }

    private func previewDeadline() -> Deadline? {
        guard let op = buildOperation() else { return nil }
        var copy = store.data
        copy.saveOperation(op)
        return copy.deadline(for: op, today: store.today)
    }

    // MARK: - Helpers

    private func availableTypes(_ data: AppData, asset: Asset?) -> [OperationType] {
        guard let asset else { return data.operationTypes }
        var list = data.operationTypes(for: asset)
        if let current = typeID, !list.contains(where: { $0.id == current }), let t = data.operationType(current) {
            list.insert(t, at: 0)
        }
        return list
    }

    private func isValid(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.parseNumber(text) != nil
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        let data = store.data
        if !data.unit(of: assetID).isEmpty, meter.isEmpty {
            meter = Fmt.editable(data.meter(of: assetID), decimals: 1)
        }
        if typeID == nil, let asset = data.asset(assetID), let first = data.operationTypes(for: asset).first {
            typeID = first.id
        }
    }

    private func buildOperation() -> OperationRecord? {
        guard let typeID else { return nil }
        let opType = store.data.operationType(typeID)
        var op = original ?? OperationRecord(assetID: assetID, typeID: typeID, date: date)
        op.typeID = typeID
        op.date = date
        op.meter = Fmt.parseNumber(meter)
        op.cost = Fmt.parseNumber(cost)
        op.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        op.attributes = attributes.filter { key, value in
            (opType?.fields.contains { $0.id == key } ?? false) && !value.trimmingCharacters(in: .whitespaces).isEmpty
        }
        op.noFollowUp = noFollowUp
        if manualDue && !noFollowUp {
            op.dueDate = hasDueDate ? dueDate : nil
            op.dueMeter = Fmt.parseNumber(dueMeter)
        } else {
            op.dueDate = nil
            op.dueMeter = nil
        }
        return op
    }

    private func save() {
        guard let op = buildOperation() else { return }
        let name = store.data.operationType(op.typeID)?.name ?? "Operazione"
        store.update { $0.saveOperation(op) }
        store.celebrate()
        store.showToast(original == nil ? "\(name) registrato" : "Operazione aggiornata")
        dismiss()
    }
}

extension String {
    /// Uppercases only the first character.
    func capitalized(firstOnly: Bool) -> String {
        guard firstOnly, let head = self.first else { return capitalized }
        return head.uppercased() + dropFirst()
    }
}
