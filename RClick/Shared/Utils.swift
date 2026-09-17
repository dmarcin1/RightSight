import Foundation

public class Utils {
    public static func isProtectedFolder(_ path: String) -> Bool {
        let cleanPath = path.removingPercentEncoding ?? path
        let url = URL(fileURLWithPath: cleanPath).standardized.resolvingSymlinksInPath()
        let normalizedPath = url.path

        if normalizedPath == "/" || normalizedPath.isEmpty {
            return true
        }

        for protected in Constants.protectedDirs {
            let normalizedProtected = URL(fileURLWithPath: protected).standardized.resolvingSymlinksInPath().path
            if normalizedPath == normalizedProtected {
                return true
            }
        }

        let systemRoots = ["/System", "/Library", "/bin", "/sbin", "/usr", "/private", "/var"]
        for sysRoot in systemRoots {
            if normalizedPath == sysRoot || normalizedPath.hasPrefix(sysRoot + "/") {
                return true
            }
        }

        return false
    }

    public static func getRealHomeDir() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return FileManager.default.string(withFileSystemRepresentation: dir, length: strlen(dir))
        }
        let fullPath = NSHomeDirectory()
        let components = fullPath.components(separatedBy: "/")
        let limitedComponents = Array(components.prefix(3))
        return limitedComponents.joined(separator: "/")
    }
}
