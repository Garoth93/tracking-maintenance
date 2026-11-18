import XCTest
@testable import UpkeepCore

final class DayDateTests: XCTestCase {
    func testEpochAndRoundTrip() {
        XCTAssertEqual(DayDate(iso: "1970-01-01")?.dayNumber, 0)
        for iso in ["2000-02-29", "2024-12-31", "2026-11-16", "1999-01-01", "2100-03-01"] {
            XCTAssertEqual(DayDate(iso: iso)?.iso, iso)
            let d = DayDate(iso: iso)!
            XCTAssertEqual(DayDate(dayNumber: d.dayNumber), d)
        }
    }

    func testInvalidStringsAreRejected() {
        XCTAssertNil(DayDate(iso: "2026-13-01"))
        XCTAssertNil(DayDate(iso: "26-01-01"))
        XCTAssertNil(DayDate(iso: "2026/01/01"))
        XCTAssertNil(DayDate(iso: "2026-1-5"))
        XCTAssertNil(DayDate(iso: ""))
    }

    func testOverflowRollsOverLikeJavaScript() {
        XCTAssertEqual(DayDate(iso: "2026-02-30")?.iso, "2026-03-02")
        XCTAssertEqual(DayDate(iso: "2024-02-29")?.adding(days: 1).iso, "2024-03-01")
    }

    func testArithmeticAndWeekdays() {
        let monday = DayDate(iso: "2026-11-16")!
        XCTAssertEqual(monday.weekdayFromMonday, 0)
        XCTAssertEqual(monday.weekdayFromSunday, 1)
        XCTAssertEqual(DayDate(iso: "2026-11-22")!.weekdayFromSunday, 0)
        XCTAssertEqual(DayDate.daysBetween(DayDate(iso: "2026-03-28")!, DayDate(iso: "2026-04-02")!), 5)
        XCTAssertEqual(monday.adding(days: -16).iso, "2026-10-31")
        XCTAssertTrue(DayDate(iso: "2026-01-01")! < monday)
    }

    func testDateConversionUsesCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let d = DayDate(iso: "2026-03-29")!
        XCTAssertEqual(DayDate(date: d.date(calendar: calendar), calendar: calendar), d)
    }

    func testCodableAsString() throws {
        let data = try JSONEncoder().encode([DayDate(iso: "2026-11-16")!])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-11-16\"]")
        let decoded = try JSONDecoder().decode([DayDate].self, from: data)
        XCTAssertEqual(decoded.first?.iso, "2026-11-16")
        XCTAssertThrowsError(try JSONDecoder().decode([DayDate].self, from: Data("[\"x\"]".utf8)))
    }
}
