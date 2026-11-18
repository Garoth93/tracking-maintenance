import XCTest
@testable import UpkeepCore

final class FormatTests: XCTestCase {
    func testNumbers() {
        XCTAssertEqual(Fmt.number(12345.6), "12.345,6")
        XCTAssertEqual(Fmt.number(1000000, decimals: 0), "1.000.000")
        XCTAssertEqual(Fmt.number(0.05, decimals: 1), "0,1")
        XCTAssertEqual(Fmt.money(1234.5), "1.234,50 €")
        XCTAssertEqual(Fmt.meter(48200, unit: "km"), "48.200 km")
        XCTAssertEqual(Fmt.meter(18, unit: "uscite"), "18 uscite")
        XCTAssertEqual(Fmt.editable(1234.5), "1234,5")
        XCTAssertEqual(Fmt.editable(nil), "")
    }

    func testParse() {
        XCTAssertEqual(Fmt.parseNumber("12.345"), 12345)
        XCTAssertEqual(Fmt.parseNumber("12345,6"), 12345.6)
        XCTAssertEqual(Fmt.parseNumber("12.50"), 12.5)
        XCTAssertEqual(Fmt.parseNumber("0.500"), 0.5)
        XCTAssertEqual(Fmt.parseNumber("1.234,56"), 1234.56)
        XCTAssertEqual(Fmt.parseNumber("1,234.56"), 1234.56)
        XCTAssertEqual(Fmt.parseNumber("1.234.567"), 1234567)
        XCTAssertEqual(Fmt.parseNumber(" 15 000 "), 15000)
        XCTAssertEqual(Fmt.parseNumber("68,40 €"), 68.4)
        XCTAssertNil(Fmt.parseNumber(""))
        XCTAssertNil(Fmt.parseNumber("abc"))
    }

    func testMonthsAndTexts() {
        let d = DayDate(iso: "2026-01-31")!
        XCTAssertEqual(d.adding(months: 1).iso, "2026-02-28")
        XCTAssertEqual(d.adding(months: 13).iso, "2027-02-28")
        XCTAssertEqual(DayDate(iso: "2024-01-31")!.adding(months: 1).iso, "2024-02-29")
        XCTAssertEqual(d.adding(months: -2).iso, "2025-11-30")
        XCTAssertEqual(d.adding(months: 24).iso, "2028-01-31")
        XCTAssertEqual(Fmt.date(d), "31 gen 2026")
        XCTAssertEqual(Fmt.relative(daysFromToday: 5), "tra 5 giorni")
        XCTAssertEqual(Fmt.relative(daysFromToday: -3), "3 giorni fa")
        XCTAssertEqual(Fmt.interval(Interval(months: 12, meter: 15000), unit: "km"), "ogni 1 anno o 15.000 km")
        XCTAssertEqual(Fmt.interval(Interval(months: 6), unit: "km"), "ogni 6 mesi")
        XCTAssertEqual(Fmt.interval(Interval(), unit: "km"), "nessuna scadenza")
        XCTAssertEqual(Fmt.span(days: 400), "1 anno")
        XCTAssertEqual(Fmt.span(days: 90), "3 mesi")
    }
}

final class PaletteTests: XCTestCase {
    func testHexRoundTrip() {
        XCTAssertEqual(RGBColor(hex: "#6750A4")?.hex, "#6750a4")
        XCTAssertNil(RGBColor(hex: "zz"))
    }

    func testTonesAreOrderedAndInGamut() {
        let p = TonalPalette(hex: "#0b57d0")
        let light = ColorMath.lch(p.tone(90)).l
        let dark = ColorMath.lch(p.tone(30)).l
        XCTAssertEqual(light, 90, accuracy: 1.5)
        XCTAssertEqual(dark, 30, accuracy: 1.5)
        XCTAssertEqual(p.tone(100).hex, "#ffffff")
        XCTAssertEqual(p.tone(0).hex, "#000000")
        // Hue is preserved for a mid tone.
        XCTAssertEqual(ColorMath.lch(p.tone(50)).h, p.hue, accuracy: 4)
        let scheme = MaterialScheme(seed: "#6750a4", dark: true)
        XCTAssertLessThan(ColorMath.lch(scheme.surface).l, 10)
        XCTAssertGreaterThan(ColorMath.lch(scheme.onSurface).l, 85)
    }
}

