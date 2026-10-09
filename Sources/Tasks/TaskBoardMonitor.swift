import AppKit
import Combine

@MainActor
final class TaskBoardMonitor: ObservableObject {
    @Published private(set) var tasks: [BoardTask] = []
    private let store: TaskBoardStore
    private var timer: Timer?
    private var lastModified: Date?

    init(store: TaskBoardStore = TaskBoardStore()) { self.store = store }

    func start() {
        tick(force: true)
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    func current(id: String) -> BoardTask? { try? store.active().first { $0.id == id } }

    func tick(force: Bool = false) {
        let modified = (try? store.dataURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        guard force || modified != lastModified else { return }
        do {
            let updated = try store.active()
            if tasks != updated { tasks = updated }
            lastModified = modified
        } catch {
            Log.usage.error("task board read failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
