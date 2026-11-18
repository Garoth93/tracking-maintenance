import Foundation

// MARK: - Parametric definitions

/// Kind of a user-defined field (e.g. "Targa" text, "Litri" number).
public enum FieldKind: String, Codable, CaseIterable, Sendable {
    case text
    case number

    public var label: String {
        switch self {
        case .text: return "Testo"
        case .number: return "Numero"
        }
    }
}

/// A custom attribute shown in the forms of an object type or operation type.
public struct FieldDefinition: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: FieldKind

    public init(id: String = newID(), name: String, kind: FieldKind = .text) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// Category of tracked objects: Auto, Bici, Sci, Pneumatici, Caldaia…
public struct AssetType: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// SF Symbol name.
    public var icon: String
    /// "#rrggbb"
    public var color: String
    /// Unit of the usage counter ("km", "ore", "uscite"…). Empty: no counter.
    public var meterUnit: String
    /// Objects of this type can be mounted on another object (e.g. wheels on a car)
    /// and accumulate the host's counter while mounted.
    public var isComponent: Bool
    public var fields: [FieldDefinition]

    public init(
        id: String = newID(),
        name: String,
        icon: String = "shippingbox.fill",
        color: String = "#6750a4",
        meterUnit: String = "",
        isComponent: Bool = false,
        fields: [FieldDefinition] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.meterUnit = meterUnit
        self.isComponent = isComponent
        self.fields = fields
    }

    public var tracksMeter: Bool { !meterUnit.trimmingCharacters(in: .whitespaces).isEmpty }
}

/// Default recurrence of an operation: every N months and/or every N units of the counter.
public struct Interval: Codable, Equatable, Hashable, Sendable {
    public var months: Int?
    public var meter: Double?

    public init(months: Int? = nil, meter: Double? = nil) {
        self.months = months
        self.meter = meter
    }

    public var isEmpty: Bool { (months ?? 0) <= 0 && (meter ?? 0) <= 0 }
}

/// Category of operation: Tagliando, Assicurazione, Cambio gomme, Sciolinatura…
public struct OperationType: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var icon: String
    public var color: String
    /// Object types this operation is offered for. Empty: every type.
    public var assetTypeIDs: [String]
    /// Default recurrence used to compute the next deadline. Empty: no deadline.
    public var interval: Interval
    public var fields: [FieldDefinition]

    public init(
        id: String = newID(),
        name: String,
        icon: String = "wrench.and.screwdriver.fill",
        color: String = "#6750a4",
        assetTypeIDs: [String] = [],
        interval: Interval = Interval(),
        fields: [FieldDefinition] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.assetTypeIDs = assetTypeIDs
        self.interval = interval
        self.fields = fields
    }

    public func applies(to assetTypeID: String) -> Bool {
        assetTypeIDs.isEmpty || assetTypeIDs.contains(assetTypeID)
    }
}

// MARK: - Records

/// A tracked object: a car, a pair of skis, a set of winter tyres…
public struct Asset: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var typeID: String
    public var name: String
    /// Optional overrides of the type's icon/color.
    public var icon: String?
    public var color: String?
    public var notes: String
    /// Counter value when the object was added (e.g. km of a used car).
    public var initialMeter: Double
    /// Values of the type's custom fields, keyed by `FieldDefinition.id`.
    public var attributes: [String: String]
    public var createdOn: DayDate
    public var archived: Bool
    public var order: Int

    public init(
        id: String = newID(),
        typeID: String,
        name: String,
        icon: String? = nil,
        color: String? = nil,
        notes: String = "",
        initialMeter: Double = 0,
        attributes: [String: String] = [:],
        createdOn: DayDate,
        archived: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.typeID = typeID
        self.name = name
        self.icon = icon
        self.color = color
        self.notes = notes
        self.initialMeter = initialMeter
        self.attributes = attributes
        self.createdOn = createdOn
        self.archived = archived
        self.order = order
    }
}

/// A manual counter update ("oggi l'auto ha 48.200 km").
public struct MeterReading: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var assetID: String
    public var date: DayDate
    public var value: Double
    public var note: String

    public init(id: String = newID(), assetID: String, date: DayDate, value: Double, note: String = "") {
        self.id = id
        self.assetID = assetID
        self.date = date
        self.value = value
        self.note = note
    }
}

/// A logged operation: Tagliando on 12 mar 2026 at 45.000 km, 320 €.
public struct Operation: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var assetID: String
    public var typeID: String
    public var date: DayDate
    public var meter: Double?
    public var cost: Double?
    public var notes: String
    public var attributes: [String: String]
    /// Explicit next deadline (e.g. the insurance expiry). Overrides the type interval.
    public var dueDate: DayDate?
    public var dueMeter: Double?
    /// When true this operation ends the recurrence (no next deadline).
    public var noFollowUp: Bool

    public init(
        id: String = newID(),
        assetID: String,
        typeID: String,
        date: DayDate,
        meter: Double? = nil,
        cost: Double? = nil,
        notes: String = "",
        attributes: [String: String] = [:],
        dueDate: DayDate? = nil,
        dueMeter: Double? = nil,
        noFollowUp: Bool = false
    ) {
        self.id = id
        self.assetID = assetID
        self.typeID = typeID
        self.date = date
        self.meter = meter
        self.cost = cost
        self.notes = notes
        self.attributes = attributes
        self.dueDate = dueDate
        self.dueMeter = dueMeter
        self.noFollowUp = noFollowUp
    }

    enum CodingKeys: String, CodingKey {
        case id, assetID, typeID, date, meter, cost, notes, attributes, dueDate, dueMeter, noFollowUp
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        assetID = try c.decode(String.self, forKey: .assetID)
        typeID = try c.decode(String.self, forKey: .typeID)
        date = try c.decode(DayDate.self, forKey: .date)
        meter = try c.decodeIfPresent(Double.self, forKey: .meter)
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        attributes = try c.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
        dueDate = try c.decodeIfPresent(DayDate.self, forKey: .dueDate)
        dueMeter = try c.decodeIfPresent(Double.self, forKey: .dueMeter)
        noFollowUp = try c.decodeIfPresent(Bool.self, forKey: .noFollowUp) ?? false
    }
}

