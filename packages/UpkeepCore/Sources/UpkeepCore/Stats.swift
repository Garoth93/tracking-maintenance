import Foundation

public struct CostSlice: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let color: String
    public let icon: String
    public let total: Double
    public let count: Int
}

public struct MonthCost: Equatable, Sendable, Identifiable {
    public var id: Int { month }
    /// 1…12
    public let month: Int
    public let total: Double
}

public struct YearCost: Equatable, Sendable, Identifiable {
    public var id: Int { year }
    public let year: Int
    public let total: Double
}

/// Expense summaries for the Spese screen and the object detail.
public struct ExpenseReport: Equatable, Sendable {
    public let year: Int?
    public let total: Double
    public let count: Int
    public let byAsset: [CostSlice]
    public let byType: [CostSlice]
    /// Only when `year` is set.
    public let byMonth: [MonthCost]
    public let byYear: [YearCost]
    public let years: [Int]
}

extension AppData {
    /// Expenses of a year (or all time when `nil`), optionally of one object.
    public func expenseReport(year: Int?, assetID: String? = nil) -> ExpenseReport {
        let all = operations.filter { ($0.cost ?? 0) != 0 && (assetID == nil || $0.assetID == assetID) }
        let years = Array(Set(all.map(\.date.year))).sorted(by: >)
        let ops = all.filter { year == nil || $0.date.year == year }

        func slices(key: (OperationRecord) -> String, meta: (String) -> (String, String, String)) -> [CostSlice] {
            var totals: [String: (Double, Int)] = [:]
            for o in ops {
                let k = key(o)
                let cur = totals[k] ?? (0, 0)
                totals[k] = (cur.0 + (o.cost ?? 0), cur.1 + 1)
            }
            return totals.map { k, v in
                let m = meta(k)
                return CostSlice(id: k, name: m.0, color: m.1, icon: m.2, total: v.0, count: v.1)
            }.sorted { $0.total != $1.total ? $0.total > $1.total : Fmt.compare($0.name, $1.name) }
        }

        let byAsset = slices(key: \.assetID) { id in
            guard let a = asset(id) else { return ("Eliminato", "#546e7a", "questionmark") }
            return (a.name, color(of: a), icon(of: a))
        }
        let byType = slices(key: \.typeID) { id in
            guard let t = operationType(id) else { return ("Altro", "#546e7a", "questionmark") }
            return (t.name, t.color, t.icon)
        }
        var byMonth: [MonthCost] = []
        if year != nil {
            var months = [Double](repeating: 0, count: 12)
            for o in ops { months[o.date.month - 1] += o.cost ?? 0 }
            byMonth = months.enumerated().map { MonthCost(month: $0.offset + 1, total: $0.element) }
        }
        var yearTotals: [Int: Double] = [:]
        for o in all { yearTotals[o.date.year, default: 0] += o.cost ?? 0 }
        let byYear = yearTotals.map { YearCost(year: $0.key, total: $0.value) }.sorted { $0.year < $1.year }

        return ExpenseReport(
            year: year,
            total: ops.reduce(0) { $0 + ($1.cost ?? 0) },
            count: ops.count,
            byAsset: byAsset,
            byType: byType,
            byMonth: byMonth,
            byYear: byYear,
            years: years
        )
    }

    /// Cost per unit of counter since the object was added (e.g. €/km), if meaningful.
    public func costPerUnit(of assetID: String) -> Double? {
        guard let a = asset(assetID) else { return nil }
        let used = meter(of: assetID) - a.initialMeter
        let cost = totalCost(of: assetID)
        guard used > 0, cost > 0, !unit(of: assetID).isEmpty else { return nil }
        return cost / used
    }
}
