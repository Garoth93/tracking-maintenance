import Foundation

/// One row of an object's history.
public enum TimelineEvent: Equatable, Sendable, Identifiable {
    case operation(OperationRecord)
    case reading(MeterReading)
    /// `other` is the host (for a component) or the component (for a host).
    case mounted(Mounting, otherID: String)
    case unmounted(Mounting, otherID: String)

    public var id: String {
        switch self {
        case .operation(let o): return "op-" + o.id
        case .reading(let r): return "rd-" + r.id
        case .mounted(let m, _): return "mo-" + m.id
        case .unmounted(let m, _): return "um-" + m.id
        }
    }

    public var date: DayDate {
        switch self {
        case .operation(let o): return o.date
        case .reading(let r): return r.date
        case .mounted(let m, _): return m.startDate
        case .unmounted(let m, _): return m.endDate ?? m.startDate
        }
    }

    var tieBreak: Int {
        switch self {
        case .unmounted: return 3
        case .mounted: return 2
        case .operation: return 1
        case .reading: return 0
        }
    }
}

public struct TimelineYear: Equatable, Sendable, Identifiable {
    public var id: Int { year }
    public let year: Int
    public let events: [TimelineEvent]
    public let cost: Double
}

extension AppData {
    /// Operations, counter readings and mount events of an object, newest first.
    public func timeline(of assetID: String, includeReadings: Bool = true) -> [TimelineEvent] {
        var events: [TimelineEvent] = operations.filter { $0.assetID == assetID }.map { .operation($0) }
        if includeReadings {
            events += readings.filter { $0.assetID == assetID }.map { .reading($0) }
        }
        for m in mountings where m.componentID == assetID || m.hostID == assetID {
            let other = m.componentID == assetID ? m.hostID : m.componentID
            events.append(.mounted(m, otherID: other))
            if !m.isActive { events.append(.unmounted(m, otherID: other)) }
        }
        return events.sorted { a, b in
            if a.date != b.date { return a.date > b.date }
            if a.tieBreak != b.tieBreak { return a.tieBreak > b.tieBreak }
            return a.id < b.id
        }
    }

    /// The timeline grouped by year with the yearly expense.
    public func timelineByYear(of assetID: String, includeReadings: Bool = true) -> [TimelineYear] {
        let events = timeline(of: assetID, includeReadings: includeReadings)
        var years: [Int] = []
        var grouped: [Int: [TimelineEvent]] = [:]
        for e in events {
            if grouped[e.date.year] == nil { years.append(e.date.year) }
            grouped[e.date.year, default: []].append(e)
        }
        return years.map { y in
            let list = grouped[y] ?? []
            let cost = list.reduce(0.0) { sum, e in
                if case .operation(let o) = e { return sum + (o.cost ?? 0) }
                return sum
            }
            return TimelineYear(year: y, events: list, cost: cost)
        }
    }
}