/// A component (e.g. winter tyres) mounted on a host (e.g. the car) for a period.
/// While mounted, the component accumulates the host's counter.
public struct Mounting: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var componentID: String
    public var hostID: String
    public var startDate: DayDate
    public var startHostMeter: Double
    public var endDate: DayDate?
    public var endHostMeter: Double?

    public init(
        id: String = newID(),
        componentID: String,
        hostID: String,
        startDate: DayDate,
        startHostMeter: Double,
        endDate: DayDate? = nil,
        endHostMeter: Double? = nil
    ) {
        self.id = id
        self.componentID = componentID
        self.hostID = hostID
        self.startDate = startDate
        self.startHostMeter = startHostMeter
        self.endDate = endDate
        self.endHostMeter = endHostMeter
    }

    public var isActive: Bool { endDate == nil }
}

// MARK: - Settings

public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case auto, light, dark

    public var label: String {
        switch self {
        case .auto: return "Automatico"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var theme: ThemeMode
    /// Seed color of the Material palette.
    public var accent: String
    /// A deadline is "a breve" when it is at most this many days away…
    public var soonDays: Int
    /// …or when less than this percentage of its counter interval is left.
    public var soonMeterPercent: Int
    public var currencySymbol: String
    public var notificationsEnabled: Bool
    public var notifyDaysBefore: Int
    public var notifyHour: Int

    public init(
        theme: ThemeMode = .auto,
        accent: String = Palette.defaultAccent,
        soonDays: Int = 30,
        soonMeterPercent: Int = 10,
        currencySymbol: String = "€",
        notificationsEnabled: Bool = false,
        notifyDaysBefore: Int = 7,
        notifyHour: Int = 9
    ) {
        self.theme = theme
        self.accent = accent
        self.soonDays = soonDays
        self.soonMeterPercent = soonMeterPercent
        self.currencySymbol = currencySymbol
        self.notificationsEnabled = notificationsEnabled
        self.notifyDaysBefore = notifyDaysBefore
        self.notifyHour = notifyHour
    }

    enum CodingKeys: String, CodingKey {
        case theme, accent, soonDays, soonMeterPercent, currencySymbol, notificationsEnabled, notifyDaysBefore, notifyHour
    }

    public init(from decoder: Decoder) throws {
        let d = AppSettings()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decodeIfPresent(ThemeMode.self, forKey: .theme)) ?? d.theme
        accent = (try? c.decodeIfPresent(String.self, forKey: .accent)) ?? d.accent
        soonDays = (try? c.decodeIfPresent(Int.self, forKey: .soonDays)) ?? d.soonDays
        soonMeterPercent = (try? c.decodeIfPresent(Int.self, forKey: .soonMeterPercent)) ?? d.soonMeterPercent
        currencySymbol = (try? c.decodeIfPresent(String.self, forKey: .currencySymbol)) ?? d.currencySymbol
        notificationsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)) ?? d.notificationsEnabled
        notifyDaysBefore = (try? c.decodeIfPresent(Int.self, forKey: .notifyDaysBefore)) ?? d.notifyDaysBefore
        notifyHour = (try? c.decodeIfPresent(Int.self, forKey: .notifyHour)) ?? d.notifyHour
    }
}

// MARK: - Root

/// Everything the app stores. Saved as one JSON file and used as backup format.
public struct AppData: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var assetTypes: [AssetType]
    public var operationTypes: [OperationType]
    public var assets: [Asset]
    public var readings: [MeterReading]
    public var operations: [Operation]
    public var mountings: [Mounting]
    public var settings: AppSettings

    public init(
        assetTypes: [AssetType] = [],
        operationTypes: [OperationType] = [],
        assets: [Asset] = [],
        readings: [MeterReading] = [],
        operations: [Operation] = [],
        mountings: [Mounting] = [],
        settings: AppSettings = AppSettings()
    ) {
        version = AppData.currentVersion
        self.assetTypes = assetTypes
        self.operationTypes = operationTypes
        self.assets = assets
        self.readings = readings
        self.operations = operations
        self.mountings = mountings
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case version, assetTypes, operationTypes, assets, readings, operations, mountings, settings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? AppData.currentVersion
        // A backup must at least contain the objects list.
        assets = try c.decode([Asset].self, forKey: .assets)
        assetTypes = try c.decodeIfPresent([AssetType].self, forKey: .assetTypes) ?? []
        operationTypes = try c.decodeIfPresent([OperationType].self, forKey: .operationTypes) ?? []
        readings = try c.decodeIfPresent([MeterReading].self, forKey: .readings) ?? []
        operations = try c.decodeIfPresent([Operation].self, forKey: .operations) ?? []
        mountings = try c.decodeIfPresent([Mounting].self, forKey: .mountings) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}

public func newID() -> String { UUID().uuidString.lowercased() }
