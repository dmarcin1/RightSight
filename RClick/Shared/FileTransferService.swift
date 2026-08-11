import Foundation

enum FileTransferOperation: Equatable, Sendable {
    case copy
    case move
}

struct FileTransferSuccess: Sendable {
    let sourceURL: URL
    let destinationURL: URL
}

struct FileTransferFailure: Sendable {
    let sourceURL: URL
    let message: String
}

struct FileTransferResult: Sendable {
    let successes: [FileTransferSuccess]
    let failures: [FileTransferFailure]
}

enum FileTransferError: LocalizedError {
    case destinationIsNotDirectory
    case sourceDoesNotExist
    case destinationIsInsideSource

    var errorDescription: String? {
        switch self {
        case .destinationIsNotDirectory:
            "目标位置不是文件夹"
        case .sourceDoesNotExist:
            "源项目不存在"
        case .destinationIsInsideSource:
            "不能将文件夹复制或移动到其自身或子文件夹中"
        }
    }
}

enum FileTransferService {
    nonisolated static func transfer(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        operation: FileTransferOperation,
        fileManager: FileManager = .default
    ) -> FileTransferResult {
        var successes: [FileTransferSuccess] = []
        var failures: [FileTransferFailure] = []

        var isDestinationDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: destinationDirectory.path,
            isDirectory: &isDestinationDirectory
        ), isDestinationDirectory.boolValue else {
            return FileTransferResult(
                successes: [],
                failures: sourceURLs.map {
                    FileTransferFailure(
                        sourceURL: $0,
                        message: FileTransferError.destinationIsNotDirectory.localizedDescription
                    )
                }
            )
        }

        for sourceURL in sourceURLs {
            do {
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    throw FileTransferError.sourceDoesNotExist
                }
                try validateDestination(destinationDirectory, for: sourceURL, fileManager: fileManager)

                let destinationURL = uniqueDestinationURL(
                    for: sourceURL,
                    in: destinationDirectory,
                    fileManager: fileManager
                )
                switch operation {
                case .copy:
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                case .move:
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                }
                successes.append(
                    FileTransferSuccess(sourceURL: sourceURL, destinationURL: destinationURL)
                )
            } catch {
                failures.append(
                    FileTransferFailure(sourceURL: sourceURL, message: error.localizedDescription)
                )
            }
        }

        return FileTransferResult(successes: successes, failures: failures)
    }

    nonisolated static func uniqueDestinationURL(
        for sourceURL: URL,
        in destinationDirectory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)

        let originalName = sourceURL.lastPathComponent
        let fileExtension = isDirectory.boolValue ? "" : sourceURL.pathExtension
        let baseName = fileExtension.isEmpty
            ? originalName
            : sourceURL.deletingPathExtension().lastPathComponent

        var candidate = destinationDirectory.appendingPathComponent(
            originalName,
            isDirectory: isDirectory.boolValue
        )
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let numberedName = fileExtension.isEmpty
                ? "\(baseName)-\(suffix)"
                : "\(baseName)-\(suffix).\(fileExtension)"
            candidate = destinationDirectory.appendingPathComponent(
                numberedName,
                isDirectory: isDirectory.boolValue
            )
            suffix += 1
        }

        return candidate
    }

    private nonisolated static func validateDestination(
        _ destinationDirectory: URL,
        for sourceURL: URL,
        fileManager: FileManager
    ) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw FileTransferError.sourceDoesNotExist
        }
        guard isDirectory.boolValue else { return }

        let sourcePath = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let destinationPath = destinationDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        if destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + "/") {
            throw FileTransferError.destinationIsInsideSource
        }
    }
}
