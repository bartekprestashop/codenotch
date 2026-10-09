import Foundation
import Darwin

enum TaskSignal: String, Codable, CaseIterable {
    case none, problem, blocked, needs_user, paused
}

enum TaskLifecycle: String, Codable {
    case active, completed
}

enum TaskSubstatus: String, Codable, CaseIterable {
    case preparation, coding, qa

    var title: String {
        switch self {
        case .preparation: return "Przygotowanie"
        case .coding: return "Kodowanie"
        case .qa: return "QA"
        }
    }
}

struct BoardConversation: Codable, Equatable {
    let threadID: String
    let hostID: String?

    var deepLink: URL? {
        guard UUID(uuidString: threadID) != nil else { return nil }
        var parts = URLComponents()
        parts.scheme = "codex"
        parts.host = "threads"
        parts.path = "/\(threadID)"
        if let hostID, !hostID.isEmpty {
            parts.queryItems = [URLQueryItem(name: "hostId", value: hostID)]
        }
        return parts.url
    }
}

struct BoardTask: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var completed: Int
    var total: Int
    var lifecycle: TaskLifecycle
    var signal: TaskSignal
    var substatus: TaskSubstatus
    var conversations: [BoardConversation]
    var coordinatorThreadID: String
    var signalThreadID: String?
    let createdAt: Date
    var updatedAt: Date

    var openThreadID: String {
        signal == .none ? coordinatorThreadID : (signalThreadID ?? coordinatorThreadID)
    }

    var deepLink: URL? {
        conversations.first { $0.threadID == openThreadID }?.deepLink
    }
}

extension BoardTask {
    private enum CodingKeys: String, CodingKey {
        case id, title, completed, total, lifecycle, signal, substatus, conversations
        case coordinatorThreadID, signalThreadID, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        completed = try values.decode(Int.self, forKey: .completed)
        total = try values.decode(Int.self, forKey: .total)
        lifecycle = try values.decode(TaskLifecycle.self, forKey: .lifecycle)
        signal = try values.decode(TaskSignal.self, forKey: .signal)
        substatus = try values.decodeIfPresent(TaskSubstatus.self, forKey: .substatus) ?? .preparation
        conversations = try values.decode([BoardConversation].self, forKey: .conversations)
        coordinatorThreadID = try values.decode(String.self, forKey: .coordinatorThreadID)
        signalThreadID = try values.decodeIfPresent(String.self, forKey: .signalThreadID)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
    }
}

struct TaskBoardDocument: Codable, Equatable {
    var schemaVersion = 1
    var tasks: [BoardTask] = []
}

/// Separate from ActionRequestStore: task signals never enter reminder delivery.
final class TaskBoardStore {
    enum StoreError: Error {
        case invalidTask, unknownTask, unsupportedSchema, invalidDocument, lockFailed, writeFailed
    }