final class MeterAndMountTests: XCTestCase {
    let today = DayDate(iso: "2026-11-18")!

    func testDemoMeters() {
        let d = Defaults.demo(today: today)
        XCTAssertEqual(d.meter(of: "demo.car"), 46800)
        // 18.000 (first summer) + 8.800 (since April)
        XCTAssertEqual(d.mountedDistance(componentID: "demo.summer"), 26800)
        XCTAssertEqual(d.meter(of: "demo.summer"), 26800)
        XCTAssertEqual(d.meter(of: "demo.winter"), 8000)
        XCTAssertEqual(d.activeComponents(onHost: "demo.car").map(\.id), ["demo.summer"])
        XCTAssertNotNil(d.dailyRate(of: "demo.car"))
        XCTAssertEqual(d.dailyRate(of: "demo.summer"), d.dailyRate(of: "demo.car"))
    }

    func testSwapReplacesSameType() {
        var d = Defaults.demo(today: today)
        let removed = d.mount(componentID: "demo.winter", on: "demo.car", date: today)
        XCTAssertEqual(removed, ["Gomme estive"])
        XCTAssertEqual(d.activeComponents(onHost: "demo.car").map(\.id), ["demo.winter"])
        XCTAssertEqual(d.meter(of: "demo.summer"), 26800)
        d.addReading(assetID: "demo.car", date: today.adding(days: 30), value: 48000)
        XCTAssertEqual(d.meter(of: "demo.winter"), 9200)
        XCTAssertEqual(d.meter(of: "demo.summer"), 26800)
        d.unmount(componentID: "demo.winter", date: today.adding(days: 31))
        d.addReading(assetID: "demo.car", date: today.adding(days: 40), value: 50000)
        XCTAssertEqual(d.meter(of: "demo.winter"), 9200)
    }

    func testMountTwiceOnSameHostIsNoOp() {
        var d = Defaults.demo(today: today)
        let count = d.mountings.count
        d.mount(componentID: "demo.summer", on: "demo.car", date: today)
        XCTAssertEqual(d.mountings.count, count)
    }

    func testDeleteHostKeepsComponentDistance() {
        var d = Defaults.demo(today: today)
        d.deleteAsset(id: "demo.car")
        XCTAssertEqual(d.meter(of: "demo.summer"), 26800)
        XCTAssertEqual(d.meter(of: "demo.winter"), 8000)
        XCTAssertTrue(d.mountings.isEmpty)
        XCTAssertFalse(d.operations.contains { $0.assetID == "demo.car" })
    }

    func testTypeDeletionIsBlockedWhenUsed() {
        var d = Defaults.demo(today: today)
        XCTAssertEqual(d.deleteAssetType(id: Defaults.TypeID.car), .typeInUse(count: 1))
        XCTAssertNil(d.deleteAssetType(id: Defaults.TypeID.moto))
        XCTAssertFalse(d.operationTypes.contains { $0.assetTypeIDs.contains(Defaults.TypeID.moto) })
        XCTAssertNotNil(d.deleteOperationType(id: Defaults.OpID.service))
        XCTAssertNil(d.deleteOperationType(id: Defaults.OpID.battery))
    }

    func testMoveAssets() {
        var d = Defaults.demo(today: today)
        d.moveAssets(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(d.sortedAssets().map(\.id).prefix(3), ["demo.summer", "demo.winter", "demo.car"])
    }
}

final class DeadlineTests: XCTestCase {
    let today = DayDate(iso: "2026-11-18")!

    func deadline(_ d: AppData, _ asset: String, _ type: String) -> Deadline? {
        d.deadlines(today: today).first { $0.assetID == asset && $0.typeID == type }
    }

