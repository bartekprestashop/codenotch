import XCTest
import AppKit
@testable import Codenotch

final class ActionRequestTests: XCTestCase {
    private func scratch() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testDuplicateKeepsFirstDeadlineAndOnlyOneReminder() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString
        let first = try store.upsert(id: "approval-1", project: "Codenotch", task: "Release",
            message: "Choose a version", threadID: thread, now: start, lifetime: 3600)
        let duplicate = try store.upsert(id: "approval-1", project: "Changed", task: "Changed",
            message: "Changed", threadID: thread, now: start.addingTimeInterval(60))
        XCTAssertEqual(first, duplicate)
        XCTAssertTrue(try store.claimReminders(now: start.addingTimeInterval(119), after: 120).isEmpty)
        XCTAssertEqual(try store.claimReminders(now: start.addingTimeInterval(120), after: 120).count, 1)
        XCTAssertTrue(try store.claimReminders(now: start.addingTimeInterval(121), after: 120).isEmpty)
    }

    func testResolveCancelsReminderAndExpiryHidesEntry() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString
        try store.upsert(id: "one", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 100)
        try store.resolve(id: "one")
        try store.resolve(id: "one")
        XCTAssertTrue(try store.claimReminders(now: start.addingTimeInterval(50), after: 10).isEmpty)
        try store.upsert(id: "two", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 100)
        XCTAssertTrue(try store.active(now: start.addingTimeInterval(100)).isEmpty)
        XCTAssertTrue(try store.claimReminders(now: start.addingTimeInterval(100), after: 10).isEmpty)
    }

    func testDeepLinkUsesThreadAndOptionalHost() throws {
        let store = ActionRequestStore(directory: scratch())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let thread = UUID().uuidString
        let request = try store.upsert(id: "a", project: "A", task: "B", message: "C",
                                       threadID: thread, hostID: "local")
        XCTAssertEqual(request.deepLink?.scheme, "codex")
        XCTAssertEqual(request.deepLink?.host, "threads")
        XCTAssertEqual(request.deepLink?.path, "/\(thread)")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.deepLink),
                                     resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "local")
    }

    func testConcurrentWritersPreserveDistinctRequests() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let thread = UUID().uuidString
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            do {
                _ = try store.upsert(id: "decision-\(index)", project: "A",
                    task: "B", message: "C", threadID: thread)
            } catch {
                XCTFail("Concurrent write \(index) failed: \(error)")
            }
        }
        XCTAssertEqual(try store.active().count, 20)
    }

    func testRecordsWithoutGenerationRemainReadable() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let created = try store.upsert(id: "old", project: "A", task: "B", message: "C",
                                       threadID: UUID().uuidString)
        let file = directory.appendingPathComponent("requests.json")
        var records = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file))
                                    as? [[String: Any]])
        records[0].removeValue(forKey: "generation")
        try JSONSerialization.data(withJSONObject: records).write(to: file)
        let decoded = try XCTUnwrap(store.active().first)
        XCTAssertEqual(decoded.id, created.id)
        XCTAssertNil(decoded.generation)
    }

    func testReadingPrunesOnlyExpiredEntriesFromDisk() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString
        try store.upsert(id: "expired", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 30)
        try store.upsert(id: "active", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 300)
        XCTAssertEqual(try store.active(now: start.addingTimeInterval(30)).map(\.id), ["active"])
        let saved = try JSONDecoder().decode([ActionRequest].self,
            from: Data(contentsOf: directory.appendingPathComponent("requests.json")))
        XCTAssertEqual(saved.map(\.id), ["active"])
    }

    func testResolutionOrReusedIDBeforeTransportStartCancelsOldClaim() throws {
        let directory = scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString
        try store.upsert(id: "decision", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 300)
        let claimed = try XCTUnwrap(store.claimReminders(now: start.addingTimeInterval(60), after: 60).first)
        try store.resolve(id: "decision")
        try store.upsert(id: "decision", project: "A", task: "New", message: "New",
                         threadID: thread, now: start, lifetime: 300)
        XCTAssertFalse(try store.resolveIfCurrent(claimed.key))
        var started = false
        let result: Bool? = try store.startClaimedDelivery(for: claimed,
            now: start.addingTimeInterval(62)) { _ in started = true; return true }
        XCTAssertNil(result)
        XCTAssertFalse(started)
        XCTAssertEqual(try store.active(now: start.addingTimeInterval(62)).first?.task, "New")
    }

}

private final class FakeReminderTask: ReminderCancelable {
    private(set) var cancelled = false
    func cancel() { cancelled = true }
}

private final class FakeReminderTransport: ReminderTransport {
    private(set) var sentIDs: [String] = []
    private(set) var tasks: [String: FakeReminderTask] = [:]

