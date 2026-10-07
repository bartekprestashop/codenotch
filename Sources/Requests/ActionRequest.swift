import Foundation
import Darwin

/// The only data exchanged with agents. No transcript, credentials or chat contents.
struct ActionRequest: Codable, Identifiable, Equatable {
    let id: String
    let project: String
    let task: String
    let message: String
    let threadID: String
    let hostID: String?
    let createdAt: Date
    /// Distinguishes a newly opened request even if an ID is reused at the same time.
    /// Optional so records written by the first version remain readable.
    var generation: UUID?
    var expiresAt: Date
    var reminderClaimedAt: Date?

    var key: ActionRequestKey {
        ActionRequestKey(id: id, createdAt: createdAt, generation: generation)
    }

    var deepLink: URL? {
        guard UUID(uuidString: threadID) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.path = "/\(threadID)"
        if let hostID, !hostID.isEmpty {
            components.queryItems = [URLQueryItem(name: "hostId", value: hostID)]
        }
        return components.url
    }
}

/// A menu item keeps the generation as well as the reusable agent-side ID.
struct ActionRequestKey: Hashable {
    let id: String
    let createdAt: Date
    let generation: UUID?

    init(id: String, createdAt: Date, generation: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.generation = generation
    }
}

/// A single JSON document protected by an advisory lock and replaced atomically.
/// All writers, including the command-line tool, must use this type.
final class ActionRequestStore {
    let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Codenotch/ActionRequests", isDirectory: true)) {
        self.directory = directory
    }

    private var dataURL: URL { directory.appendingPathComponent("requests.json") }
    private var lockURL: URL { directory.appendingPathComponent("requests.lock") }

    func active(now: Date = Date()) throws -> [ActionRequest] {
        try locked {
            let all = try read()
            let current = all.filter { $0.expiresAt > now }
            if current.count != all.count { try write(current) }
            return current.sorted { $0.createdAt < $1.createdAt }
        }
    }

    @discardableResult
    func upsert(id: String, project: String, task: String, message: String,
                threadID: String, hostID: String? = nil, now: Date = Date(),
                lifetime: TimeInterval = 7 * 24 * 3600) throws -> ActionRequest {
        guard !id.isEmpty, id.count <= 160, UUID(uuidString: threadID) != nil,
              !project.isEmpty, !task.isEmpty, !message.isEmpty,
              project.count <= 120, task.count <= 160, message.count <= 500,
              (hostID?.count ?? 0) <= 120, lifetime > 0 else {
            throw StoreError.invalidRequest
        }
        return try locked {
            let all = try read()
            var requests = all.filter { $0.expiresAt > now }
            if let index = requests.firstIndex(where: { $0.id == id }) {
                // Idempotent retries retain the original deadline and reminder claim.
                if requests.count != all.count { try write(requests) }
                return requests[index]
            }
            let request = ActionRequest(id: id, project: project, task: task,
                message: message, threadID: threadID, hostID: hostID,
                createdAt: now, generation: UUID(), expiresAt: now.addingTimeInterval(lifetime),
                reminderClaimedAt: nil)
            requests.append(request)
            try write(requests)
            return request
        }
    }

    func resolve(id: String) throws {
        try locked {
            let requests = try read()
            let remaining = requests.filter { $0.id != id }
            if remaining.count != requests.count { try write(remaining) }
        }
    }

    @discardableResult
    func resolveIfCurrent(_ key: ActionRequestKey) throws -> Bool {
        try locked {
            var requests = try read()
            guard let index = requests.firstIndex(where: { $0.key == key }) else { return false }
            requests.remove(at: index)
            try write(requests)
            return true
        }
    }

    /// Claim before network I/O, so restarts and overlapping ticks send at most once.
    func claimReminders(now: Date, after delay: TimeInterval) throws -> [ActionRequest] {
        try locked {
            let all = try read()
            var requests = all.filter { $0.expiresAt > now }
            var claimed: [ActionRequest] = []
            for index in requests.indices where requests[index].reminderClaimedAt == nil
                && requests[index].createdAt.addingTimeInterval(delay) <= now {
                requests[index].reminderClaimedAt = now
                claimed.append(requests[index])
            }
            if !claimed.isEmpty || requests.count != all.count { try write(requests) }
            return claimed
        }
    }

    /// Starts transport while holding the same lock used by `resolve`.
    /// A completed resolution wins if it acquired the lock first. Once the
    /// transport starts, a later resolution can only request cancellation.
    func startClaimedDelivery<T>(for claimed: ActionRequest, now: Date,
                                 start: (ActionRequest) throws -> T) throws -> T? {
        try locked {
            guard let current = try read().first(where: {
                $0.key == claimed.key
                    && $0.reminderClaimedAt == claimed.reminderClaimedAt
                    && $0.reminderClaimedAt != nil && $0.expiresAt > now
            }) else { return nil }
            return try start(current)
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw StoreError.lockFailed }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StoreError.lockFailed }
        return try body()
    }

    private func read() throws -> [ActionRequest] {
        guard fileManager.fileExists(atPath: dataURL.path) else { return [] }
        return try JSONDecoder().decode([ActionRequest].self, from: Data(contentsOf: dataURL))
    }

    private func write(_ requests: [ActionRequest]) throws {
        let temporary = directory.appendingPathComponent(".requests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporary) }
        try JSONEncoder().encode(requests).write(to: temporary, options: [])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        guard rename(temporary.path, dataURL.path) == 0 else { throw StoreError.writeFailed }
    }

    enum StoreError: Error { case invalidRequest, lockFailed, writeFailed }
}
