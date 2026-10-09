import Foundation
import XCTest
@testable import Codenotch

final class TaskBoardTests: XCTestCase {
    private let coordinator = BoardConversation(
        threadID: "11111111-1111-4111-8111-111111111111", hostID: "local")
    private let source = BoardConversation(
        threadID: "22222222-2222-4222-8222-222222222222", hostID: "local")

    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-board-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testLifecycleRetainsTaskAndResumesWithoutResettingProgress() throws {
        let store = TaskBoardStore(directory: try scratch())
        let start = Date(timeIntervalSince1970: 1_000)
        let task = try store.upsert(id: "job", title: "A task", coordinator: coordinator, now: start)
        XCTAssertEqual(task.total, 5)
        XCTAssertEqual(task.createdAt, start)
        let progressed = try store.progress(id: "job", completed: 3,
                                            now: start.addingTimeInterval(20))
        XCTAssertEqual(progressed.completed, 3)
        _ = try store.setLifecycle(id: "job", lifecycle: .completed,
                                   now: start.addingTimeInterval(30))
        XCTAssertTrue(try store.active().isEmpty)
        XCTAssertEqual(try store.all().count, 1)
        let resumed = try store.setLifecycle(id: "job", lifecycle: .active,
                                             now: start.addingTimeInterval(40))
        XCTAssertEqual(resumed.completed, 3)
        XCTAssertEqual(resumed.createdAt, start)
        XCTAssertEqual(try store.active().map(\.id), ["job"])
    }

    func testIdempotentRetryDoesNotChangeUpdatedAtOrFile() throws {
        let store = TaskBoardStore(directory: try scratch())
        let start = Date(timeIntervalSince1970: 1_000)
        _ = try store.upsert(id: "job", title: "A task", coordinator: coordinator, now: start)
        let before = try Data(contentsOf: store.dataURL)
        let retry = try store.upsert(id: "job", title: "A task", coordinator: coordinator,
                                     now: start.addingTimeInterval(60))
        XCTAssertEqual(retry.updatedAt, start)
        XCTAssertEqual(try Data(contentsOf: store.dataURL), before)
        _ = try store.progress(id: "job", completed: 0, now: start.addingTimeInterval(60))
        XCTAssertEqual(try Data(contentsOf: store.dataURL), before)
    }

    func testSignalRoutesToSourceWithoutChangingProgressOrRequestFile() throws {
        let directory = try scratch()
        let store = TaskBoardStore(directory: directory)
        _ = try store.upsert(id: "job", title: "A task", coordinator: coordinator,
                             total: 7, completed: 2)
        let signaled = try store.setSignal(id: "job", signal: .needs_user, source: source)
        XCTAssertEqual(signaled.openThreadID, source.threadID)
        XCTAssertEqual(signaled.deepLink?.absoluteString,
                       "codex://threads/\(source.threadID)?hostId=local")
        XCTAssertEqual(signaled.completed, 2)
        XCTAssertEqual(signaled.total, 7)
        let changed = try store.setSignal(id: "job", signal: .blocked)
        XCTAssertEqual(changed.openThreadID, coordinator.threadID)
        let cleared = try store.setSignal(id: "job", signal: .none)
        XCTAssertEqual(cleared.openThreadID, coordinator.threadID)
        XCTAssertEqual(cleared.conversations.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("requests.json").path))
    }

    func testRejectsInvalidProgressAndPreservesStoredDocument() throws {
        let store = TaskBoardStore(directory: try scratch())
        _ = try store.upsert(id: "job", title: "A task", coordinator: coordinator)
        let before = try Data(contentsOf: store.dataURL)
        XCTAssertThrowsError(try store.progress(id: "job", completed: 6))
        XCTAssertThrowsError(try store.progress(id: "job", completed: -1))
        XCTAssertEqual(try Data(contentsOf: store.dataURL), before)
    }

    func testAdditionalConversationDoesNotRetargetOrdinaryRow() throws {
        let store = TaskBoardStore(directory: try scratch())
        _ = try store.upsert(id: "job", title: "A task", coordinator: coordinator)
        let task = try store.addConversation(id: "job", conversation: source)
        XCTAssertEqual(task.conversations.count, 2)
        XCTAssertEqual(task.openThreadID, coordinator.threadID)
    }

    func testUnsupportedSchemaIsNotOverwritten() throws {
        let store = TaskBoardStore(directory: try scratch())
        let data = Data(#"{"schemaVersion":2,"tasks":[]}"#.utf8)
        try data.write(to: store.dataURL)
        XCTAssertThrowsError(try store.upsert(id: "job", title: "A task", coordinator: coordinator))
        XCTAssertEqual(try Data(contentsOf: store.dataURL), data)
    }
}

@MainActor
final class TaskBoardButtonGeometryTests: XCTestCase {
    func testButtonFitsAfterLastReadingOnEveryEdge() {
        for count in [1, 2, 3] {
        for edge in NotchEdge.allCases {
            let model = NotchViewModel()
            model.edge = edge
            model.updateSnapshots(Array(Fixtures.snapshots().prefix(count)))
            model.isExpanded = true
            let lastRing = model.ringAlong(index: count - 1, in: model.cellWing)
            let button = model.taskButtonAlong
            XCTAssertGreaterThan(button - lastRing,
                model.cellPitch * model.sizeScale / 2,
                "Button overlaps provider hit band on \(edge)")
            XCTAssertLessThan(button + 12, model.cellWing.lead + model.cellWing.length,
                "Button escapes notch on \(edge)")
        }
        }
    }
}
