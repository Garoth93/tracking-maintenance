import SwiftUI
import UpkeepCore

/// Card of one deadline with progress and a "Fatto" button.
struct DeadlineCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    let deadline: Deadline
    let showAsset: Bool
    let onDone: () -> Void

    var body: some View {
        let data = store.data
        let type = data.operationType(deadline.typeID)
        let asset = data.asset(deadline.assetID)
        let st = m3.tones(for: deadline.status)

        M3Card(color: deadline.status == .ok ? m3.surfaceContainerLow : st.container.opacity(m3.dark ? 0.55 : 0.6)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(icon: type?.icon ?? "calendar", tones: m3.tones(type?.color ?? Palette.defaultAccent), size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type?.name ?? "Scadenza")
                            .font(.m3TitleSmall)
                            .foregroundStyle(m3.onSurface)
                        if showAsset, let asset {
                            Label(asset.name, systemImage: data.icon(of: asset))
                                .font(.m3BodySmall)
                                .foregroundStyle(m3.onSurfaceVariant)
                                .lineLimit(1)
                        } else {
                            Text("ultima \(Fmt.date(deadline.lastDate))")
                                .font(.m3BodySmall)
                                .foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    Spacer(minLength: 6)
                    StatusPill(status: deadline.status)
                }

                M3Progress(value: deadline.progress, color: st.accent, track: m3.surfaceContainerHighest, height: 8)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let line = DeadlineText.dateLine(deadline) {
                            Label(line, systemImage: "calendar").labelStyle(CompactLabel())
                        }
                        if let line = DeadlineText.meterLine(deadline) {
                            Label(line, systemImage: "gauge.with.dots.needle.33percent").labelStyle(CompactLabel())
                        }
                        if deadline.dueDate == nil, let est = deadline.estimatedMeterDate {
                            Label("stimata il \(Fmt.date(est))", systemImage: "sparkles").labelStyle(CompactLabel())
                        }
                    }
                    .font(.m3BodySmall)
                    .foregroundStyle(m3.onSurfaceVariant)
                    Spacer(minLength: 8)
                    Button {
                        onDone()
                    } label: {
                        Label("Fatto", systemImage: "checkmark")
                    }
                    .buttonStyle(.m3FilledSmall)
                }
            }
        }
    }
}

struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.frame(width: 16)
            configuration.title
        }
    }
}

struct DeadlineGroup: Identifiable {
    let status: DueStatus
    let items: [Deadline]
    var id: Int { status.rawValue }
}

struct DeadlinesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var filter: DueStatus?
    @State private var logTarget: Deadline?

    var body: some View {
        let all = store.data.deadlines(today: store.today)
        let shown = all.filter { filter == nil || $0.status == filter }
        let groups: [DeadlineGroup] = [DueStatus.overdue, .soon, .ok].compactMap { s in
            let list = shown.filter { $0.status == s }
            return list.isEmpty ? nil : DeadlineGroup(status: s, items: list)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Scadenze", subtitle: subtitle(all))

                if !all.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "Tutte", selected: filter == nil) { filter = nil }
                            ForEach([DueStatus.overdue, .soon, .ok], id: \.self) { s in
                                let n = all.filter { $0.status == s }.count
                                FilterChip(label: "\(groupTitle(s)) · \(n)", selected: filter == s) {
                                    filter = filter == s ? nil : s
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()
                }

                if all.isEmpty {
                    M3Card(padding: 20) {
                        EmptyStateView(
                            icon: "calendar.badge.checkmark",
                            title: "Nessuna scadenza",
                            message: "Le scadenze nascono dalle operazioni con un intervallo (es. Tagliando ogni 12 mesi o 15.000 km) o con una data di scadenza impostata (es. Assicurazione)."
                        )
                    }
                } else {
                    ForEach(groups) { group in
                        SectionTitle(title: groupTitle(group.status), trailing: "\(group.items.count)")
                        VStack(spacing: 10) {
                            ForEach(group.items) { d in
                                NavigationLink(value: Route.asset(d.assetID)) {
                                    DeadlineCard(deadline: d, showAsset: true) { logTarget = d }
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .animation(.snappy, value: filter)
        }
        .m3Screen(m3)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $logTarget) { d in
            OperationFormView(assetID: d.assetID, original: nil, presetTypeID: d.typeID)
        }
    }

    private func groupTitle(_ s: DueStatus) -> String {
        switch s {
        case .overdue: return "Scadute"
        case .soon: return "A breve"
        case .ok: return "In regola"
        }
    }

    private func subtitle(_ all: [Deadline]) -> String {
        let urgent = all.filter { $0.status != .ok }.count
        if all.isEmpty { return "Tutto sotto controllo" }
        if urgent == 0 { return "Tutto in regola · \(all.count) monitorate" }
        return "\(urgent) da gestire · \(all.count) monitorate"
    }
}
