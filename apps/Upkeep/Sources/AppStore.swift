import Foundation
import Observation
import UpkeepCore

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let undo: (@MainActor () -> Void)?
}

enum AppTab: String, CaseIterable, Identifiable {
    case objects, deadlines, expenses, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .objects: return "Oggetti"
        case .deadlines: return "Scadenze"
        case .expenses: return "Spese"
        case .settings: return "Opzioni"
        }
    }

    var icon: String {
        switch self {
        case .objects: return "square.grid.2x2"
        case .deadlines: return "calendar.badge.clock"
        case .expenses: return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .objects: return "square.grid.2x2.fill"
        case .deadlines: return "calendar.badge.clock"
        case .expenses: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// App state: wraps `AppData` (UpkeepCore) and saves every change as JSON
/// in Application Support.
@MainActor
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var toast: ToastMessage?
    /// Refreshed when the app comes to the foreground.
    private(set) var today: DayDate = .today()
    /// Incremented on saves that deserve haptic feedback.
    private(set) var successCount = 0
    var errorMessage: String?
    var selectedTab: AppTab = .objects

    @ObservationIgnored private let fileStore: JSONFileStore<AppData>
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var reminderTask: Task<Void, Never>?

    init(fileURL: URL = AppStore.defaultFileURL) {
        fileStore = JSONFileStore(url: fileURL)
        do {
            if var saved = try fileStore.load() {
                saved.ensureTypes()
                data = saved
            } else {
                // First launch: built-in types, no objects (the home offers the sample data).
                data = Defaults.empty()
                try? fileStore.save(data)
            }
        } catch {
            // Never overwrite unreadable data: move it aside and start fresh.
            let backup = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            data = Defaults.empty()
            errorMessage = "I dati salvati non erano leggibili. Una copia è stata conservata come \(backup.lastPathComponent)."
        }
    }

    nonisolated static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Upkeep", isDirectory: true)
            .appendingPathComponent("data.json")
    }

    func refreshToday() {
        let now = DayDate.today()
        if now != today { today = now }
    }

    // MARK: - Mutations

    func update(_ change: (inout AppData) -> Void) {
        var copy = data
        change(&copy)
        guard copy != data else { return }
        data = copy
        do {
            try fileStore.save(data)
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error.localizedDescription)"
        }
        scheduleReminders()
    }

    /// Applies a change and shows a snackbar with "Annulla" restoring the previous data.
    func updateUndoable(_ message: String, _ change: (inout AppData) -> Void) {
        let before = data
        update(change)
        successCount += 1
        showToast(message) { [weak self] in self?.update { $0 = before } }
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) { update { change(&$0.settings) } }

    func replaceAll(with newData: AppData) {
        var d = newData
        d.ensureTypes()
        update { $0 = d }
    }

    func resetAll(withDemo: Bool) {
        refreshToday()
        let day = today
        update { $0.resetAll(withDemo: withDemo, today: day) }
    }

    func celebrate() { successCount += 1 }

    // MARK: - Reminders

    func scheduleReminders() {
        reminderTask?.cancel()
        let snapshot = data
        let day = today
        reminderTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await Notifier.reschedule(snapshot, today: day)
        }
    }

    // MARK: - Toast

    func showToast(_ text: String, undo: (@MainActor () -> Void)? = nil) {
        let message = ToastMessage(text: text, undo: undo)
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled else { return }
            self?.dismissToast(id: message.id)
        }
    }

    func dismissToast(id: UUID) {
        if toast?.id == id { toast = nil }
    }

    func performUndo() {
        guard let undo = toast?.undo else { return }
        toastTask?.cancel()
        toast = nil
        undo()
    }
}