    func testDemoStatuses() {
        let d = Defaults.demo(today: today)
        let service = deadline(d, "demo.car", Defaults.OpID.service)!
        XCTAssertEqual(service.dueMeter, 48000)
        XCTAssertEqual(service.meterLeft, 1200)
        XCTAssertEqual(service.status, .soon)
        XCTAssertEqual(deadline(d, "demo.car", Defaults.OpID.insurance)?.daysLeft, 15)
        XCTAssertEqual(deadline(d, "demo.car", Defaults.OpID.insurance)?.status, .soon)
        XCTAssertEqual(deadline(d, "demo.car", Defaults.OpID.tax)?.status, .overdue)
        XCTAssertEqual(deadline(d, "demo.car", Defaults.OpID.inspection)?.status, .ok)
        XCTAssertNil(deadline(d, "demo.car", Defaults.OpID.tyreSwap))
        XCTAssertNil(deadline(d, "demo.car", Defaults.OpID.fuel))
        XCTAssertEqual(deadline(d, "demo.bike", Defaults.OpID.chainClean)?.status, .overdue)
        XCTAssertEqual(deadline(d, "demo.bike", Defaults.OpID.chainReplace)?.status, .soon)
        XCTAssertEqual(deadline(d, "demo.ski", Defaults.OpID.edges)?.status, .overdue)
        // Rotation on the summer tyres follows the tyres' own km.
        XCTAssertEqual(deadline(d, "demo.summer", Defaults.OpID.rotation)?.meterLeft, 1200)
        // Most urgent first.
        XCTAssertEqual(d.deadlines(today: today).first?.status, .overdue)
        XCTAssertEqual(d.worstStatus(of: "demo.car", today: today), .overdue)
    }

    func testOnlyLatestOperationCountsAndNoFollowUp() {
        var d = Defaults.demo(today: today)
        d.saveOperation(Operation(assetID: "demo.car", typeID: Defaults.OpID.tax, date: today, cost: 245))
        let tax = deadline(d, "demo.car", Defaults.OpID.tax)!
        XCTAssertEqual(tax.dueDate, today.adding(months: 12))
        XCTAssertEqual(tax.status, .ok)
        d.saveOperation(Operation(assetID: "demo.car", typeID: Defaults.OpID.tax, date: today.adding(days: 1), noFollowUp: true))
        XCTAssertNil(deadline(d, "demo.car", Defaults.OpID.tax))
    }

    func testArchivedObjectsHaveNoDeadlines() {
        var d = Defaults.demo(today: today)
        d.setArchived(true, assetID: "demo.bike", today: today)
        XCTAssertFalse(d.deadlines(today: today).contains { $0.assetID == "demo.bike" })
    }

    func testEstimatedDateFromUsage() {
        var d = AppData(assetTypes: Defaults.assetTypes, operationTypes: Defaults.operationTypes)
        d.saveAsset(Asset(id: "a", typeID: Defaults.TypeID.car, name: "A", initialMeter: 0, createdOn: today.adding(days: -100)))
        d.addReading(assetID: "a", date: today, value: 10000) // 100 km/day
        d.saveOperation(Operation(assetID: "a", typeID: Defaults.OpID.oil, date: today, meter: 10000))
        let dl = d.deadlines(today: today).first!
        XCTAssertEqual(dl.dueMeter, 20000)
        XCTAssertEqual(dl.estimatedMeterDate, today.adding(days: 100))
        XCTAssertEqual(dl.status, .ok)
        XCTAssertEqual(dl.progress, 0, accuracy: 0.0001)
    }

    func testReminderPlans() {
        let d = Defaults.demo(today: today)
        let plans = d.reminderPlans(today: today, daysBefore: 7)
        XCTAssertTrue(plans.contains { $0.id == "demo.car|\(Defaults.OpID.insurance)|before" && $0.day == today.adding(days: 8) })
        XCTAssertTrue(plans.contains { $0.id == "demo.car|\(Defaults.OpID.insurance)|due" && $0.day == today.adding(days: 15) })
        XCTAssertFalse(plans.contains { $0.day < today })
        XCTAssertEqual(plans.map(\.day), plans.map(\.day).sorted())
    }
}

final class StatsAndDataTests: XCTestCase {
    let today = DayDate(iso: "2026-11-18")!

