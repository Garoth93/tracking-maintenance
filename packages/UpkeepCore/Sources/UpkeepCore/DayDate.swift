import Foundation

/// A calendar day without time or time zone, stored like the PWA does
/// ("YYYY-MM-DD", local date). Arithmetic is done on a plain day count,
/// so it is immune to daylight saving time and behaves the same on Linux.
public struct DayDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Days since 1970-01-01.
    public init(dayNumber: Int) {
        let civil = DayDate.civil(fromDays: dayNumber)
        year = civil.y
        month = civil.m
        day = civil.d
    }

    /// Out-of-range days roll over like JavaScript `Date` (e.g. Feb 30 → Mar 2).
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month) else { return nil }
        self.init(dayNumber: DayDate.days(fromCivil: year, month, day))
    }

    /// Parses "YYYY-MM-DD" (the same check as the PWA's `/^\d{4}-\d{2}-\d{2}$/`).
    public init?(iso: String) {
        let bytes = Array(iso.utf8)
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else { return nil }
        let digitPositions = [0, 1, 2, 3, 5, 6, 8, 9]
        guard digitPositions.allSatisfy({ bytes[$0] >= 48 && bytes[$0] <= 57 }) else { return nil }
        func number(_ range: Range<Int>) -> Int {
            range.reduce(0) { $0 * 10 + Int(bytes[$1] - 48) }
        }
        self.init(year: number(0..<4), month: number(5..<7), day: number(8..<10))
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(dayNumber: DayDate.days(fromCivil: c.year ?? 1970, c.month ?? 1, c.day ?? 1))
    }

    public static func today(calendar: Calendar = .current) -> DayDate {
        DayDate(date: Date(), calendar: calendar)
    }

    /// Noon of this day in `calendar`'s time zone (safe for date pickers).
    public func date(calendar: Calendar = .current) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = 12
        return calendar.date(from: c) ?? Date(timeIntervalSince1970: TimeInterval(dayNumber) * 86_400)
    }

    public var dayNumber: Int { DayDate.days(fromCivil: year, month, day) }

    public var iso: String { pad(year, 4) + "-" + pad(month, 2) + "-" + pad(day, 2) }

    public var description: String { iso }

    public func adding(days n: Int) -> DayDate { DayDate(dayNumber: dayNumber + n) }

    /// Calendar days from `a` to `b` (b - a).
    public static func daysBetween(_ a: DayDate, _ b: DayDate) -> Int { b.dayNumber - a.dayNumber }

    /// 0 = Sunday … 6 = Saturday (like JavaScript `getDay()`).
    public var weekdayFromSunday: Int { positiveModulo(dayNumber + 4, 7) }

    /// 0 = Monday … 6 = Sunday.
    public var weekdayFromMonday: Int { positiveModulo(dayNumber + 3, 7) }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool { lhs.dayNumber < rhs.dayNumber }

    // Howard Hinnant's civil-from-days algorithms (proleptic Gregorian).
    static func days(fromCivil y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civil(fromDays z0: Int) -> (y: Int, m: Int, d: Int) {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }
}

extension DayDate: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = DayDate(iso: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data non valida: \(string)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}

private func pad(_ n: Int, _ width: Int) -> String {
    let s = String(n)
    return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
}

private func positiveModulo(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }
