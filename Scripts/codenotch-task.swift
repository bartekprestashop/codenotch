import Foundation

@main
struct TaskBoardCommand {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let command = arguments.first else { throw CommandError.usage }
            let store = ProcessInfo.processInfo.environment["CODENOTCH_TASK_DIRECTORY"]
                .map { TaskBoardStore(directory: URL(fileURLWithPath: $0, isDirectory: true)) }
                ?? TaskBoardStore()
            let options = try parse(Array(arguments.dropFirst()))
            switch command {
            case "upsert":
                guard let id = options["id"], let title = options["title"],
                      let thread = options["thread"] ?? ProcessInfo.processInfo.environment["CODEX_THREAD_ID"]
                else { throw CommandError.usage }
                let total = try number(options["total"])
                let completed = try number(options["completed"])
                let conversation = BoardConversation(threadID: thread,
                    hostID: options["host"] ?? ProcessInfo.processInfo.environment["CODEX_HOST_ID"])
                let task = try store.upsert(id: id, title: title, coordinator: conversation,
                                            total: total, completed: completed)
                print(task.id)
            case "progress":
                guard let id = options["id"], let completed = try number(options["completed"]) else {
                    throw CommandError.usage
                }
                _ = try store.progress(id: id, completed: completed, total: try number(options["total"]))
            case "add-thread":
                guard let id = options["id"], let thread = options["thread"] else {
                    throw CommandError.usage
                }
                _ = try store.addConversation(id: id,
                    conversation: BoardConversation(threadID: thread, hostID: options["host"]))
            case "signal":
                guard let id = options["id"], let value = options["value"],
                      let signal = TaskSignal(rawValue: value) else { throw CommandError.usage }
                guard signal != .none || options["thread"] == nil else { throw CommandError.usage }
                let source = options["thread"].map { BoardConversation(threadID: $0, hostID: options["host"]) }
                _ = try store.setSignal(id: id, signal: signal, source: source)
            case "complete", "resume":
                guard let id = options["id"] else { throw CommandError.usage }
                _ = try store.setLifecycle(id: id,
                    lifecycle: command == "complete" ? .completed : .active)
            case "list":
                let tasks = try (options["all"] == "true" ? store.all() : store.active())
                for task in tasks {
                    print("\(task.id)\t\(task.lifecycle.rawValue)\t\(task.completed)/\(task.total)\t\(task.signal.rawValue)\t\(task.title)\t\(task.updatedAt)")
                }
            default: throw CommandError.usage
            }
        } catch {
            fputs("codenotch-task: \(error)\n", stderr)
            exit(2)
        }
    }

    private static func number(_ value: String?) throws -> Int? {
        guard let value else { return nil }
        guard let result = Int(value) else { throw CommandError.usage }
        return result
    }

    private static func parse(_ arguments: [String]) throws -> [String: String] {
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--") else { throw CommandError.usage }
            let name = String(key.dropFirst(2))
            if name == "all" {
                options[name] = "true"
                index += 1
                continue
            }
            guard index + 1 < arguments.count, options[name] == nil else {
                throw CommandError.usage
            }
            options[name] = arguments[index + 1]
            index += 2
        }
        return options
    }

    enum CommandError: Error { case usage }
}
