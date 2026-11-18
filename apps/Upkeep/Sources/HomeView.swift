import SwiftUI
import UpkeepCore

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var typeFilter: String?
    @State private var query = ""
    @State private var showArchived = false
    @State private var showNew = false
    @State private var confirmDemo = false

    var body: some View {
        let data = store.data
        let all = data.sortedAssets(includeArchived: true)
        let visible = all.filter { a in
            (showArchived ? a.archived : !a.archived)
                && (typeFilter == nil || a.typeID == typeFilter)
                && (Fmt.matches(a.name, query: query) || a.attributes.values.contains { Fmt.matches($0, query: query) })
        }
        let deadlines = data.deadlines(today: store.today)
        let overdue = deadlines.filter { $0.status == .overdue }.count
        let soon = deadlines.filter { $0.status == .soon }.count
        let usedTypes = data.assetTypes.filter { t in all.contains { $0.typeID == t.id && $0.archived == showArchived } }
        let archivedCount = all.filter(\.archived).count

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: showArchived ? "Archiviati" : "I tuoi oggetti", subtitle: subtitle(count: all.count - archivedCount))

                if !all.isEmpty && !showArchived && (overdue > 0 || soon > 0) {
                    HStack(spacing: 10) {
                        if overdue > 0 { summaryTile(count: overdue, label: overdue == 1 ? "scaduta" : "scadute", status: .overdue) }
                        if soon > 0 { summaryTile(count: soon, label: "a breve", status: .soon) }
                    }
                }

                if !all.isEmpty {
                    searchBar
                    if usedTypes.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "Tutti", selected: typeFilter == nil) { typeFilter = nil }
                                ForEach(usedTypes) { t in
                                    FilterChip(label: t.name, icon: t.icon, selected: typeFilter == t.id) {
                                        typeFilter = typeFilter == t.id ? nil : t.id
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                    }
                }

                if all.isEmpty {
                    emptyState
                } else if visible.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "Nessun risultato", message: "Prova a cambiare filtro o ricerca.")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(visible) { asset in
                            NavigationLink(value: Route.asset(asset.id)) {
                                AssetCard(asset: asset)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }

                if archivedCount > 0 {
                    Button(showArchived ? "Torna agli oggetti attivi" : "Mostra archiviati (\(archivedCount))") {
                        withAnimation(.snappy) {
                            showArchived.toggle()
                            typeFilter = nil
                        }
                    }
                    .buttonStyle(.m3Text)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
            .animation(.snappy, value: typeFilter)
        }
        .scrollDismissesKeyboard(.immediately)
        .m3Screen(m3)
        .overlay(alignment: .bottomTrailing) {
            if !all.isEmpty {
                FAB(icon: "plus", label: "Nuovo") { showNew = true }
                    .padding(16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNew) {
            AssetFormView(original: nil, presetTypeID: typeFilter)
        }
        .confirmationDialog("Caricare i dati di esempio?", isPresented: $confirmDemo, titleVisibility: .visible) {
            Button("Carica esempio") {
                store.resetAll(withDemo: true)
                store.showToast("Dati di esempio caricati")
            }
        } message: {
            Text("Auto con gomme estive e invernali, bici, sci e caldaia, con operazioni e scadenze. Puoi cancellarli dalle Opzioni.")
        }
    }

    private func subtitle(count: Int) -> String {
        let today = Fmt.longDate(store.today)
        switch count {
        case 0: return today.capitalized
        case 1: return "1 oggetto · " + today
        default: return "\(count) oggetti · " + today
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(m3.onSurfaceVariant)
            TextField("Cerca per nome, targa, modello…", text: $query)
                .font(.m3BodyLarge)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(m3.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(m3.surfaceContainerHigh, in: Capsule())
    }

    private func summaryTile(count: Int, label: String, status: DueStatus) -> some View {
        let t = m3.tones(for: status)
        return Button {
            store.selectedTab = .deadlines
        } label: {
            HStack(spacing: 10) {
                Image(systemName: status == .overdue ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(count)").font(.m3TitleLarge.monospacedDigit())
                    Text(label).font(.m3LabelMedium)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(0.6)
            }
            .foregroundStyle(t.onContainer)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(t.container, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var emptyState: some View {
        M3Card(color: m3.surfaceContainerLow, padding: 20) {
            VStack(spacing: 16) {
                EmptyStateView(
                    icon: "car.side.fill",
                    title: "Inizia dal tuo primo oggetto",
                    message: "Auto, moto, bici, sci, gomme, caldaia… Registra km, manutenzioni, spese e scadenze. Tipi e operazioni sono tutti personalizzabili."
                )
                Button {
                    showNew = true
                } label: {
                    Label("Aggiungi oggetto", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.m3Filled)
                Button {
                    confirmDemo = true
                } label: {
                    Label("Prova con dati di esempio", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.m3Tonal)
            }
        }
        .padding(.top, 12)
    }
}

/// Object card of the home list.
struct AssetCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    let asset: Asset

    var body: some View {
        let data = store.data
        let type = data.type(of: asset)
        let tones = m3.tones(data.color(of: asset))
        let unit = data.unit(of: asset.id)
        let next = data.deadlines(today: store.today, assetID: asset.id).first
        let host = data.activeMounting(ofComponent: asset.id).flatMap { data.asset($0.hostID) }
        let mounted = data.activeComponents(onHost: asset.id)

        M3Card(color: m3.surfaceContainerLow, padding: 16, corner: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    IconBadge(icon: data.icon(of: asset), tones: tones, size: 54, cookie: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(asset.name)
                            .font(.m3TitleMedium)
                            .foregroundStyle(m3.onSurface)
                            .lineLimit(1)
                        Text(caption(type: type, host: host))
                            .font(.m3BodySmall)
                            .foregroundStyle(m3.onSurfaceVariant)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if !unit.isEmpty {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Fmt.number(data.meter(of: asset.id), decimals: 0))
                                .font(.m3TitleLarge.monospacedDigit())
                                .foregroundStyle(m3.onSurface)
                            Text(unit)
                                .font(.m3LabelMedium)
                                .foregroundStyle(m3.onSurfaceVariant)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(m3.onSurfaceVariant)
                    }
                }

                if !mounted.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(mounted) { c in
                            Label(c.name, systemImage: data.icon(of: c))
                                .font(.m3LabelMedium)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .foregroundStyle(m3.onSurfaceVariant)
                                .background(m3.surfaceContainerHighest, in: Capsule())
                        }
                    }
                }

                if let next, let opType = data.operationType(next.typeID) {
                    let st = m3.tones(for: next.status)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: opType.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(st.accent)
                            Text(opType.name)
                                .font(.m3LabelLarge)
                                .foregroundStyle(m3.onSurface)
                            Text(DeadlineText.short(next))
                                .font(.m3BodySmall)
                                .foregroundStyle(m3.onSurfaceVariant)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if next.status != .ok { StatusPill(status: next.status) }
                        }
                        M3Progress(value: next.progress, color: st.accent, track: m3.surfaceContainerHighest)
                    }
                }
            }
        }
        .opacity(asset.archived ? 0.6 : 1)
    }

    private func caption(type: AssetType?, host: Asset?) -> String {
        var parts: [String] = [type?.name ?? "Oggetto"]
        if let host { parts.append("su " + host.name) }
        if let first = type?.fields.first, let v = asset.attributes[first.id], !v.isEmpty { parts.append(v) }
        return parts.joined(separator: " · ")
    }
}

/// Human texts for deadlines.
enum DeadlineText {
    /// "tra 15 giorni", "scaduta da 3 giorni", "tra 1.200 km".
    static func short(_ d: Deadline) -> String {
        var parts: [String] = []
        if let days = d.daysLeft {
            parts.append(days < 0 ? "da \(Fmt.span(days: days))" : (days == 0 ? "oggi" : "tra \(Fmt.span(days: days))"))
        }
        if let left = d.meterLeft {
            parts.append(left <= 0 ? "superati di \(Fmt.meter(-left, unit: d.unit))" : "tra \(Fmt.meter(left, unit: d.unit))")
        }
        return parts.joined(separator: " · ")
    }

    static func dateLine(_ d: Deadline) -> String? {
        guard let due = d.dueDate, let days = d.daysLeft else { return nil }
        let rel = days < 0 ? "scaduta da \(Fmt.span(days: days))" : Fmt.relative(daysFromToday: days)
        return "\(Fmt.date(due)) · \(rel)"
    }

    static func meterLine(_ d: Deadline) -> String? {
        guard let due = d.dueMeter, let left = d.meterLeft else { return nil }
        let rel = left <= 0 ? "superati di \(Fmt.meter(-left, unit: d.unit))" : "mancano \(Fmt.meter(left, unit: d.unit))"
        return "a \(Fmt.meter(due, unit: d.unit)) · \(rel)"
    }
}
