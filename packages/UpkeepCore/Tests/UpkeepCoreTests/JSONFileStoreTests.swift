import XCTest
@testable import UpkeepCore

final class JSONFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpkeepCoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsNilWhenMissing() throws {
        let store = JSONFileStore<AppData>(url: directory.appendingPathComponent("data.json"))
        XCTAssertNil(try store.load())
    }

    func testSaveCreatesDirectoryAndLoadRoundTrips() throws {
        let url = directory.appendingPathComponent("nested/data.json")
        let store = JSONFileStore<AppData>(url: url)
        let data = Defaults.demo(today: DayDate(iso: "2026-11-16")!)
        try store.save(data)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try store.load(), data)
    }
}
