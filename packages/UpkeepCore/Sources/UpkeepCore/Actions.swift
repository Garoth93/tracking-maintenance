import Foundation

public enum DeleteBlock: Equatable, Sendable {
    case typeInUse(count: Int)

    public var message: String {
        switch self {
        case .typeInUse(let count):
            return count == 1 ? "È usato da 1 elemento." : "È usato da \(count) elementi."
        }
    }
}

extension AppData {
    // MARK: Types

    public mutating func saveAssetType(_ type: AssetType) {
        if let i = assetTypes.firstIndex(where: { $0.id == type.id }) {
            assetTypes[i] = type
        } else {
            assetTypes.append(type)
        }
    }

    /// Refuses to delete a type still used by objects.
    @discardableResult
    public mutating func deleteAssetType(id: String) -> DeleteBlock? {
        let used = assets.filter { $0.typeID == id }.count
        if used > 0 { return .typeInUse(count: used) }
        assetTypes.removeAll { $0.id == id }
        for i in operationTypes.indices { operationTypes[i].assetTypeIDs.removeAll { $0 == id } }
        return nil
    }

    public mutating func saveOperationType(_ type: OperationType) {
        if let i = operationTypes.firstIndex(where: { $0.id == type.id }) {
            operationTypes[i] = type
        } else {
            operationTypes.append(type)
        }
    }

    /// Refuses to delete a type still used by logged operations.
    @discardableResult
    public mutating func deleteOperationType(id: String) -> DeleteBlock? {
        let used = operations.filter { $0.typeID == id }.count
        if used > 0 { return .typeInUse(count: used) }
        operationTypes.removeAll { $0.id == id }
        return nil
    }

    public mutating func moveAssetType(fromOffsets source: IndexSet, toOffset destination: Int) {
        assetTypes.moveElements(fromOffsets: source, toOffset: destination)
    }

    public mutating func moveOperationType(fromOffsets source: IndexSet, toOffset destination: Int) {
        operationTypes.moveElements(fromOffsets: source, toOffset: destination)
    }

    // MARK: Objects

