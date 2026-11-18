import Foundation

extension DayDate {
    /// Adds calendar months, clamping the day to the end of the target month
    /// (31 jan + 1 month = 28/29 feb).
    public func adding(months n: Int) -> DayDate {
        let total = (year * 12 + (month - 1)) + n
        let y = Int((Double(total) / 12).rounded(.down))
        let m = total - y * 12 + 1
        let last = DayDate.daysInMonth(year: y, month: m)
        return DayDate(year: y, month: m, day: Swift.min(day, last)) ?? self
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}

/// Italian formatting with fixed rules, identical on iOS and Linux.
public enum Fmt {
    public static let monthNames = [
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"
    ]
    public static let monthShort = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]

    /// "16 novembre 2026"
    public static func longDate(_ d: DayDate) -> String { "\(d.day) \(monthNames[d.month - 1]) \(d.year)" }

    /// "16 nov 2026"
    public static func date(_ d: DayDate) -> String { "\(d.day) \(monthShort[d.month - 1]) \(d.year)" }

    /// "16 nov"
    public static func shortDate(_ d: DayDate) -> String { "\(d.day) \(monthShort[d.month - 1])" }

    /// 12345.6 → "12.345,6" (at most `decimals` decimals, trailing zeros removed unless `fixed`).
    public static func number(_ value: Double, decimals: Int = 1, fixed: Bool = false) -> String {
        guard value.isFinite else { return "–" }
        let negative = value < 0
        let factor = pow(10, Double(decimals))
        let scaled = (abs(value) * factor).rounded()
        var intPart = Int((scaled / factor).rounded(.down))
        var frac = Int(scaled - Double(intPart) * factor)
        if frac >= Int(factor) { intPart += 1; frac = 0 }
        var digits = String(intPart)
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        groups.insert(digits, at: 0)
        var result = groups.joined(separator: ".")
        if decimals > 0 {
            var f = String(frac)
            f = String(repeating: "0", count: max(0, decimals - f.count)) + f
            if !fixed {
                while f.hasSuffix("0") { f.removeLast() }
            }
            if !f.isEmpty { result += "," + f }
        }
        return (negative && (intPart != 0 || frac != 0) ? "-" : "") + result
    }

    /// "1.234,50 €"
    public static func money(_ value: Double, symbol: String = "€") -> String {
        number(value, decimals: 2, fixed: true) + " " + symbol
    }

    /// "1.235 €" (rounded, for summaries).
    public static func moneyShort(_ value: Double, symbol: String = "€") -> String {
        number(value, decimals: 0) + " " + symbol
    }

    /// "48.200 km" — empty unit gives just the number.
    public static func meter(_ value: Double, unit: String) -> String {
        let n = number(value, decimals: value.magnitude < 100 ? 1 : 0)
        return unit.isEmpty ? n : n + " " + unit
    }

    /// Plain value for text fields (no thousands separator): 1234.5 → "1234,5".
    public static func editable(_ value: Double?, decimals: Int = 2) -> String {
        guard let value else { return "" }
        return number(value, decimals: decimals).replacingOccurrences(of: ".", with: "")
    }

    /// Parses "12.345", "12345,6", "12.50", "1.234,56", "1,234.56". `nil` when empty or invalid.
    public static func parseNumber(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "'", with: "")
        guard !s.isEmpty else { return nil }
        let hasDot = s.contains("."), hasComma = s.contains(",")
        if hasDot && hasComma {
            let lastDot = s.lastIndex(of: ".")!, lastComma = s.lastIndex(of: ",")!
            if lastComma > lastDot {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            let parts = s.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count > 2 {
                s = s.replacingOccurrences(of: ",", with: "")
            } else {
                s = s.replacingOccurrences(of: ",", with: ".")
            }
        } else if hasDot {
            let parts = s.split(separator: ".", omittingEmptySubsequences: false)
            // Italian thousands separators: every group after a dot has 3 digits.
            if parts.count > 2 || (parts.count == 2 && parts[1].count == 3 && !parts[0].isEmpty && parts[0] != "0") {
                if parts.dropFirst().allSatisfy({ $0.count == 3 }) {
                    s = s.replacingOccurrences(of: ".", with: "")
                }
            }
        }
        guard let v = Double(s), v.isFinite else { return nil }
        return v
    }

    /// "oggi", "domani", "tra 5 giorni", "ieri", "3 giorni fa".
    public static func relative(daysFromToday n: Int) -> String {
        switch n {
        case 0: return "oggi"
        case 1: return "domani"
        case -1: return "ieri"
        case 2...: return "tra \(n) giorni"
        default: return "\(-n) giorni fa"
        }
    }

    /// Compact span: "12 g", "5 sett", "4 mesi", "1 anno", "2 anni".
    public static func span(days: Int) -> String {
        let a = abs(days)
        if a < 14 { return "\(a) " + (a == 1 ? "giorno" : "giorni") }
        if a < 60 { return "\(a / 7) sett" }
        if a < 365 {
            let m = Int((Double(a) / 30.44).rounded())
            return "\(m) " + (m == 1 ? "mese" : "mesi")
        }
        let y = Double(a) / 365.25
        let rounded = (y * 2).rounded() / 2
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : number(rounded, decimals: 1)
        return text + " " + (rounded == 1 ? "anno" : "anni")
    }

    /// "ogni 12 mesi · 15.000 km"
    public static func interval(_ interval: Interval, unit: String) -> String {
        var parts: [String] = []
        if let m = interval.months, m > 0 {
            if m % 12 == 0 {
                let y = m / 12
                parts.append(y == 1 ? "1 anno" : "\(y) anni")
            } else {
                parts.append(m == 1 ? "1 mese" : "\(m) mesi")
            }
        }
        if let v = interval.meter, v > 0 { parts.append(meter(v, unit: unit.isEmpty ? "unità" : unit)) }
        return parts.isEmpty ? "nessuna scadenza" : "ogni " + parts.joined(separator: " o ")
    }

    /// Case- and accent-insensitive comparison for sorting by name.
    public static func compare(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending
    }

    /// Case- and accent-insensitive search.
    public static func matches(_ text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