    func start(_ request: ActionRequest, token: String, chatID: String,
               completion: @escaping (Bool) -> Void) throws -> any ReminderCancelable {
        sentIDs.append(request.id)
        let task = FakeReminderTask()
        tasks[request.id] = task
        return task
    }
}

@MainActor
final class ActionRequestMonitorTests: XCTestCase {
    func testSoundOnlyForNewRequestsAfterInitialLoad() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let monitor = ActionRequestMonitor(store: store, credentials: { nil })
        var chimes = 0
        monitor.onNewRequests = { chimes += 1 }
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString

        try store.upsert(id: "first", project: "A", task: "B", message: "C",
                         threadID: thread, now: start, lifetime: 3600)
        monitor.tick(now: start.addingTimeInterval(1), force: true)
        XCTAssertEqual(chimes, 0, "Existing entries are silent on launch")

        try store.upsert(id: "first", project: "Changed", task: "B", message: "C",
                         threadID: thread, now: start.addingTimeInterval(2))
        monitor.tick(now: start.addingTimeInterval(2), force: true)
        XCTAssertEqual(chimes, 0, "Idempotent writes are silent")

        try store.upsert(id: "second", project: "A", task: "B", message: "C",
                         threadID: thread, now: start.addingTimeInterval(3), lifetime: 3600)
        try store.upsert(id: "third", project: "A", task: "B", message: "C",
                         threadID: thread, now: start.addingTimeInterval(3), lifetime: 3600)
        monitor.tick(now: start.addingTimeInterval(4), force: true)
        XCTAssertEqual(chimes, 1, "A batch of new requests makes one sound")
        monitor.tick(now: start.addingTimeInterval(4), force: true)
        XCTAssertEqual(chimes, 1, "Repeated reads are silent")

        try store.resolve(id: "second")
        monitor.tick(now: start.addingTimeInterval(5), force: true)
        XCTAssertEqual(chimes, 1, "Resolution is silent")
        try store.upsert(id: "second", project: "A", task: "New", message: "C",
                         threadID: thread, now: start.addingTimeInterval(6), lifetime: 3600)
        monitor.tick(now: start.addingTimeInterval(7), force: true)
        XCTAssertEqual(chimes, 2, "Reopened ID with a new generation is new")

        let restarted = ActionRequestMonitor(store: store, credentials: { nil })
        restarted.onNewRequests = { chimes += 1 }
        restarted.tick(now: start.addingTimeInterval(8), force: true)
        XCTAssertEqual(chimes, 2, "Restart does not replay a sound")
    }

    func testDelayIdempotenceAndExternalResolutionCancelInFlight() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "CodenotchReminderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(15, forKey: "actionReminderMinutes")
        let store = ActionRequestStore(directory: directory)
        let transport = FakeReminderTransport()
        let monitor = ActionRequestMonitor(store: store, defaults: defaults,
            transport: transport, credentials: { ("unused-test-token", "unused-test-chat") })
        let start = Date(timeIntervalSince1970: 1_000_000)
        try store.upsert(id: "one", project: "A", task: "B", message: "C",
                         threadID: UUID().uuidString, now: start, lifetime: 7200)
        monitor.tick(now: start.addingTimeInterval(899), force: true)
        XCTAssertTrue(transport.sentIDs.isEmpty)
        monitor.tick(now: start.addingTimeInterval(900), force: true)
        monitor.tick(now: start.addingTimeInterval(901), force: true)
        XCTAssertEqual(transport.sentIDs, ["one"])
        try store.resolve(id: "one") // Simulate an agent closing it in another process.
        monitor.tick(now: start.addingTimeInterval(902), force: true)
        XCTAssertTrue(transport.tasks["one"]?.cancelled == true)
        XCTAssertTrue(monitor.requests.isEmpty)
    }

    func testReusedIDCancelsOldDeliveryWithoutTouchingNewRequest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActionRequestStore(directory: directory)
        let transport = FakeReminderTransport()
        let suite = "CodenotchReminderDefaultTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let monitor = ActionRequestMonitor(store: store, defaults: defaults, transport: transport,
            credentials: { ("unused-test-token", "unused-test-chat") })
        XCTAssertEqual(monitor.reminderDelay, 900)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let thread = UUID().uuidString
        try store.upsert(id: "same", project: "A", task: "Old", message: "C",
                         threadID: thread, now: start, lifetime: 15_000)
        monitor.tick(now: start.addingTimeInterval(900), force: true)
        let oldTask = try XCTUnwrap(transport.tasks["same"])
        try store.resolve(id: "same")
        try store.upsert(id: "same", project: "A", task: "New", message: "C",
                         threadID: thread, now: start.addingTimeInterval(901), lifetime: 15_000)
        monitor.tick(now: start.addingTimeInterval(902), force: true)
        XCTAssertTrue(oldTask.cancelled)
        XCTAssertEqual(monitor.requests.map(\.task), ["New"])
        XCTAssertEqual(transport.sentIDs, ["same"])
    }
}