    let directory: URL
    private let files = FileManager.default

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Codenotch/ActionRequests", isDirectory: true)) {
        self.directory = directory
    }

    var dataURL: URL { directory.appendingPathComponent("task-board.json") }
    private var lockURL: URL { directory.appendingPathComponent("task-board.lock") }

    func all() throws -> [BoardTask] { try locked { try read().tasks } }
    func active() throws -> [BoardTask] {
        try all().filter { $0.lifecycle == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func upsert(id: String, title: String, coordinator: BoardConversation,
                total: Int? = nil, completed: Int? = nil,
                now: Date = Date()) throws -> BoardTask {
        guard validID(id), validTitle(title), validConversation(coordinator) else {
            throw StoreError.invalidTask
        }
        return try mutate(now: now) { document in
            if let index = document.tasks.firstIndex(where: { $0.id == id }) {
                var task = document.tasks[index]
                let nextTotal = total ?? task.total
                let nextCompleted = completed ?? task.completed
                guard (1...1000).contains(nextTotal), (0...nextTotal).contains(nextCompleted) else {
                    throw StoreError.invalidTask
                }
                task.title = title
                task.total = nextTotal
                task.completed = nextCompleted
                if let old = task.conversations.firstIndex(where: { $0.threadID == coordinator.threadID }) {
                    task.conversations[old] = coordinator
                } else {
                    task.conversations.append(coordinator)
                }
                task.coordinatorThreadID = coordinator.threadID
                document.tasks[index] = task
                return index
            }
            let initialTotal = total ?? 5
            let initialCompleted = completed ?? 0
            guard (1...1000).contains(initialTotal), (0...initialTotal).contains(initialCompleted) else {
                throw StoreError.invalidTask
            }
            document.tasks.append(BoardTask(id: id, title: title, completed: initialCompleted,
                total: initialTotal, lifecycle: .active, signal: .none, substatus: .preparation,
                conversations: [coordinator], coordinatorThreadID: coordinator.threadID,
                signalThreadID: nil, createdAt: now, updatedAt: now))
            return document.tasks.count - 1
        }
    }

    @discardableResult
    func progress(id: String, completed: Int, total: Int? = nil,
                  now: Date = Date()) throws -> BoardTask {
        try mutate(now: now) { document in
            let index = try self.index(id, in: document)
            let targetTotal = total ?? document.tasks[index].total
            guard (1...1000).contains(targetTotal), (0...targetTotal).contains(completed) else {
                throw StoreError.invalidTask
            }
            document.tasks[index].total = targetTotal
            document.tasks[index].completed = completed
            return index
        }
    }

    @discardableResult
    func setSubstatus(id: String, substatus: TaskSubstatus, now: Date = Date()) throws -> BoardTask {
        try mutate(now: now) { document in
            let index = try self.index(id, in: document)
            document.tasks[index].substatus = substatus
            return index
        }
    }

    @discardableResult
    func addConversation(id: String, conversation: BoardConversation,
                         now: Date = Date()) throws -> BoardTask {
        guard validConversation(conversation) else { throw StoreError.invalidTask }
        return try mutate(now: now) { document in
            let index = try self.index(id, in: document)
            if let old = document.tasks[index].conversations.firstIndex(where: {
                $0.threadID == conversation.threadID
            }) {
                document.tasks[index].conversations[old] = conversation
            } else {
                document.tasks[index].conversations.append(conversation)
            }
            return index
        }
    }

    @discardableResult
    func setSignal(id: String, signal: TaskSignal, source: BoardConversation? = nil,
                   now: Date = Date()) throws -> BoardTask {
        guard source == nil || validConversation(source!) else { throw StoreError.invalidTask }
        return try mutate(now: now) { document in
            let index = try self.index(id, in: document)
            document.tasks[index].signal = signal
            if signal == .none {
                document.tasks[index].signalThreadID = nil
            } else if let source {
                if let old = document.tasks[index].conversations.firstIndex(where: { $0.threadID == source.threadID }) {
                    document.tasks[index].conversations[old] = source
                } else {
                    document.tasks[index].conversations.append(source)
                }
                document.tasks[index].signalThreadID = source.threadID
            } else {
                document.tasks[index].signalThreadID = nil
            }
            return index
        }
    }

    @discardableResult
    func setLifecycle(id: String, lifecycle: TaskLifecycle,
                      now: Date = Date()) throws -> BoardTask {
        try mutate(now: now) { document in
            let index = try self.index(id, in: document)
            document.tasks[index].lifecycle = lifecycle
            return index
        }
    }

    private func index(_ id: String, in document: TaskBoardDocument) throws -> Int {
        guard let index = document.tasks.firstIndex(where: { $0.id == id }) else {
            throw StoreError.unknownTask
        }
        return index
    }

    private func mutate(now: Date, _ body: (inout TaskBoardDocument) throws -> Int) throws -> BoardTask {
        try locked {
            var document = try read()
            let before = document
            let index = try body(&document)
            try validate(document)
            if document != before {
                // Retrying an identical command neither rewrites the file nor changes the date.
                document.tasks[index].updatedAt = now
                try write(document)
            }
            return document.tasks[index]
        }
    }

    private func validID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 160
            && !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.controlCharacters.contains($0) })
    }
    private func validTitle(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= 160
            && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }
    private func validConversation(_ value: BoardConversation) -> Bool {
        UUID(uuidString: value.threadID) != nil && (value.hostID?.count ?? 0) <= 120
            && !(value.hostID?.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            }) ?? false)
    }

    private func validate(_ document: TaskBoardDocument) throws {
        guard document.schemaVersion == 1 else { throw StoreError.unsupportedSchema }
        var ids = Set<String>()
        for task in document.tasks {
            let threadIDs = task.conversations.map(\.threadID)
            guard validID(task.id), ids.insert(task.id).inserted, validTitle(task.title),
                  (1...1000).contains(task.total), (0...task.total).contains(task.completed),
                  !threadIDs.isEmpty, Set(threadIDs).count == threadIDs.count,
                  task.conversations.allSatisfy(validConversation),
                  threadIDs.contains(task.coordinatorThreadID),
                  task.signalThreadID.map(threadIDs.contains) ?? true,
                  task.createdAt <= task.updatedAt else { throw StoreError.invalidDocument }
        }
    }

    private func read() throws -> TaskBoardDocument {
        guard files.fileExists(atPath: dataURL.path) else { return TaskBoardDocument() }
        let document = try JSONDecoder().decode(TaskBoardDocument.self, from: Data(contentsOf: dataURL))
        try validate(document)
        return document
    }

    private func write(_ document: TaskBoardDocument) throws {
        let temporary = directory.appendingPathComponent(".task-board-\(UUID().uuidString)")
        defer { try? files.removeItem(at: temporary) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: temporary)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        guard rename(temporary.path, dataURL.path) == 0 else { throw StoreError.writeFailed }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw StoreError.lockFailed }
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StoreError.lockFailed }
        return try body()
    }
}
