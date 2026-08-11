import Foundation

struct FileCutBuffer {
    private(set) var urls: [URL] = []

    var isEmpty: Bool { urls.isEmpty }

    mutating func replace(with urls: [URL]) {
        self.urls = urls
    }

    mutating func removeSuccessfullyMoved(_ successes: [FileTransferSuccess]) {
        let movedPaths = Set(successes.map { $0.sourceURL.standardizedFileURL.path })
        urls.removeAll { movedPaths.contains($0.standardizedFileURL.path) }
    }
}
