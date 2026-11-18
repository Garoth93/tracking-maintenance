import SwiftUI
import Charts
import UpkeepCore

struct ExpensesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var year: Int?
    @State private var didInit = false
    @State private var breakdown = 0

    var body: some View {
        let data = store.data
        let symbol = data.settings.currencySymbol
        let report = data.expenseReport(year: year)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Spese", subtitle: year.map { "Anno \($0)" } ?? "Da sempre")

                if report.years.isEmpty {
                    M3Card(padding: 20) {
                        EmptyStateView(icon: "eurosign.circle", title: "Nessuna spesa",
                                       message: "Inserisci il costo quando registri un'operazione: qui vedrai i totali per anno, oggetto e tipo.")
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(report.years, id: \.self) { y in
                                FilterChip(label: String(y), selected: year == y) { year = y }
                            }
                            FilterChip(label: "Tutti", selected: year == nil) { year = nil }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()

                    hero(report, symbol: symbol)
                    chart(report)

                    HStack(spacing: 8) {
                        FilterChip(label: "Per oggetto", icon: "square.grid.2x2", selected: breakdown == 0) { breakdown = 0 }
                        FilterChip(label: "Per operazione", icon: "wrench.and.screwdriver", selected: breakdown == 1) { breakdown = 1 }
                    }
                    .padding(.top, 6)

                    let slices = breakdown == 0 ? report.byAsset : report.byType
                    VStack(spacing: 8) {
                        ForEach(slices) { s in
                            sliceRow(s, max: slices.first?.total ?? 1, symbol: symbol)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .animation(.snappy, value: year)
            .animation(.snappy, value: breakdown)
        }
        .m3Screen(m3)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !didInit else { return }
            didInit = true
            let years = store.data.expenseReport(year: nil).years
            year = years.contains(store.today.year) ? store.today.year : years.first
        }
    }

    private func hero(_ report: ExpenseReport, symbol: String) -> some View {
        M3Card(color: m3.primaryContainer, padding: 20, corner: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text(report.year == nil ? "Totale" : "Totale \(report.year!)")
                    .font(.m3LabelLarge)
                    .foregroundStyle(m3.onPrimaryContainer.opacity(0.8))
                Text(Fmt.money(report.total, symbol: symbol))
                    .font(.m3DisplaySmall.monospacedDigit())
                    .foregroundStyle(m3.onPrimaryContainer)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(report.count == 1 ? "1 operazione con costo" : "\(report.count) operazioni con costo")
                    .font(.m3BodySmall)
                    .foregroundStyle(m3.onPrimaryContainer.opacity(0.8))
            }
        }
    }

    @ViewBuilder
    private func chart(_ report: ExpenseReport) -> some View {
        M3Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(report.year == nil ? "Per anno" : "Per mese")
                    .font(.m3TitleSmall)
                    .foregroundStyle(m3.onSurface)
                if report.year != nil {
                    Chart(report.byMonth) { m in
                        BarMark(x: .value("Mese", Fmt.monthShort[m.month - 1]), y: .value("Spesa", m.total), width: .ratio(0.6))
                            .foregroundStyle(m.month == store.today.month && report.year == store.today.year ? m3.tertiary : m3.primary)
                            .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel().font(.m3LabelSmall).foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(m3.outlineVariant)
                            AxisValueLabel().font(.m3LabelSmall).foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    .frame(height: 180)
                } else {
                    Chart(report.byYear) { y in
                        BarMark(x: .value("Anno", String(y.year)), y: .value("Spesa", y.total), width: .ratio(0.55))
                            .foregroundStyle(m3.primary)
                            .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel().font(.m3LabelSmall).foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(m3.outlineVariant)
                            AxisValueLabel().font(.m3LabelSmall).foregroundStyle(m3.onSurfaceVariant)
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }

    private func sliceRow(_ s: CostSlice, max: Double, symbol: String) -> some View {
        let tones = m3.tones(s.color)
        return M3Card(padding: 14, corner: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconBadge(icon: s.icon, tones: tones, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.name).font(.m3TitleSmall).foregroundStyle(m3.onSurface).lineLimit(1)
                        Text(s.count == 1 ? "1 operazione" : "\(s.count) operazioni")
                            .font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                    }
                    Spacer()
                    Text(Fmt.money(s.total, symbol: symbol))
                        .font(.m3TitleSmall.monospacedDigit())
                        .foregroundStyle(m3.onSurface)
                }
                M3Progress(value: max > 0 ? s.total / max : 0, color: tones.accent, track: m3.surfaceContainerHighest)
            }
        }
    }
}
