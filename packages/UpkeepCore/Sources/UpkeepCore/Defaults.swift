import Foundation

/// Built-in types (fully editable by the user) and the sample data.
public enum Defaults {
    public enum TypeID {
        public static let car = "type.car"
        public static let moto = "type.moto"
        public static let bike = "type.bike"
        public static let ski = "type.ski"
        public static let tyres = "type.tyres"
        public static let home = "type.home"
        public static let other = "type.other"
    }

    public static let assetTypes: [AssetType] = [
        AssetType(id: TypeID.car, name: "Auto", icon: "car.fill", color: "#0b57d0", meterUnit: "km", fields: [
            FieldDefinition(id: "f.car.plate", name: "Targa"),
            FieldDefinition(id: "f.car.model", name: "Modello"),
            FieldDefinition(id: "f.car.year", name: "Anno", kind: .number),
            FieldDefinition(id: "f.car.vin", name: "Telaio")
        ]),
        AssetType(id: TypeID.moto, name: "Moto", icon: "motorcycle", color: "#d84315", meterUnit: "km", fields: [
            FieldDefinition(id: "f.moto.plate", name: "Targa"),
            FieldDefinition(id: "f.moto.model", name: "Modello")
        ]),
        AssetType(id: TypeID.bike, name: "Bici", icon: "bicycle", color: "#2e7d32", meterUnit: "km", fields: [
            FieldDefinition(id: "f.bike.model", name: "Modello"),
            FieldDefinition(id: "f.bike.size", name: "Taglia")
        ]),
        AssetType(id: TypeID.ski, name: "Sci", icon: "figure.skiing.downhill", color: "#00796b", meterUnit: "uscite", fields: [
            FieldDefinition(id: "f.ski.model", name: "Modello"),
            FieldDefinition(id: "f.ski.length", name: "Lunghezza (cm)", kind: .number),
            FieldDefinition(id: "f.ski.din", name: "DIN attacchi", kind: .number)
        ]),
        AssetType(id: TypeID.tyres, name: "Pneumatici", icon: "circle.circle.fill", color: "#546e7a", meterUnit: "km", isComponent: true, fields: [
            FieldDefinition(id: "f.tyre.brand", name: "Marca e modello"),
            FieldDefinition(id: "f.tyre.size", name: "Misura"),
            FieldDefinition(id: "f.tyre.dot", name: "DOT")
        ]),
        AssetType(id: TypeID.home, name: "Casa e impianti", icon: "house.fill", color: "#ef6c00"),
        AssetType(id: TypeID.other, name: "Altro", icon: "shippingbox.fill", color: "#6750a4")
    ]

    public enum OpID {
        public static let service = "op.service"
        public static let oil = "op.oil"
        public static let inspection = "op.inspection"
        public static let insurance = "op.insurance"
        public static let tax = "op.tax"
        public static let tyreSwap = "op.tyreswap"
        public static let brakes = "op.brakes"
        public static let battery = "op.battery"
        public static let wash = "op.wash"
        public static let fuel = "op.fuel"
        public static let chainClean = "op.chainclean"
        public static let chainReplace = "op.chainreplace"
        public static let bikeService = "op.bikeservice"
        public static let wax = "op.wax"
        public static let edges = "op.edges"
        public static let bindings = "op.bindings"
        public static let rotation = "op.rotation"
        public static let balancing = "op.balancing"
        public static let boiler = "op.boiler"
        public static let repair = "op.repair"
        public static let other = "op.other"
    }

