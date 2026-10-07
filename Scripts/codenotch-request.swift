import Foundation

@main
struct RequestCommand {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let command = arguments.first else { throw CommandError.usage }
            let store = ProcessInfo.processInfo.environment["CODENOTCH_REQUEST_DIRECTORY"]
                .map { ActionRequestStore(directory: URL(fileURLWithPath: $0, isDirectory: true)) }
                ?? ActionRequestStore()
            switch command {
            case "open":
                let options = try parse(Array(arguments.dropFirst()))
                guard let id = options["id"], let project = options["project"],
                      let task = options["task"], let message = options["message"],
                      let thread = options["thread"] ?? ProcessInfo.processInfo.environment["CODEX_THREAD_ID"]
                else { throw CommandError.usage }
                let request = try store.upsert(id: id, project: project, task: task,
                    message: message, threadID: thread,
                    hostID: options["host"] ?? ProcessInfo.processInfo.environment["CODEX_HOST_ID"])
                print(request.id)
            case "resolve":
                let options = try parse(Array(arguments.dropFirst()))
                guard let id = options["id"] else { throw CommandError.usage }
                try store.resolve(id: id)
            case "list":
                for request in try store.active() {
                    print("\(request.id)\t\(request.project)\t\(request.task)\t\(request.message)")
                }
            default: throw CommandError.usage
            }
        } catch {
            fputs("codenotch-request: \(error)\n", stderr)
            exit(2)
        }
    }

    private static func parse(_ arguments: [String]) throws -> [String: String] {
        guard arguments.count.isMultiple(of: 2) else { throw CommandError.usage }
        var options: [String: String] = [:]
        for index in stride(from: 0, to: arguments.count, by: 2) {
            let key = arguments[index]
            guard key.hasPrefix("--") else { throw CommandError.usage }
            options[String(key.dropFirst(2))] = arguments[index + 1]
        }
        return options
    }

    enum CommandError: Error {
        case usage
    }
}
