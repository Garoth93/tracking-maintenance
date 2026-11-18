import Foundation

/// A dated counter value, from a reading, an operation or the object's creation.
public struct MeterPoint: Equatable, Sendable {
    public let date: DayDate
    public let value: Double
}

extension AppData {
    // MARK: Lookups

    public func asset(_ id: String) -> Asset? { assets.first { $0.id == id } }

    public func assetType(_ id: String) -> AssetType? { assetTypes.first { $0.id == id } }

    public func operationType(_ id: String) -> OperationType? { operationTypes.first { $0.id == id } }

    public func type(of asset: Asset) -> AssetType? { assetType(asset.typeID) }

    public func unit(of assetID: String) -> String {
        guard let a = asset(assetID), let t = type(of: a) else { return "" }
        return t.meterUnit.trimmingCharacters(in: .whitespaces)
    }

    public func icon(of asset: Asset) -> String {
        asset.icon ?? type(of: asset)?.icon ?? "shippingbox.fill"
    }

    public func color(of asset: Asset) -> String {
        asset.color ?? type(of: asset)?.color ?? Palette.defaultAccent
    }

    public func isComponent(_ asset: Asset) -> Bool { type(of: asset)?.isComponent ?? false }

    /// Operation types offered for an object, in list order.
    public func operationTypes(for asset: Asset) -> [OperationType] {
        operationTypes.filter { $0.applies(to: asset.typeID) }
    }

    /// Visible objects sorted by `order`, then name.
    public func sortedAssets(includeArchived: Bool = false) -> [Asset] {
        assets
            .filter { includeArchived || !$0.archived }
            .sorted { $0.order != $1.order ? $0.order < $1.order : Fmt.compare($0.name, $1.name) }
    }

    public func operations(of assetID: String) -> [Operation] {
        operations
            .filter { $0.assetID == assetID }
            .sorted(by: Self.newestFirst)
    }

    public func readings(of assetID: String) -> [MeterReading] {
        readings.filter { $0.assetID == assetID }.sorted { $0.date != $1.date ? $0.date > $1.date : $0.value > $1.value }
    }

    static func newestFirst(_ a: Operation, _ b: Operation) -> Bool {
        if a.date != b.date { return a.date > b.date }
        return (a.meter ?? -1) > (b.meter ?? -1)
    }

    // MARK: Mountings

    public func mountings(ofComponent id: String) -> [Mounting] {
        mountings.filter { $0.componentID == id }.sorted { $0.startDate > $1.startDate }
    }

    public func mountings(onHost id: String) -> [Mounting] {
        mountings.filter { $0.hostID == id }.sorted { $0.startDate > $1.startDate }
    }

    public func activeMounting(ofComponent id: String) -> Mounting? {
        mountings.first { $0.componentID == id && $0.isActive }
    }

    public func activeComponents(onHost id: String) -> [Asset] {
        mountings
            .filter { $0.hostID == id && $0.isActive }
            .compactMap { asset($0.componentID) }
            .sorted { Fmt.compare($0.name, $1.name) }
    }

    /// Objects that can be mounted on `host` (components, not the host itself, not archived).
    public func mountCandidates(for host: Asset) -> [Asset] {
        assets.filter { $0.id != host.id && !$0.archived && isComponent($0) }
            .sorted { Fmt.compare($0.name, $1.name) }
    }

    /// Counter accumulated by a component while mounted (sum of all mount periods).
    public func mountedDistance(componentID: String) -> Double {
        mountedDistance(componentID: componentID, depth: 0)
    }

    func mountedDistance(componentID: String, depth: Int) -> Double {
        guard depth < 8 else { return 0 }
        return mountings.filter { $0.componentID == componentID }.reduce(0) { sum, m in
            let end = m.endHostMeter ?? meter(of: m.hostID, depth: depth + 1)
            return sum + Swift.max(0, end - m.startHostMeter)
        }
    }

    /// Distance of one mount period (the current one uses the host's live counter).
    public func distance(of mounting: Mounting) -> Double {
        let end = mounting.endHostMeter ?? meter(of: mounting.hostID)
        return Swift.max(0, end - mounting.startHostMeter)
    }

    // MARK: Counter

    /// Current counter of an object: the highest of its initial value plus mounted
    /// distance, its readings and the counter values of its operations.
    public func meter(of assetID: String) -> Double {
        meter(of: assetID, depth: 0)
    }

    func meter(of assetID: String, depth: Int) -> Double {
        guard let a = asset(assetID) else { return 0 }
        var value = a.initialMeter + mountedDistance(componentID: assetID, depth: depth)
        for r in readings where r.assetID == assetID { value = Swift.max(value, r.value) }
        for o in operations where o.assetID == assetID { if let m = o.meter { value = Swift.max(value, m) } }
        return value
    }

    /// Dated counter values of an object (creation, readings, operations), oldest first.
    public func meterPoints(of assetID: String) -> [MeterPoint] {
        guard let a = asset(assetID) else { return [] }
        var points = [MeterPoint(date: a.createdOn, value: a.initialMeter)]
        points += readings.filter { $0.assetID == assetID }.map { MeterPoint(date: $0.date, value: $0.value) }
        points += operations.filter { $0.assetID == assetID }.compactMap { o in o.meter.map { MeterPoint(date: o.date, value: $0) } }
        return points.sorted { $0.date != $1.date ? $0.date < $1.date : $0.value < $1.value }
    }

    /// Average counter growth per day, from the first to the last dated value.
    /// `nil` for components (their counter follows the host), with less than
    /// two weeks of history or without growth.
    public func dailyRate(of assetID: String) -> Double? {
        guard let a = asset(assetID), !isComponent(a) else {
            if let m = activeMounting(ofComponent: assetID) { return dailyRate(of: m.hostID) }
            return nil
        }
        let points = meterPoints(of: assetID)
        guard let first = points.first, let last = points.last else { return nil }
        let days = DayDate.daysBetween(first.date, last.date)
        guard days >= 14, last.value > first.value else { return nil }
        return (last.value - first.value) / Double(days)
    }

    // MARK: Expenses

    public func totalCost(of assetID: String) -> Double {
        operations.filter { $0.assetID == assetID }.reduce(0) { $0 + ($1.cost ?? 0) }
    }

    public func lastOperation(of assetID: String) -> Operation? {
        operations(of: assetID).first
    }
}
