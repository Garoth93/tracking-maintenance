import SwiftUI
import Charts
import UpkeepCore

enum DetailSheet: Identifiable {
    case edit
    case newOperation(typeID: String?)
    case editOperation(OperationRecord)
    case meter
    case mount
    case unmount
    case mounting(Mounting)

    var id: String {
        switch self {
        case .edit: return "edit"
        case .newOperation(let t): return "new-" + (t ?? "")
        case .editOperation(let o): return "op-" + o.id
        case .meter: return "meter"
        case .mount: return "mount"
        case .unmount: return "unmount"
        case .mounting(let m): return "mo-" + m.id
        }
    }
}

struct AssetDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let assetID: String
    @State private var sheet: DetailSheet?
    @State private var confirmDelete = false
    @State private var showReadings = true

    var body: some View {
        if let asset = store.data.asset(assetID) {
            content(asset)
        } else {
            EmptyStateView(icon: "trash", title: "Oggetto eliminato", message: "Questo oggetto non esiste più.")
                .m3Screen(m3)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ asset: Asset) -> some View {
        let data = store.data
        let type = data.type(of: asset)
        let tones = m3.tones(data.color(of: asset))
        let isComponent = data.isComponent(asset)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero(asset, type: type, tones: tones)
                actions(asset, isComponent: isComponent)
                deadlinesSection(asset)
                if isComponent {
                    hostSection(asset)
                } else {
                    componentsSection(asset)
                }
                detailsSection(asset, type: type)
                expensesSection(asset)
                historySection(asset)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .m3Screen(m3)
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { sheet = .edit } label: { Label("Modifica", systemImage: "pencil") }
                    Button {
                        let archived = !asset.archived
                        store.updateUndoable(archived ? "\(asset.name) archiviato" : "\(asset.name) ripristinato") {
                            $0.setArchived(archived, assetID: asset.id, today: store.today)
                        }
                    } label: {
                        Label(asset.archived ? "Ripristina" : "Archivia", systemImage: asset.archived ? "tray.and.arrow.up" : "archivebox")
                    }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FAB(icon: "plus", label: "Registra") { sheet = .newOperation(typeID: nil) }
                .padding(16)
        }
        .sheet(item: $sheet) { s in sheetView(s, asset: asset) }
        .confirmationDialog("Eliminare “\(asset.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina con tutto lo storico", role: .destructive) {
                dismiss()
                store.updateUndoable("\(asset.name) eliminato") { $0.deleteAsset(id: asset.id) }
            }
        } message: {
            Text("Verranno eliminate anche operazioni, letture e montaggi. In alternativa puoi archiviarlo.")
        }
    }

    @ViewBuilder
    private func sheetView(_ s: DetailSheet, asset: Asset) -> some View {
        switch s {
        case .edit:
            AssetFormView(original: asset, presetTypeID: nil)
        case .newOperation(let typeID):
            OperationFormView(assetID: asset.id, original: nil, presetTypeID: typeID)
        case .editOperation(let op):
            OperationFormView(assetID: asset.id, original: op, presetTypeID: nil)
        case .meter:
            MeterSheet(assetID: asset.id)
        case .mount:
            MountSheet(assetID: asset.id)
        case .unmount:
            UnmountSheet(componentID: asset.id)
        case .mounting(let m):
            MountingEditSheet(mounting: m)
        }
    }

    // MARK: - Hero

    private func hero(_ asset: Asset, type: AssetType?, tones: Tones) -> some View {
        let data = store.data
        let unit = data.unit(of: asset.id)
        return VStack(spacing: 14) {
            IconBadge(icon: data.icon(of: asset), tones: tones, size: 96, cookie: true)
                .padding(.top, 6)
            VStack(spacing: 4) {
                Text(asset.name)
                    .font(.m3HeadlineMedium)
                    .foregroundStyle(m3.onSurface)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    Text(type?.name ?? "Oggetto")
                    if asset.archived { Text("· archiviato") }
                }
                .font(.m3LabelLarge)
                .foregroundStyle(tones.accent)
            }
            if !unit.isEmpty {
                VStack(spacing: 2) {
                    Text(Fmt.number(data.meter(of: asset.id), decimals: 1))
                        .font(.m3DisplaySmall.monospacedDigit())
                        .foregroundStyle(m3.onSurface)
                        .contentTransition(.numericText())
                    Text(meterCaption(asset, unit: unit))
                        .font(.m3BodySmall)
                        .foregroundStyle(m3.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(m3.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func meterCaption(_ asset: Asset, unit: String) -> String {
        let data = store.data
        var parts = [unit]
        if data.isComponent(asset) {
            parts.append("calcolati dai montaggi")
        } else if let rate = data.dailyRate(of: asset.id) {
            parts.append("media \(Fmt.meter(rate * 30.44, unit: unit))/mese")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func actions(_ asset: Asset, isComponent: Bool) -> some View {
        let data = store.data
        let hasUnit = !data.unit(of: asset.id).isEmpty
        let mounted = data.activeMounting(ofComponent: asset.id) != nil
        let canMount = isComponent || !data.mountCandidates(for: asset).isEmpty
        return HStack(spacing: 10) {
            if hasUnit && !isComponent {
                actionButton("Aggiorna", icon: "gauge.with.dots.needle.67percent") { sheet = .meter }
            }
            if isComponent {
                if mounted {
                    actionButton("Smonta", icon: "arrow.down.circle") { sheet = .unmount }
                }
                actionButton(mounted ? "Sposta" : "Monta", icon: "arrow.up.circle") { sheet = .mount }
            } else if canMount {
                actionButton("Monta", icon: "circle.circle") { sheet = .mount }
            }
            actionButton("Operazione", icon: "wrench.and.screwdriver") { sheet = .newOperation(typeID: nil) }
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.m3LabelMedium).lineLimit(1)
            }
            .foregroundStyle(m3.onSecondaryContainer)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(m3.secondaryContainer, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Deadlines

    @ViewBuilder
    private func deadlinesSection(_ asset: Asset) -> some View {
        let list = store.data.deadlines(today: store.today, assetID: asset.id)
        if !list.isEmpty {
            SectionTitle(title: "Scadenze")
            VStack(spacing: 10) {
                ForEach(list) { d in
                    DeadlineCard(deadline: d, showAsset: false) {
                        sheet = .newOperation(typeID: d.typeID)
                    }
                }
            }
        }
    }

    // MARK: - Mounting

    @ViewBuilder
    private func componentsSection(_ asset: Asset) -> some View {
        let data = store.data
        let history = data.mountings(onHost: asset.id)
        let active = history.filter(\.isActive)
        if !history.isEmpty || !data.mountCandidates(for: asset).isEmpty {
            SectionTitle(title: "Componenti montati", trailing: "Monta") { sheet = .mount }
            if active.isEmpty {
                M3Card {
                    Text("Nessun componente montato. Monta ad esempio un treno di gomme: accumulerà i km dell'auto finché resta montato.")
                        .font(.m3BodyMedium)
                        .foregroundStyle(m3.onSurfaceVariant)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(active) { m in
                        if let c = data.asset(m.componentID) {
                            mountedRow(component: c, mounting: m)
                        }
                    }
                }
            }
        }
    }

    private func mountedRow(component c: Asset, mounting m: Mounting) -> some View {
        let data = store.data
        let unit = data.unit(of: c.id)
        return NavigationLink(value: Route.asset(c.id)) {
            M3Card {
                HStack(spacing: 14) {
                    IconBadge(icon: data.icon(of: c), tones: m3.tones(data.color(of: c)), size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                        Text("dal \(Fmt.date(m.startDate)) · +\(Fmt.meter(data.distance(of: m), unit: unit)) con questo")
                            .font(.m3BodySmall)
                            .foregroundStyle(m3.onSurfaceVariant)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fmt.number(data.meter(of: c.id), decimals: 0)).font(.m3TitleMedium.monospacedDigit())
                        Text(unit).font(.m3LabelSmall)
                    }
                    .foregroundStyle(m3.onSurface)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private func hostSection(_ asset: Asset) -> some View {
        let data = store.data
        let current = data.activeMounting(ofComponent: asset.id)
        SectionTitle(title: "Montaggio")
        M3Card {
            if let m = current, let host = data.asset(m.hostID) {
                NavigationLink(value: Route.asset(host.id)) {
                    HStack(spacing: 14) {
                        IconBadge(icon: data.icon(of: host), tones: m3.tones(data.color(of: host)), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Montato su \(host.name)").font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                            Text("dal \(Fmt.date(m.startDate)) a \(Fmt.meter(m.startHostMeter, unit: data.unit(of: host.id))) · +\(Fmt.meter(data.distance(of: m), unit: data.unit(of: asset.id)))")
                                .font(.m3BodySmall)
                                .foregroundStyle(m3.onSurfaceVariant)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(m3.onSurfaceVariant)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 20))
                        .foregroundStyle(m3.onSurfaceVariant)
                        .frame(width: 44, height: 44)
                        .background(m3.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smontato").font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                        Text("In deposito: i km non aumentano.").font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                    }
                    Spacer()
                    Button("Monta") { sheet = .mount }.buttonStyle(.m3TonalSmall)
                }
            }
        }
    }

    // MARK: - Details

    @ViewBuilder
    private func detailsSection(_ asset: Asset, type: AssetType?) -> some View {
        let fields = (type?.fields ?? []).compactMap { f -> (String, String)? in
            guard let v = asset.attributes[f.id], !v.isEmpty else { return nil }
            return (f.name, v)
        }
        let unit = store.data.unit(of: asset.id)
        SectionTitle(title: "Dettagli", trailing: "Modifica") { sheet = .edit }
        M3Card {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, pair in
                    infoRow(pair.0, pair.1)
                }
                infoRow("Aggiunto il", Fmt.date(asset.createdOn))
                if !unit.isEmpty {
                    infoRow("Valore iniziale", Fmt.meter(asset.initialMeter, unit: unit))
                }
                if !asset.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note").font(.m3LabelMedium).foregroundStyle(m3.onSurfaceVariant)
                        Text(asset.notes).font(.m3BodyMedium).foregroundStyle(m3.onSurface)
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.m3BodyMedium).foregroundStyle(m3.onSurfaceVariant)
            Spacer(minLength: 12)
            Text(value).font(.m3BodyMedium.weight(.medium)).foregroundStyle(m3.onSurface).multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Expenses

    @ViewBuilder
    private func expensesSection(_ asset: Asset) -> some View {
        let data = store.data
        let report = data.expenseReport(year: nil, assetID: asset.id)
        if report.total > 0 {
            let symbol = data.settings.currencySymbol
            let thisYear = report.byYear.first { $0.year == store.today.year }?.total ?? 0
            SectionTitle(title: "Spese")
            M3Card(color: m3.primaryContainer) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        metric("Totale", Fmt.moneyShort(report.total, symbol: symbol))
                        metric("Quest'anno", Fmt.moneyShort(thisYear, symbol: symbol))
                        if let cpu = data.costPerUnit(of: asset.id) {
                            metric("Per \(data.unit(of: asset.id))", Fmt.number(cpu, decimals: 2, fixed: true) + " " + symbol)
                        }
                    }
                    if report.byYear.count > 1 {
                        Chart(report.byYear) { y in
                            BarMark(x: .value("Anno", String(y.year)), y: .value("Spesa", y.total), width: .ratio(0.55))
                                .foregroundStyle(m3.primary)
                                .cornerRadius(6)
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { _ in AxisValueLabel().foregroundStyle(m3.onPrimaryContainer) }
                        }
                        .frame(height: 110)
                    }
                    ForEach(report.byType.prefix(4)) { s in
                        HStack {
                            Image(systemName: s.icon).frame(width: 20)
                            Text(s.name)
                            Spacer()
                            Text(Fmt.moneyShort(s.total, symbol: symbol)).monospacedDigit()
                        }
                        .font(.m3BodyMedium)
                        .foregroundStyle(m3.onPrimaryContainer)
                    }
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.m3LabelMedium).opacity(0.8)
            Text(value).font(.m3TitleLarge.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(m3.onPrimaryContainer)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - History

    @ViewBuilder
    private func historySection(_ asset: Asset) -> some View {
        let data = store.data
        let years = data.timelineByYear(of: asset.id, includeReadings: showReadings)
        HStack {
            SectionTitle(title: "Storico")
            if !data.readings(of: asset.id).isEmpty {
                FilterChip(label: "Letture km", selected: showReadings) {
                    withAnimation(.snappy) { showReadings.toggle() }
                }
                .padding(.top, 8)
            }
        }
        if years.isEmpty {
            M3Card {
                Text("Nessuna operazione registrata. Tocca “Registra” per aggiungere tagliandi, cambi, rinnovi…")
                    .font(.m3BodyMedium)
                    .foregroundStyle(m3.onSurfaceVariant)
            }
        } else {
            ForEach(years) { y in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(String(y.year)).font(.m3TitleSmall).foregroundStyle(m3.primary)
                        Spacer()
                        if y.cost > 0 {
                            Text(Fmt.money(y.cost, symbol: data.settings.currencySymbol))
                                .font(.m3LabelLarge.monospacedDigit())
                                .foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                    ForEach(Array(y.events.enumerated()), id: \.element.id) { index, e in
                        TimelineRow(event: e, assetID: asset.id, isLast: index == y.events.count - 1) {
                            open(e)
                        }
                    }
                }
                .padding(.bottom, 8)
                .background(m3.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private func open(_ e: TimelineEvent) {
        switch e {
        case .operation(let o): sheet = .editOperation(o)
        case .reading: sheet = .meter
        case .mounted(let m, _), .unmounted(let m, _): sheet = .mounting(m)
        }
    }
}

/// One history row with a timeline dot.
struct TimelineRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    let event: TimelineEvent
    let assetID: String
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        let info = describe()
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Image(systemName: info.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(info.tones.onContainer)
                        .frame(width: 34, height: 34)
                        .background(info.tones.container, in: Circle())
                    if !isLast {
                        Rectangle().fill(m3.outlineVariant).frame(width: 2).frame(maxHeight: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(info.title).font(.m3TitleSmall).foregroundStyle(m3.onSurface)
                        Spacer(minLength: 8)
                        if let cost = info.cost {
                            Text(Fmt.money(cost, symbol: store.data.settings.currencySymbol))
                                .font(.m3LabelLarge.monospacedDigit())
                                .foregroundStyle(m3.onSurface)
                        }
                    }
                    Text(info.subtitle)
                        .font(.m3BodySmall)
                        .foregroundStyle(m3.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                    if let notes = info.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.m3BodySmall)
                            .foregroundStyle(m3.onSurfaceVariant)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.bottom, isLast ? 4 : 14)
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct Info {
        let icon: String
        let tones: Tones
        let title: String
        let subtitle: String
        var cost: Double?
        var notes: String?
    }

    private func describe() -> Info {
        let data = store.data
        let unit = data.unit(of: assetID)
        switch event {
        case .operation(let o):
            let t = data.operationType(o.typeID)
            var sub = [Fmt.date(o.date)]
            if let m = o.meter { sub.append(Fmt.meter(m, unit: unit)) }
            if let due = o.dueDate { sub.append("scad. \(Fmt.date(due))") }
            var extra: [String] = []
            for f in t?.fields ?? [] {
                if let v = o.attributes[f.id], !v.isEmpty { extra.append("\(f.name): \(v)") }
            }
            if !o.notes.isEmpty { extra.append(o.notes) }
            return Info(
                icon: t?.icon ?? "wrench.fill",
                tones: m3.tones(t?.color ?? Palette.defaultAccent),
                title: t?.name ?? "Operazione",
                subtitle: sub.joined(separator: " · "),
                cost: o.cost,
                notes: extra.joined(separator: " · ")
            )
        case .reading(let r):
            return Info(
                icon: "gauge.with.dots.needle.50percent",
                tones: Tones(accent: m3.onSurfaceVariant, container: m3.surfaceContainerHighest, onContainer: m3.onSurfaceVariant),
                title: "Lettura \(Fmt.meter(r.value, unit: unit))",
                subtitle: Fmt.date(r.date),
                notes: r.note
            )
        case .mounted(let m, let other):
            let name = data.asset(other)?.name ?? "?"
            let isHost = m.hostID == assetID
            return Info(
                icon: "arrow.up.circle.fill",
                tones: Tones(accent: m3.tertiary, container: m3.tertiaryContainer, onContainer: m3.onTertiaryContainer),
                title: isHost ? "Montato: \(name)" : "Montato su \(name)",
                subtitle: "\(Fmt.date(m.startDate)) · \(Fmt.meter(m.startHostMeter, unit: data.unit(of: m.hostID)))"
            )
        case .unmounted(let m, let other):
            let name = data.asset(other)?.name ?? "?"
            let isHost = m.hostID == assetID
            return Info(
                icon: "arrow.down.circle.fill",
                tones: Tones(accent: m3.onSurfaceVariant, container: m3.surfaceContainerHighest, onContainer: m3.onSurfaceVariant),
                title: isHost ? "Smontato: \(name)" : "Smontato da \(name)",
                subtitle: "\(Fmt.date(m.endDate ?? m.startDate)) · \(Fmt.meter(m.endHostMeter ?? 0, unit: data.unit(of: m.hostID))) · \(Fmt.meter(data.distance(of: m), unit: data.unit(of: m.componentID))) percorsi"
            )
        }
    }
}