    public static let operationTypes: [OperationType] = {
        let motor = [TypeID.car, TypeID.moto]
        return [
            OperationType(id: OpID.service, name: "Tagliando", icon: "wrench.and.screwdriver.fill", color: "#0b57d0",
                          assetTypeIDs: motor, interval: Interval(months: 12, meter: 15000),
                          fields: [FieldDefinition(id: "f.op.shop", name: "Officina")]),
            OperationType(id: OpID.oil, name: "Cambio olio", icon: "oilcan.fill", color: "#5d4037",
                          assetTypeIDs: motor, interval: Interval(meter: 10000),
                          fields: [FieldDefinition(id: "f.op.oiltype", name: "Tipo olio")]),
            OperationType(id: OpID.inspection, name: "Revisione", icon: "checkmark.seal.fill", color: "#2e7d32",
                          assetTypeIDs: motor, interval: Interval(months: 24)),
            OperationType(id: OpID.insurance, name: "Assicurazione", icon: "shield.lefthalf.filled", color: "#3f51b5",
                          assetTypeIDs: motor, interval: Interval(months: 12),
                          fields: [FieldDefinition(id: "f.op.company", name: "Compagnia"),
                                   FieldDefinition(id: "f.op.policy", name: "N. polizza")]),
            OperationType(id: OpID.tax, name: "Bollo", icon: "doc.text.fill", color: "#ad1457",
                          assetTypeIDs: motor, interval: Interval(months: 12)),
            OperationType(id: OpID.tyreSwap, name: "Cambio gomme", icon: "circle.circle.fill", color: "#546e7a",
                          assetTypeIDs: motor),
            OperationType(id: OpID.brakes, name: "Freni", icon: "exclamationmark.octagon.fill", color: "#c62828",
                          assetTypeIDs: motor + [TypeID.bike]),
            OperationType(id: OpID.battery, name: "Batteria", icon: "battery.100percent", color: "#f9a825",
                          assetTypeIDs: motor),
            OperationType(id: OpID.wash, name: "Lavaggio", icon: "bubbles.and.sparkles.fill", color: "#00796b",
                          assetTypeIDs: motor + [TypeID.bike]),
            OperationType(id: OpID.fuel, name: "Rifornimento", icon: "fuelpump.fill", color: "#ef6c00",
                          assetTypeIDs: motor,
                          fields: [FieldDefinition(id: "f.op.liters", name: "Litri", kind: .number)]),
            OperationType(id: OpID.chainClean, name: "Pulizia catena", icon: "drop.fill", color: "#7cb342",
                          assetTypeIDs: [TypeID.bike], interval: Interval(meter: 500)),
            OperationType(id: OpID.chainReplace, name: "Cambio catena", icon: "link", color: "#2e7d32",
                          assetTypeIDs: [TypeID.bike], interval: Interval(meter: 3000)),
            OperationType(id: OpID.bikeService, name: "Revisione bici", icon: "gearshape.2.fill", color: "#0b57d0",
                          assetTypeIDs: [TypeID.bike], interval: Interval(months: 12)),
            OperationType(id: OpID.wax, name: "Sciolinatura", icon: "sparkles", color: "#00796b",
                          assetTypeIDs: [TypeID.ski], interval: Interval(meter: 5)),
            OperationType(id: OpID.edges, name: "Affilatura lamine", icon: "scissors", color: "#3f51b5",
                          assetTypeIDs: [TypeID.ski], interval: Interval(meter: 10)),
            OperationType(id: OpID.bindings, name: "Controllo attacchi", icon: "lock.shield.fill", color: "#c62828",
                          assetTypeIDs: [TypeID.ski], interval: Interval(months: 12)),
            OperationType(id: OpID.rotation, name: "Inversione", icon: "arrow.triangle.2.circlepath", color: "#546e7a",
                          assetTypeIDs: [TypeID.tyres], interval: Interval(meter: 10000)),
            OperationType(id: OpID.balancing, name: "Equilibratura", icon: "scalemass.fill", color: "#5d4037",
                          assetTypeIDs: [TypeID.tyres]),
            OperationType(id: OpID.boiler, name: "Manutenzione caldaia", icon: "flame.fill", color: "#ef6c00",
                          assetTypeIDs: [TypeID.home], interval: Interval(months: 12),
                          fields: [FieldDefinition(id: "f.op.tech", name: "Tecnico")]),
            OperationType(id: OpID.repair, name: "Riparazione", icon: "hammer.fill", color: "#d84315"),
            OperationType(id: OpID.other, name: "Altro", icon: "ellipsis.circle.fill", color: "#6750a4")
        ]
    }()

    public static func empty() -> AppData {
        AppData(assetTypes: assetTypes, operationTypes: operationTypes)
    }