    func testExpenseReport() {
        let d = Defaults.demo(today: today)
        let all = d.expenseReport(year: nil)
        XCTAssertEqual(all.total, d.operations.reduce(0) { $0 + ($1.cost ?? 0) }, accuracy: 0.001)
        XCTAssertEqual(all.byAsset.first?.id, "demo.car")
        let y = d.expenseReport(year: 2026)
        XCTAssertEqual(y.byMonth.count, 12)
        XCTAssertEqual(y.byMonth.reduce(0) { $0 + $1.total }, y.total, accuracy: 0.001)
        XCTAssertEqual(all.byYear.reduce(0) { $0 + $1.total }, all.total, accuracy: 0.001)
        XCTAssertNotNil(d.costPerUnit(of: "demo.car"))
        XCTAssertNil(d.costPerUnit(of: "demo.boiler"))
    }

    func testTimeline() {
        let d = Defaults.demo(today: today)
        let car = d.timeline(of: "demo.car")
        XCTAssertEqual(car.map(\.date), car.map(\.date).sorted(by: >))
        XCTAssertEqual(car.filter { if case .mounted = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(car.filter { if case .unmounted = $0 { return true } else { return false } }.count, 2)
        let years = d.timelineByYear(of: "demo.car")
        XCTAssertEqual(years.reduce(0) { $0 + $1.events.count }, car.count)
        XCTAssertEqual(years.reduce(0) { $0 + $1.cost }, d.totalCost(of: "demo.car"), accuracy: 0.001)
    }

    func testJSONRoundTripAndLenientImport() throws {
        let d = Defaults.demo(today: today)
        let data = try JSONFileStore<AppData>.encoder.encode(d)
        XCTAssertEqual(try JSONFileStore<AppData>.decoder.decode(AppData.self, from: data), d)

        let minimal = #"{"assets":[{"id":"x","typeID":"t.missing","name":"X","notes":"","initialMeter":0,"attributes":{},"createdOn":"2026-01-01","archived":false,"order":0}],"operations":[{"id":"o","assetID":"x","typeID":"op.missing","date":"2026-02-01"}],"settings":{"theme":"dark"}}"#
        var imported = try JSONFileStore<AppData>.decoder.decode(AppData.self, from: Data(minimal.utf8))
        XCTAssertEqual(imported.settings.theme, .dark)
        XCTAssertEqual(imported.settings.soonDays, 30)
        XCTAssertEqual(imported.operations.first?.notes, "")
        imported.ensureTypes()
        XCTAssertNotNil(imported.assetType("t.missing"))
        XCTAssertNotNil(imported.operationType("op.missing"))
        XCTAssertTrue(imported.assetTypes.count > Defaults.assetTypes.count)

        XCTAssertThrowsError(try JSONFileStore<AppData>.decoder.decode(AppData.self, from: Data("{}".utf8)))
    }

    func testCSV() {
        let csv = Defaults.demo(today: today).operationsCSV()
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, Defaults.demo(today: today).operations.count + 1)
        XCTAssertTrue(lines[0].hasPrefix("Data;Oggetto"))
        XCTAssertTrue(csv.contains("Litri: 38,5"))
        XCTAssertTrue(csv.contains(";68,4;"))
    }

    func testDefaultsAreConsistent() {
        let ids = Set(Defaults.assetTypes.map(\.id))
        for op in Defaults.operationTypes { XCTAssertTrue(Set(op.assetTypeIDs).isSubset(of: ids), op.name) }
        XCTAssertEqual(Set(Defaults.operationTypes.map(\.id)).count, Defaults.operationTypes.count)
        let demo = Defaults.demo(today: today)
        for o in demo.operations {
            let a = demo.asset(o.assetID)!
            XCTAssertTrue(demo.operationType(o.typeID)!.applies(to: a.typeID), o.typeID)
        }
    }
}