    public mutating func saveAsset(_ asset: Asset) {
        if let i = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[i] = asset
        } else {
            var new = asset
            new.order = (assets.map(\.order).max() ?? -1) + 1
            assets.append(new)
        }
    }

    /// Deletes an object with its readings, operations and mount history.
    /// Components that were mounted on it keep the distance they accumulated.
    public mutating func deleteAsset(id: String) {
        let hosted = Set(mountings.filter { $0.hostID == id }.map(\.componentID))
        for componentID in hosted {
            let kept = mountings.filter { $0.componentID == componentID && $0.hostID == id }
                .reduce(0.0) { $0 + distance(of: $1) }
            if let i = assets.firstIndex(where: { $0.id == componentID }) { assets[i].initialMeter += kept }
        }
        assets.removeAll { $0.id == id }
        readings.removeAll { $0.assetID == id }
        operations.removeAll { $0.assetID == id }
        mountings.removeAll { $0.hostID == id || $0.componentID == id }
    }

    public mutating func setArchived(_ archived: Bool, assetID: String, today: DayDate) {
        guard let i = assets.firstIndex(where: { $0.id == assetID }) else { return }
        assets[i].archived = archived
        if archived, activeMounting(ofComponent: assetID) != nil {
            unmount(componentID: assetID, date: today)
        }
    }

    /// Reorders visible objects (indexes refer to `sortedAssets()`).
    public mutating func moveAssets(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = sortedAssets(includeArchived: true)
        ordered.moveElements(fromOffsets: source, toOffset: destination)
        for (n, a) in ordered.enumerated() {
            if let i = assets.firstIndex(where: { $0.id == a.id }) { assets[i].order = n }
        }
    }

    // MARK: Counter

    @discardableResult
    public mutating func addReading(assetID: String, date: DayDate, value: Double, note: String = "") -> String {
        let r = MeterReading(assetID: assetID, date: date, value: value, note: note)
        readings.append(r)
        return r.id
    }

    public mutating func deleteReading(id: String) {
        readings.removeAll { $0.id == id }
    }

    // MARK: Operations

    public mutating func saveOperation(_ op: Operation) {
        if let i = operations.firstIndex(where: { $0.id == op.id }) {
            operations[i] = op
        } else {
            operations.append(op)
        }
    }

    public mutating func deleteOperation(id: String) {
        operations.removeAll { $0.id == id }
    }

    // MARK: Mounting

    /// Mounts a component on a host at `date` with the host counter at `hostMeter`
    /// (default: its current value). The component is first removed from any
    /// other host; with `replaceSameType`, components of the same type already
    /// on the host are removed (summer → winter tyres swap).
    /// Returns the names of the components that were removed.
    @discardableResult
    public mutating func mount(
        componentID: String,
        on hostID: String,
        date: DayDate,
        hostMeter: Double? = nil,
        replaceSameType: Bool = true
    ) -> [String] {
        guard componentID != hostID, let component = asset(componentID), asset(hostID) != nil else { return [] }
        let startMeter = hostMeter ?? meter(of: hostID)
        if let current = activeMounting(ofComponent: componentID) {
            if current.hostID == hostID { return [] }
            unmount(componentID: componentID, date: date)
        }
        var replaced: [String] = []
        if replaceSameType {
            for other in activeComponents(onHost: hostID) where other.typeID == component.typeID {
                unmount(componentID: other.id, date: date, hostMeter: startMeter)
                replaced.append(other.name)
            }
        }
        mountings.append(Mounting(componentID: componentID, hostID: hostID, startDate: date, startHostMeter: startMeter))
        return replaced
    }

    /// Ends the active mount period of a component.
    public mutating func unmount(componentID: String, date: DayDate, hostMeter: Double? = nil) {
        guard let i = mountings.firstIndex(where: { $0.componentID == componentID && $0.isActive }) else { return }
        let end = hostMeter ?? meter(of: mountings[i].hostID)
        mountings[i].endDate = max(date, mountings[i].startDate)
        mountings[i].endHostMeter = max(end, mountings[i].startHostMeter)
    }

    public mutating func saveMounting(_ mounting: Mounting) {
        if let i = mountings.firstIndex(where: { $0.id == mounting.id }) {
            mountings[i] = mounting
        } else {
            mountings.append(mounting)
        }
    }

    public mutating func deleteMounting(id: String) {
        mountings.removeAll { $0.id == id }
    }

    // MARK: Whole data

    /// Fills in missing default types (used after importing a backup without types).
    public mutating func ensureTypes() {
        if assetTypes.isEmpty { assetTypes = Defaults.assetTypes }
        if operationTypes.isEmpty { operationTypes = Defaults.operationTypes }
        // Objects whose type is missing get a placeholder type so they stay visible.
        let known = Set(assetTypes.map(\.id))
        for typeID in Set(assets.map(\.typeID)) where !known.contains(typeID) {
            assetTypes.append(AssetType(id: typeID, name: "Tipo importato", icon: "questionmark.square.dashed", color: "#546e7a"))
        }
        let knownOps = Set(operationTypes.map(\.id))
        for typeID in Set(operations.map(\.typeID)) where !knownOps.contains(typeID) {
            operationTypes.append(OperationType(id: typeID, name: "Operazione importata", icon: "questionmark.circle", color: "#546e7a"))
        }
    }

    public mutating func resetAll(withDemo: Bool, today: DayDate) {
        let keptSettings = settings
        self = withDemo ? Defaults.demo(today: today) : Defaults.empty()
        settings = keptSettings
    }
}

extension Array {
    /// `MutableCollection.move(fromOffsets:toOffset:)` without SwiftUI.
    mutating func moveElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { self[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { remove(at: index) }
        insert(contentsOf: moving, at: Swift.max(0, Swift.min(count, destination - before)))
    }
}
