import Foundation
import Testing
@testable import RightSight

struct FileTransferServiceTests {
    @MainActor
    @Test func copiesWithoutRemovingSource() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let sourceURL = fixture.source.appendingPathComponent("notes.txt")
        try Data("original".utf8).write(to: sourceURL)

        let result = FileTransferService.transfer(
            [sourceURL],
            to: fixture.destination,
            operation: .copy
        )

        #expect(result.failures.isEmpty)
        #expect(result.successes.count == 1)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(try String(contentsOf: result.successes[0].destinationURL, encoding: .utf8) == "original")
    }

    @MainActor
    @Test func numbersConflictsWithoutOverwriting() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let sourceURL = fixture.source.appendingPathComponent("notes.txt")
        let existingURL = fixture.destination.appendingPathComponent("notes.txt")
        let numberedURL = fixture.destination.appendingPathComponent("notes-2.txt")
        try Data("new".utf8).write(to: sourceURL)
        try Data("keep".utf8).write(to: existingURL)
        try Data("keep two".utf8).write(to: numberedURL)

        let result = FileTransferService.transfer(
            [sourceURL],
            to: fixture.destination,
            operation: .copy
        )

        #expect(result.successes.first?.destinationURL.lastPathComponent == "notes-3.txt")
        #expect(try String(contentsOf: existingURL, encoding: .utf8) == "keep")
        #expect(try String(contentsOf: numberedURL, encoding: .utf8) == "keep two")
    }

    @MainActor
    @Test func movesAndRemovesSource() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let sourceURL = fixture.source.appendingPathComponent("move-me.txt")
        try Data("move".utf8).write(to: sourceURL)

        let result = FileTransferService.transfer(
            [sourceURL],
            to: fixture.destination,
            operation: .move
        )

        #expect(result.failures.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: result.successes[0].destinationURL.path))
    }

    @MainActor
    @Test func rejectsCopyingDirectoryIntoItsDescendant() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RightSightFileTransferTests-\(UUID().uuidString)")
        let child = root.appendingPathComponent("Child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = FileTransferService.transfer([root], to: child, operation: .copy)

        #expect(result.successes.isEmpty)
        #expect(result.failures.count == 1)
        #expect(result.failures[0].message.contains("自身或子文件夹"))
    }

    @MainActor
    @Test func cutBufferKeepsItemsThatWereNotMoved() {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/second.txt")
        var buffer = FileCutBuffer()
        buffer.replace(with: [first, second])

        buffer.removeSuccessfullyMoved([
            FileTransferSuccess(
                sourceURL: first,
                destinationURL: URL(fileURLWithPath: "/tmp/destination/first.txt")
            )
        ])

        #expect(buffer.urls == [second])
    }

    private func makeFixture() throws -> (root: URL, source: URL, destination: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RightSightFileTransferTests-\(UUID().uuidString)")
        let source = root.appendingPathComponent("Source")
        let destination = root.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return (root, source, destination)
    }
}
