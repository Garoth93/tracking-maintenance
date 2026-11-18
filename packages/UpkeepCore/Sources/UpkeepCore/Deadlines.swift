import Foundation

public enum DueStatus: Int, Comparable, Sendable {
    case ok = 0
    case soon = 1
    case overdue = 2

    public static func < (lhs: DueStatus, rhs: DueStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .ok: return "In regola"
        case .soon: return "A breve"
        case .overdue: return "Scaduta"
        }
    }
}

/// Next deadline of one operation type on one object, computed from the latest
/// operation of that type (explicit due date/counter or the type's interval).
public struct Deadline: Identifiable, Equatable, Sendable {
    public var id: String { assetID + "|" + typeID }
    public let assetID: String
    public let typeID: String
    public let lastOperationID: String
    public let lastDate: DayDate
    public let lastMeter: Double?
    public let dueDate: DayDate?
    public let dueMeter: Double?
    public let currentMeter: Double
    public let unit: String
    /// Days from today to `dueDate` (negative when past).
    public let daysLeft: Int?
    /// Counter left to `dueMeter` (negative when past).
    public let meterLeft: Double?
    /// When `dueMeter` will probably be reached, from the average daily usage.
    public let estimatedMeterDate: DayDate?
    public let status: DueStatus
    /// 0…1 (or more when overdue): how much of the interval has passed.
    public let progress: Double

    /// The earliest known or estimated date, for sorting.
    public var effectiveDate: DayDate? {
        switch (dueDate, estimatedMeterDate) {
        case let (a?, b?): return min(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }
}

extension AppData {
    /// Latest operation of each (object, type) pair.
    func latestOperations() -> [OperationRecord] {
        var latest: [String: OperationRecord] = [:]
        for op in operations {
            let key = op.assetID + "|" + op.typeID
            if let current = latest[key], !Self.newestFirst(op, current) { continue }
            latest[key] = op
        }
        return Array(latest.values)
    }

    public func deadline(for op: OperationRecord, today: DayDate) -> Deadline? {
        guard !op.noFollowUp, let type = operationType(op.typeID) else { return nil }
        let dueDate: DayDate? = op.dueDate ?? type.interval.months.flatMap { $0 > 0 ? op.date.adding(months: $0) : nil }
        let dueMeter: Double? = op.dueMeter ?? {
            guard let step = type.interval.meter, step > 0, let start = op.meter else { return nil }
            return start + step
        }()
        guard dueDate != nil || dueMeter != nil else { return nil }

        let current = meter(of: op.assetID)
        let daysLeft = dueDate.map { DayDate.daysBetween(today, $0) }
        let meterLeft = dueMeter.map { $0 - current }

        var estimated: DayDate?
        if let left = meterLeft, let rate = dailyRate(of: op.assetID), rate > 0 {
            let days = left / rate
            if days.isFinite, abs(days) < 365 * 30 { estimated = today.adding(days: Int(days.rounded(.down))) }
        }

        // Progress through the interval (time and counter, whichever is further).
        var progress = 0.0
        if let due = dueDate {
            let span = DayDate.daysBetween(op.date, due)
            let done = DayDate.daysBetween(op.date, today)
            progress = span > 0 ? Double(done) / Double(span) : (done >= 0 ? 1 : 0)
        }
        var meterSpan: Double?
        if let due = dueMeter {
            if let start = op.meter, due > start {
                meterSpan = due - start
            } else if let step = type.interval.meter, step > 0 {
                meterSpan = step
            }
            if let span = meterSpan, let left = meterLeft { progress = Swift.max(progress, 1 - left / span) }
        }
        progress = Swift.max(0, progress)

        var status = DueStatus.ok
        if (daysLeft ?? 1) < 0 || (meterLeft ?? 1) <= 0 {
            status = .overdue
        } else {
            let soonDays = settings.soonDays
            let soonByTime = (daysLeft.map { $0 <= soonDays } ?? false)
                || (estimated.map { DayDate.daysBetween(today, $0) <= soonDays } ?? false)
            let soonByMeter: Bool = {
                guard let left = meterLeft, let span = meterSpan, span > 0 else { return false }
                return left <= span * Double(settings.soonMeterPercent) / 100
            }()
            if soonByTime || soonByMeter { status = .soon }
        }

        return Deadline(
            assetID: op.assetID,
            typeID: op.typeID,
            lastOperationID: op.id,
            lastDate: op.date,
            lastMeter: op.meter,
            dueDate: dueDate,
            dueMeter: dueMeter,
            currentMeter: current,
            unit: unit(of: op.assetID),
            daysLeft: daysLeft,
            meterLeft: meterLeft,
            estimatedMeterDate: estimated,
            status: status,
            progress: progress
        )
    }

    /// All deadlines of non-archived objects, most urgent first.
    public func deadlines(today: DayDate, assetID: String? = nil) -> [Deadline] {
        let visible = Set(assets.filter { !$0.archived }.map(\.id))
        return latestOperations()
            .filter { visible.contains($0.assetID) && (assetID == nil || $0.assetID == assetID) }
            .compactMap { deadline(for: $0, today: today) }
            .sorted(by: Self.moreUrgent)
    }

    static func moreUrgent(_ a: Deadline, _ b: Deadline) -> Bool {
        if a.status != b.status { return a.status > b.status }
        switch (a.effectiveDate, b.effectiveDate) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.progress > b.progress
        }
    }

    /// Worst status among an object's deadlines.
    public func worstStatus(of assetID: String, today: DayDate) -> DueStatus? {
        deadlines(today: today, assetID: assetID).map(\.status).max()
    }
}

/// A local notification to schedule for a deadline.
public struct ReminderPlan: Equatable, Sendable {
    public let id: String
    public let day: DayDate
    public let title: String
    public let body: String
}

extension AppData {
    /// Reminders for date-based (or estimated) deadlines: `daysBefore` days ahead and on the day.
    public func reminderPlans(today: DayDate, daysBefore: Int, limit: Int = 60) -> [ReminderPlan] {
        var plans: [ReminderPlan] = []
        for d in deadlines(today: today) {
            guard let a = asset(d.assetID), let t = operationType(d.typeID) else { continue }
            guard let day = d.dueDate ?? d.estimatedMeterDate else { continue }
            let estimated = d.dueDate == nil
            let what = "\(t.name) · \(a.name)"
            if daysBefore > 0 {
                let before = day.adding(days: -daysBefore)
                if before > today {
                    plans.append(ReminderPlan(
                        id: d.id + "|before",
                        day: before,
                        title: what,
                        body: (estimated ? "Scadenza stimata" : "Scade") + " tra \(daysBefore) giorni, il \(Fmt.date(day))."
                    ))
                }
            }
            if day >= today {
                plans.append(ReminderPlan(
                    id: d.id + "|due",
                    day: day,
                    title: what,
                    body: estimated ? "Oggi dovresti raggiungere \(Fmt.meter(d.dueMeter ?? 0, unit: d.unit))." : "Scade oggi."
                ))
            }
        }
        return Array(plans.sorted { $0.day < $1.day }.prefix(limit))
    }
}
