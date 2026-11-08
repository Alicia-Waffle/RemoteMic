import Foundation

enum Log {
    private static let lock = NSLock()
    /// 单文件 2 GB 后轮转，避免日志无限增长拖垮磁盘。
    private static let maximumBytes: UInt64 = 2 * 1_024 * 1_024 * 1_024
    private static var handle: FileHandle?

    /// 轮转后保留的上一份日志，只保留一份，总占用最多约为 4 GB。
    private static var archiveFile: URL {
        AppStorage.logsDirectory.appendingPathComponent("RemoteMic.log.1")
    }

    static var isEnabled: Bool { AppStorage.loggingEnabled }

    static func setEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        AppStorage.loggingEnabled = enabled
        if enabled {
            openHandleIfNeeded()
        } else {
            closeHandle()
        }
    }

    static func write(_ message: String) {
        guard AppStorage.loggingEnabled else { return }
        lock.lock()
        defer { lock.unlock() }

        rotateIfNeeded()
        openHandleIfNeeded()
        guard let handle else { return }
        let line = "[\(Date())] \(message)\n"
        try? handle.write(contentsOf: Data(line.utf8))
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        closeHandle()
        try? FileManager.default.removeItem(at: AppStorage.logFile)
        try? FileManager.default.removeItem(at: archiveFile)
        if AppStorage.loggingEnabled {
            openHandleIfNeeded()
        }
    }

    /// 立即轮转（控制台菜单手动触发，便于验证）。
    static func rotateNow() {
        lock.lock()
        defer { lock.unlock() }
        rotate(force: true)
    }

    /// 当前日志 + 上一份轮转文件的总占用。
    static var byteSize: UInt64 {
        fileSize(at: AppStorage.logFile) + fileSize(at: archiveFile)
    }

    private static var currentFileSize: UInt64 {
        fileSize(at: AppStorage.logFile)
    }

    private static func fileSize(at url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values?.fileSize ?? 0)
    }

    private static func openHandleIfNeeded() {
        guard handle == nil else { return }
        AppStorage.ensureDirectory(AppStorage.logsDirectory)
        if !FileManager.default.fileExists(atPath: AppStorage.logFile.path) {
            FileManager.default.createFile(
                atPath: AppStorage.logFile.path,
                contents: nil
            )
        }
        handle = try? FileHandle(forWritingTo: AppStorage.logFile)
        _ = try? handle?.seekToEnd()
    }

    private static func rotateIfNeeded() {
        guard currentFileSize >= maximumBytes else { return }
        rotate(force: false)
    }

    private static func rotate(force: Bool) {
        guard force || currentFileSize >= maximumBytes, currentFileSize > 0 else {
            return
        }
        closeHandle()
        guard rotateFiles(current: AppStorage.logFile, archive: archiveFile) else {
            return
        }
        guard AppStorage.loggingEnabled else { return }
        openHandleIfNeeded()
        guard let handle else { return }
        let line = "[\(Date())] [LOG] 日志已轮转，上一份保留为 " +
            "\(archiveFile.lastPathComponent)\n"
        try? handle.write(contentsOf: Data(line.utf8))
    }

    /// 把当前日志移动成上一份，并替换更早的上一份。
    @discardableResult
    static func rotateFiles(current: URL, archive: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: current.path) else { return false }
        try? fm.removeItem(at: archive)
        do {
            try fm.moveItem(at: current, to: archive)
            return true
        } catch {
            return false
        }
    }

    private static func closeHandle() {
        try? handle?.close()
        handle = nil
    }
}

func print(_ message: String) {
    Log.write(message)
}