    /// Sample garage relative to `today`, showing every feature.
    public static func demo(today: DayDate) -> AppData {
        var d = empty()
        func ago(_ n: Int) -> DayDate { today.adding(days: -n) }

        let car = Asset(id: "demo.car", typeID: TypeID.car, name: "Golf 8", notes: "Auto di tutti i giorni",
                        initialMeter: 12000,
                        attributes: ["f.car.plate": "GH 123 KL", "f.car.model": "Volkswagen Golf 1.5 TSI", "f.car.year": "2021"],
                        createdOn: ago(900), order: 0)
        let summer = Asset(id: "demo.summer", typeID: TypeID.tyres, name: "Gomme estive",
                           attributes: ["f.tyre.brand": "Michelin Pilot Sport 5", "f.tyre.size": "225/45 R17"],
                           createdOn: ago(900), order: 1)
        let winter = Asset(id: "demo.winter", typeID: TypeID.tyres, name: "Gomme invernali",
                           attributes: ["f.tyre.brand": "Pirelli Cinturato Winter 2", "f.tyre.size": "205/55 R16"],
                           createdOn: ago(400), order: 2)
        let bike = Asset(id: "demo.bike", typeID: TypeID.bike, name: "Bici da corsa",
                         attributes: ["f.bike.model": "Bianchi Specialissima", "f.bike.size": "55"],
                         createdOn: ago(500), order: 3)
        let ski = Asset(id: "demo.ski", typeID: TypeID.ski, name: "Sci all-mountain",
                        attributes: ["f.ski.model": "Rossignol Experience 86", "f.ski.length": "176", "f.ski.din": "8"],
                        createdOn: ago(700), order: 4)
        let boiler = Asset(id: "demo.boiler", typeID: TypeID.home, name: "Caldaia", notes: "Vaillant ecoTEC",
                           createdOn: ago(800), order: 5)
        d.assets = [car, summer, winter, bike, ski, boiler]

        d.readings = [
            MeterReading(assetID: car.id, date: ago(600), value: 22000),
            MeterReading(assetID: car.id, date: ago(200), value: 38500),
            MeterReading(assetID: car.id, date: ago(2), value: 46800),
            MeterReading(assetID: bike.id, date: ago(3), value: 6200),
            MeterReading(assetID: ski.id, date: ago(230), value: 18)
        ]

        d.mountings = [
            Mounting(componentID: summer.id, hostID: car.id, startDate: ago(900), startHostMeter: 12000,
                     endDate: ago(390), endHostMeter: 30000),
            Mounting(componentID: winter.id, hostID: car.id, startDate: ago(390), startHostMeter: 30000,
                     endDate: ago(210), endHostMeter: 38000),
            Mounting(componentID: summer.id, hostID: car.id, startDate: ago(210), startHostMeter: 38000)
        ]

        d.operations = [
            OperationRecord(assetID: car.id, typeID: OpID.service, date: ago(700), meter: 18000, cost: 260,
                      attributes: ["f.op.shop": "Officina Rossi"]),
            OperationRecord(assetID: car.id, typeID: OpID.service, date: ago(330), meter: 33000, cost: 310,
                      notes: "Filtri olio, aria e abitacolo", attributes: ["f.op.shop": "Officina Rossi"]),
            OperationRecord(assetID: car.id, typeID: OpID.insurance, date: ago(350), cost: 620,
                      attributes: ["f.op.company": "Assicura SpA"], dueDate: today.adding(days: 15)),
            OperationRecord(assetID: car.id, typeID: OpID.tax, date: ago(380), cost: 245),
            OperationRecord(assetID: car.id, typeID: OpID.inspection, date: ago(200), meter: 38400, cost: 79),
            OperationRecord(assetID: car.id, typeID: OpID.tyreSwap, date: ago(390), meter: 30000, cost: 40, notes: "Montate invernali"),
            OperationRecord(assetID: car.id, typeID: OpID.tyreSwap, date: ago(210), meter: 38000, cost: 40, notes: "Montate estive"),
            OperationRecord(assetID: car.id, typeID: OpID.fuel, date: ago(10), meter: 46500, cost: 68.4,
                      attributes: ["f.op.liters": "38,5"]),
            OperationRecord(assetID: summer.id, typeID: OpID.rotation, date: ago(210), meter: 18000, cost: 25),
            OperationRecord(assetID: bike.id, typeID: OpID.chainClean, date: ago(40), meter: 5400),
            OperationRecord(assetID: bike.id, typeID: OpID.chainReplace, date: ago(150), meter: 3500, cost: 45),
            OperationRecord(assetID: bike.id, typeID: OpID.bikeService, date: ago(300), cost: 90),
            OperationRecord(assetID: ski.id, typeID: OpID.wax, date: ago(240), meter: 14, cost: 20),
            OperationRecord(assetID: ski.id, typeID: OpID.edges, date: ago(400), meter: 8, cost: 35),
            OperationRecord(assetID: ski.id, typeID: OpID.bindings, date: ago(320), cost: 15),
            OperationRecord(assetID: boiler.id, typeID: OpID.boiler, date: ago(300), cost: 120,
                      attributes: ["f.op.tech": "Termoidraulica Bianchi"])
        ]
        return d
    }
}
