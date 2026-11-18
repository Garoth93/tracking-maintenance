import SwiftUI
import UpkeepCore

// MARK: - Counter update

struct MeterSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let assetID: String
    @State private var value = ""
    @State private var date: DayDate = .today()
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        let data = store.data
        let unit = data.unit(of: assetID)
        let current = data.meter(of: assetID)
        let parsed = Fmt.parseNumber(value)
        let readings = data.readings(of: assetID)

        SheetScaffold("Aggiorna \(unit)", canSave: parsed != nil, onSave: save) {
            VStack(spacing: 6) {
                Text("Valore attuale").font(.m3LabelMedium).foregroundStyle(m3.onSurfaceVariant)
                Text(Fmt.meter(current, unit: unit)).font(.m3TitleLarge.monospacedDigit()).foregroundStyle(m3.onSurface)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                TextField(Fmt.editable(current, decimals: 0), text: $value)
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .foregroundStyle(m3.onPrimaryContainer)
                Text(unit).font(.m3LabelLarge).foregroundStyle(m3.onPrimaryContainer.opacity(0.8))
                if let p = parsed {
                    let delta = p - current
                    Text(delta >= 0 ? "+\(Fmt.meter(delta, unit: unit)) dall'ultimo valore" : "Inferiore al valore attuale: non cambierà il contatore")
                        .font(.m3BodySmall)
                        .foregroundStyle(delta >= 0 ? m3.onPrimaryContainer : m3.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(m3.primaryContainer, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            M3DateField(label: "Data", day: $date)
            M3TextField(label: "Nota", text: $note, icon: "note.text", placeholder: "Facoltativa")

            if !readings.isEmpty {
                FormSection("Letture registrate") {
                    VStack(spacing: 0) {
                        ForEach(readings.prefix(30)) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(Fmt.meter(r.value, unit: unit)).font(.m3BodyLarge.monospacedDigit()).foregroundStyle(m3.onSurface)
                                    Text(Fmt.date(r.date) + (r.note.isEmpty ? "" : " · " + r.note))
                                        .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                                }
                                Spacer()
                                Button {
                                    let id = r.id
                                    store.updateUndoable("Lettura eliminata") { $0.deleteReading(id: id) }
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(m3.error)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Elimina lettura")
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            if r.id != readings.prefix(30).last?.id {
                                Divider().overlay(m3.outlineVariant).padding(.leading, 16)
                            }
                        }
                    }
                    .background(m3.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        guard let v = Fmt.parseNumber(value) else { return }
        let unit = store.data.unit(of: assetID)
        let d = date, n = note.trimmingCharacters(in: .whitespaces)
        store.update { $0.addReading(assetID: assetID, date: d, value: v, note: n) }
        store.celebrate()
        store.showToast("Contatore aggiornato: \(Fmt.meter(v, unit: unit))")
        dismiss()
    }
}

// MARK: - Mount

/// Mounts a component on a host. Opened from either side.
struct MountSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let assetID: String
    @State private var otherID: String?
    @State private var date: DayDate = .today()
    @State private var hostMeter = ""
    @State private var replace = true

    var body: some View {
        let data = store.data
        let asset = data.asset(assetID)
        let fromComponent = asset.map { data.isComponent($0) } ?? false
        let options: [Asset] = {
            guard let asset else { return [] }
            if fromComponent {
                let current = data.activeMounting(ofComponent: assetID)?.hostID
                return data.sortedAssets().filter { !data.isComponent($0) && $0.id != current }
            }
            return data.mountCandidates(for: asset)
        }()
        let hostID = fromComponent ? otherID : assetID
        let unit = hostID.map { data.unit(of: $0) } ?? ""

        SheetScaffold(fromComponent ? "Monta su…" : "Monta componente", saveTitle: "Monta", canSave: otherID != nil && valid, onSave: save) {
            FormSection(fromComponent ? "Oggetto" : "Componente") {
                if options.isEmpty {
                    Text(fromComponent
                         ? "Non ci sono oggetti su cui montarlo. Aggiungi prima l'auto o la bici."
                         : "Nessun componente disponibile. Crea un oggetto di un tipo “componente” (es. Pneumatici).")
                        .font(.m3BodyMedium)
                        .foregroundStyle(m3.onSurfaceVariant)
                } else {
                    VStack(spacing: 8) {
                        ForEach(options) { o in
                            optionRow(o, selected: o.id == otherID)
                        }
                    }
                }
            }

            FormSection("Quando") {
                M3DateField(label: "Data di montaggio", day: $date)
                if !unit.isEmpty {
                    M3TextField(label: "Contatore dell'oggetto al montaggio", text: $hostMeter,
                                icon: "gauge.with.dots.needle.33percent", suffix: unit, keyboard: .decimalPad)
                }
            }

            FormCard {
                Toggle(isOn: $replace) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sostituisci quelli dello stesso tipo").font(.m3BodyLarge)
                        Text("Es. montando le invernali vengono smontate le estive.")
                            .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                    }
                }
                .toggleStyle(.m3)
            }
        }
        .onAppear {
            if !fromComponent { hostMeter = Fmt.editable(data.meter(of: assetID), decimals: 1) }
            if otherID == nil, options.count == 1 { select(options[0], fromComponent: fromComponent) }
        }
    }

    private var valid: Bool {
        hostMeter.trimmingCharacters(in: .whitespaces).isEmpty || Fmt.parseNumber(hostMeter) != nil
    }

    private func optionRow(_ o: Asset, selected: Bool) -> some View {
        let data = store.data
        let fromComponent = data.asset(assetID).map { data.isComponent($0) } ?? false
        let where_: String = {
            if let m = data.activeMounting(ofComponent: o.id), let h = data.asset(m.hostID) { return "ora su \(h.name)" }
            if data.isComponent(o) { return "smontato" }
            let unit = data.unit(of: o.id)
            return unit.isEmpty ? (data.type(of: o)?.name ?? "") : Fmt.meter(data.meter(of: o.id), unit: unit)
        }()
        return Button {
            select(o, fromComponent: fromComponent)
        } label: {
            HStack(spacing: 12) {
                IconBadge(icon: data.icon(of: o), tones: m3.tones(data.color(of: o)), size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(o.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                    Text(where_).font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? m3.primary : m3.outline)
            }
            .padding(12)
            .background(selected ? m3.secondaryContainer : m3.surfaceContainerHighest,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func select(_ o: Asset, fromComponent: Bool) {
        otherID = o.id
        if fromComponent { hostMeter = Fmt.editable(store.data.meter(of: o.id), decimals: 1) }
    }

    private func save() {
        guard let otherID else { return }
        let data = store.data
        let fromComponent = data.asset(assetID).map { data.isComponent($0) } ?? false
        let componentID = fromComponent ? assetID : otherID
        let hostID = fromComponent ? otherID : assetID
        let meter = Fmt.parseNumber(hostMeter)
        let day = date, rep = replace
        let cName = data.asset(componentID)?.name ?? ""
        let hName = data.asset(hostID)?.name ?? ""
        store.updateUndoable("\(cName) montato su \(hName)") {
            $0.mount(componentID: componentID, on: hostID, date: day, hostMeter: meter, replaceSameType: rep)
        }
        dismiss()
    }
}

struct UnmountSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let componentID: String
    @State private var date: DayDate = .today()
    @State private var hostMeter = ""

    var body: some View {
        let data = store.data
        let mounting = data.activeMounting(ofComponent: componentID)
        let host = mounting.flatMap { data.asset($0.hostID) }
        let unit = host.map { data.unit(of: $0.id) } ?? ""

        SheetScaffold("Smonta", saveTitle: "Smonta", canSave: mounting != nil, onSave: save) {
            if let host, let mounting {
                M3Card(color: m3.surfaceContainerHighest) {
                    Text("Montato su \(host.name) dal \(Fmt.date(mounting.startDate)) a \(Fmt.meter(mounting.startHostMeter, unit: unit)).")
                        .font(.m3BodyMedium)
                        .foregroundStyle(m3.onSurface)
                }
            }
            M3DateField(label: "Data di smontaggio", day: $date)
            if !unit.isEmpty {
                M3TextField(label: "Contatore di \(host?.name ?? "") allo smontaggio", text: $hostMeter,
                            icon: "gauge.with.dots.needle.33percent", suffix: unit, keyboard: .decimalPad)
            }
        }
        .onAppear {
            if let h = host { hostMeter = Fmt.editable(data.meter(of: h.id), decimals: 1) }
        }
    }

    private func save() {
        let meter = Fmt.parseNumber(hostMeter)
        let day = date
        let name = store.data.asset(componentID)?.name ?? ""
        store.updateUndoable("\(name) smontato") { $0.unmount(componentID: componentID, date: day, hostMeter: meter) }
        dismiss()
    }
}

/// Edits or deletes a mount period from the history.
struct MountingEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let mounting: Mounting
    @State private var startDate: DayDate
    @State private var startMeter: String
    @State private var ended: Bool
    @State private var endDate: DayDate
    @State private var endMeter: String
    @State private var confirmDelete = false

    init(mounting: Mounting) {
        self.mounting = mounting
        _startDate = State(initialValue: mounting.startDate)
        _startMeter = State(initialValue: Fmt.editable(mounting.startHostMeter, decimals: 1))
        _ended = State(initialValue: !mounting.isActive)
        _endDate = State(initialValue: mounting.endDate ?? .today())
        _endMeter = State(initialValue: Fmt.editable(mounting.endHostMeter, decimals: 1))
    }

    var body: some View {
        let data = store.data
        let unit = data.unit(of: mounting.hostID)
        let c = data.asset(mounting.componentID)?.name ?? "?"
        let h = data.asset(mounting.hostID)?.name ?? "?"
        let valid = Fmt.parseNumber(startMeter) != nil && (!ended || Fmt.parseNumber(endMeter) != nil)

        SheetScaffold("Montaggio", canSave: valid, onSave: save) {
            Text("\(c) su \(h)").font(.m3TitleMedium).foregroundStyle(m3.onSurface)
            FormSection("Montato") {
                M3DateField(label: "Data", day: $startDate)
                M3TextField(label: "Contatore di \(h)", text: $startMeter, icon: "gauge.with.dots.needle.33percent",
                            suffix: unit, keyboard: .decimalPad)
            }
            FormCard {
                Toggle("Smontato", isOn: $ended.animation(.snappy)).toggleStyle(.m3).font(.m3BodyLarge)
            }
            if ended {
                FormSection("Smontato") {
                    M3DateField(label: "Data", day: $endDate)
                    M3TextField(label: "Contatore di \(h)", text: $endMeter, icon: "gauge.with.dots.needle.67percent",
                                suffix: unit, keyboard: .decimalPad)
                }
            }
            Button {
                confirmDelete = true
            } label: {
                Label("Elimina dallo storico", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.m3Danger)
        }
        .onAppear {
            if ended && endMeter.isEmpty { endMeter = Fmt.editable(data.meter(of: mounting.hostID), decimals: 1) }
        }
        .onChange(of: ended) { _, now in
            if now && endMeter.isEmpty { endMeter = Fmt.editable(store.data.meter(of: mounting.hostID), decimals: 1) }
        }
        .confirmationDialog("Eliminare questo montaggio?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                let id = mounting.id
                dismiss()
                store.updateUndoable("Montaggio eliminato") { $0.deleteMounting(id: id) }
            }
        } message: {
            Text("I km percorsi in questo periodo non verranno più conteggiati sul componente.")
        }
    }

    private func save() {
        var m = mounting
        m.startDate = startDate
        m.startHostMeter = Fmt.parseNumber(startMeter) ?? m.startHostMeter
        if ended {
            m.endDate = max(endDate, startDate)
            m.endHostMeter = max(Fmt.parseNumber(endMeter) ?? m.startHostMeter, m.startHostMeter)
        } else {
            m.endDate = nil
            m.endHostMeter = nil
        }
        let saved = m
        store.update { data in
            // Only one active mount per component.
            if saved.isActive {
                for i in data.mountings.indices {
                    let other = data.mountings[i]
                    guard other.componentID == saved.componentID, other.isActive, other.id != saved.id else { continue }
                    data.mountings[i].endDate = max(saved.startDate, other.startDate)
                    data.mountings[i].endHostMeter = max(saved.startHostMeter, other.startHostMeter)
                }
            }
            data.saveMounting(saved)
        }
        store.showToast("Montaggio aggiornato")
        dismiss()
    }
}
