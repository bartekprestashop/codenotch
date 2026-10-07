import AppKit
import Combine
import Security

protocol ReminderCancelable {
    func cancel()
}

extension URLSessionTask: ReminderCancelable {}

/// start must begin transport synchronously before returning. The store
/// calls it while holding the same lock as agent-side resolution.
protocol ReminderTransport {
    func start(_ request: ActionRequest, token: String, chatID: String,
               completion: @escaping (Bool) -> Void) throws -> any ReminderCancelable
}

struct URLSessionReminderTransport: ReminderTransport {
    func start(_ request: ActionRequest, token: String, chatID: String,
               completion: @escaping (Bool) -> Void) throws -> any ReminderCancelable {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            throw TransportError.invalidURL
        }
        var post = URLRequest(url: url)
        post.httpMethod = "POST"
        post.timeoutInterval = 15
        post.setValue("application/json", forHTTPHeaderField: "Content-Type")
        post.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": chatID,
            "text": "Codenotch: \(request.project) — \(request.task)\n\(request.message)\nOpen the request in the Mac notch."
        ])
        let task = URLSession.shared.dataTask(with: post) { _, response, error in
            completion(error == nil && (response as? HTTPURLResponse)?.statusCode == 200)
        }
        task.resume()
        return task
    }

    enum TransportError: Error { case invalidURL }
}

private enum TelegramKeychain {
    static func value(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.vinz.codenotch.telegram",
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

@MainActor
final class ActionRequestMonitor: ObservableObject {
    private struct Delivery {
        let request: ActionRequest
        let task: any ReminderCancelable
    }
    @Published private(set) var requests: [ActionRequest] = []
    private let store: ActionRequestStore
    private let defaults: UserDefaults
    private let transport: any ReminderTransport
    private let credentials: () -> (token: String, chatID: String)?
    private var timer: Timer?
    private var lastModified: Date?
    private var inFlight: [String: Delivery] = [:]
    private var hasLoadedRequests = false
    var onNewRequests: (() -> Void)?

    init(store: ActionRequestStore = ActionRequestStore(), defaults: UserDefaults = .standard,
         transport: any ReminderTransport = URLSessionReminderTransport(),
         credentials: (() -> (token: String, chatID: String)?)? = nil) {
        self.store = store
        self.defaults = defaults
        self.transport = transport
        self.credentials = credentials ?? {
            guard let token = TelegramKeychain.value(account: "bot-token"),
                  let chatID = TelegramKeychain.value(account: "chat-id") else { return nil }
            return (token, chatID)
        }
    }

    var reminderDelay: TimeInterval {
        let minutes = defaults.integer(forKey: "actionReminderMinutes")
        return TimeInterval(min(1440, max(5, minutes == 0 ? 15 : minutes))) * 60
    }

    func start() {
        tick(force: true)
        // Metadata check is cheap, and catches atomic replacements by any agent.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for delivery in inFlight.values { delivery.task.cancel() }
        inFlight.removeAll()
    }

    func current(id: String) -> ActionRequest? {
        try? store.active().first { $0.id == id }
    }

    func resolve(_ key: ActionRequestKey) {
        do {
            guard try store.resolveIfCurrent(key) else { return }
            inFlight.removeValue(forKey: key.id)?.task.cancel()
            tick(force: true)
        } catch {
            Log.usage.error("request resolution failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Internal to allow deterministic clock and fake transport in tests.
    func tick(now: Date = Date(), force: Bool = false) {
        let url = store.directory.appendingPathComponent("requests.json")
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if force || modified != lastModified || requests.contains(where: { $0.expiresAt <= now }) {
            do {
                let previousKeys = Set(requests.map(\.key))
                let updated = try store.active(now: now)
                let hasNewRequest = hasLoadedRequests
                    && updated.contains(where: { !previousKeys.contains($0.key) })
                requests = updated
                hasLoadedRequests = true
                lastModified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if hasNewRequest { onNewRequests?() }
            } catch {
                Log.usage.error("request read failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        for (id, delivery) in Array(inFlight) {
            let stillSameRequest = requests.contains {
                $0.key == delivery.request.key
                    && $0.reminderClaimedAt == delivery.request.reminderClaimedAt
            }
            if !stillSameRequest { inFlight.removeValue(forKey: id)?.task.cancel() }
        }
        sendDueReminders(now: now)
    }

    private func sendDueReminders(now: Date) {
        guard requests.contains(where: {
            $0.reminderClaimedAt == nil && $0.expiresAt > now
                && $0.createdAt.addingTimeInterval(reminderDelay) <= now
        }), let (token, chatID) = credentials() else { return }

        let due: [ActionRequest]
        do { due = try store.claimReminders(now: now, after: reminderDelay) }
        catch {
            Log.usage.error("reminder claim failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        for claimed in due {
            do {
                // Resolution and transport start are ordered by one file lock.
                // After start returns, cancellation is best effort: Telegram
                // may already have accepted the request.
                if let task = try store.startClaimedDelivery(for: claimed, now: now, start: { current in
                    try transport.start(current, token: token, chatID: chatID) { [weak self] succeeded in
                        Task { @MainActor [weak self] in
                            if let delivery = self?.inFlight[current.id],
                               delivery.request.key == current.key,
                               delivery.request.reminderClaimedAt == current.reminderClaimedAt {
                                self?.inFlight.removeValue(forKey: current.id)
                            }
                            if !succeeded { Log.usage.error("Telegram reminder failed") }
                        }
                    }
                }) {
                    inFlight[claimed.id] = Delivery(request: claimed, task: task)
                }
            } catch {
                Log.usage.error("Telegram reminder could not start")
            }
        }
    }
}
