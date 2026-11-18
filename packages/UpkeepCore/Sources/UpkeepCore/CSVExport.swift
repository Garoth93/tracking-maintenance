import Foundation

extension AppData {
    /// All operations as CSV (";" separated, Italian decimals), oldest first.
    public func operationsCSV() -> String {
        func cell(_ s: String) -> String {
            if s.contains(";") || s.contains("\"") || s.contains("\n") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        var lines = ["Data;Oggetto;Tipo oggetto;Operazione;Contatore;Unità;Costo;Prossima scadenza;Note"]
        let sorted = operations.sorted { $0.date != $1.date ? $0.date < $1.date : ($0.meter ?? 0) < ($1.meter ?? 0) }
        for o in sorted {
            let a = asset(o.assetID)
            let type = a.flatMap { self.type(of: $0) }
            let opName = operationType(o.typeID)?.name ?? ""
            let meter = o.meter.map { Fmt.editable($0, decimals: 1) } ?? ""
            let cost = o.cost.map { Fmt.editable($0, decimals: 2) } ?? ""
            var noteParts: [String] = []
            if let opType = operationType(o.typeID) {
                for f in opType.fields {
                    if let v = o.attributes[f.id], !v.isEmpty { noteParts.append("\(f.name): \(v)") }
                }
            }
            if !o.notes.isEmpty { noteParts.append(o.notes) }
            let row = [
                o.date.iso, a?.name ?? "", type?.name ?? "", opName, meter, type?.meterUnit ?? "",
                cost, o.dueDate?.iso ?? "", noteParts.joined(separator: " · ")
            ]
            lines.append(row.map(cell).joined(separator: ";"))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
