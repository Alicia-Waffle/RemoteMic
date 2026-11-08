import AppKit
import CoreGraphics
import Foundation

/// 多步动作里的一个步骤。
///
/// 组合键只是「只包含 shortcut 步骤」的多步动作，两者共用同一套存储与执行器。
enum RemoteActionStep: Codable, Hashable {
    case shortcut(RemoteCustomShortcut)
    case insertText(String)
    case openApplication(RemoteAppLaunch)
    case focusInput
    case wait(Int) // 毫秒
    case voice

    enum Kind: String, CaseIterable {
        case shortcut
        case insertText
        case openApplication
        case focusInput
        case wait
        case voice

        var title: String {
            switch self {
            case .shortcut: L10n.text("按键 / 组合键", "Key / Shortcut")
            case .insertText: L10n.text("输入文本", "Insert Text")
            case .openApplication: L10n.text("打开 App", "Open App")
            case .focusInput: L10n.text("聚焦输入框", "Focus Input")
            case .wait: L10n.text("等待", "Wait")
            case .voice: L10n.text("等待语音输入结束", "Wait for Voice")
            }
        }

        var symbol: String {
            switch self {
            case .shortcut: "keyboard"
            case .insertText: "text.cursor"
            case .openApplication: "app.badge"
            case .focusInput: "rectangle.and.text.magnifyingglass"
            case .wait: "clock"
            case .voice: "mic"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .shortcut: .shortcut
        case .insertText: .insertText
        case .openApplication: .openApplication
        case .focusInput: .focusInput
        case .wait: .wait
        case .voice: .voice
        }
    }

    var summary: String {
        switch self {
        case .shortcut(let shortcut):
            return shortcut.label
        case .insertText(let text):
            return Self.textPreview(text)
        case .openApplication(let app):
            return app.label
        case .focusInput:
            return L10n.text("聚焦输入框", "Focus input")
        case .wait(let milliseconds):
            return L10n.text(
                "等待 \(Self.secondsText(milliseconds))",
                "Wait \(Self.secondsText(milliseconds))"
            )
        case .voice:
            return L10n.text("语音输入", "Voice")
        }
    }

    static func textPreview(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flattened.isEmpty else {
            return L10n.text("空文本", "Empty text")
        }
        let limit = 12
        return flattened.count > limit
            ? String(flattened.prefix(limit)) + "…"
            : flattened
    }

    static func secondsText(_ milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1000
        if seconds < 1 {
            return String(format: "%.1fs", seconds)
        }
        return seconds.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fs", seconds)
            : String(format: "%.1fs", seconds)
    }
}

struct RemoteActionSequence: Codable, Hashable {
    var steps: [RemoteActionStep]

    init(steps: [RemoteActionStep] = []) {
        self.steps = steps
    }

    init(shortcut: RemoteCustomShortcut) {
        self.steps = [.shortcut(shortcut)]
    }

    var isEmpty: Bool { steps.isEmpty }

    var summary: String {
        guard !steps.isEmpty else {
            return L10n.text("多步动作…", "Multi-step action…")
        }
        let shown = steps.prefix(2).map(\.summary)
        var text = shown.joined(separator: " → ")
        if steps.count > shown.count {
            text += L10n.text(
                " 等 \(steps.count) 步",
                " +\(steps.count - shown.count)"
            )
        }
        return text
    }
}

// MARK: - 文本注入

/// 通过剪贴板 + ⌘V 注入固定文本，300 ms 后恢复原来的剪贴板内容。
enum TextInjector {
    private static let restoreDelay: TimeInterval = 0.3
    private static var savedItems: [[NSPasteboard.PasteboardType: Data]]?
    private static var expectedChangeCount: Int?
    private static var restoreWorkItem: DispatchWorkItem?

    static func insert(_ text: String) {
        guard !text.isEmpty else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { insert(text) }
            return
        }
        restoreNow()
        let pasteboard = NSPasteboard.general
        savedItems = snapshot(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        expectedChangeCount = pasteboard.changeCount

        RemoteMappingTarget.commandV.post(isDown: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            RemoteMappingTarget.commandV.post(isDown: false)
        }

        let work = DispatchWorkItem { restoreNow() }
        restoreWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + restoreDelay,
            execute: work
        )
        print("[TEXT] 已注入 \(text.count) 个字符，\(Int(restoreDelay * 1000)) ms 后恢复剪贴板")
    }

    private static func snapshot(
        from pasteboard: NSPasteboard
    ) -> [[NSPasteboard.PasteboardType: Data]] {
        var result: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    contents[type] = data
                }
            }
            if !contents.isEmpty { result.append(contents) }
        }
        return result
    }

    private static func restoreNow() {
        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        guard let saved = savedItems else { return }
        savedItems = nil
        let pasteboard = NSPasteboard.general
        let expected = expectedChangeCount
        expectedChangeCount = nil
        guard pasteboard.changeCount == expected else {
            // 用户或其他 App 在 300 ms 内复制了新内容，保留新内容。
            print("[TEXT] 剪贴板已被其他操作更新，跳过恢复")
            return
        }
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let items = saved.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

// MARK: - 多步动作执行器

/// 主线程串行执行多步动作。
///
/// 新动作开始时会递增 generation，让上一条动作的后续步骤自动失效；
/// 整条动作最长 60 秒，语音步骤最长 30 秒。
final class RemoteActionRunner {
    static let shared = RemoteActionRunner()

    /// 语音步骤：读取豆包是否正在录音（由 main.swift 注入）。
    var doubaoIsRecording: () -> Bool = { false }
    /// 语音步骤：模拟一次触发键点击（由 main.swift 注入）。
    var voiceTap: () -> Void = { Key.triggerTap() }

    private static let stepInterval: TimeInterval = 0.08
    private static let maximumDuration: TimeInterval = 60

    private var generation = 0
    private var timeoutWorkItem: DispatchWorkItem?

    private init() {}

    func run(_ sequence: RemoteActionSequence) {
        guard !sequence.isEmpty else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.run(sequence) }
            return
        }
        generation += 1
        let run = generation
        timeoutWorkItem?.cancel()
        print("[SEQ] 开始 \(sequence.steps.count) 步：\(sequence.summary)")
        scheduleTimeout(for: run)
        perform(index: 0, steps: sequence.steps, generation: run)
    }

    private func scheduleTimeout(for run: Int) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == run else { return }
            self.generation += 1
            print("[SEQ] ⚠️ 动作超过 \(Int(Self.maximumDuration)) 秒，已中止")
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.maximumDuration,
            execute: work
        )
    }

    private func perform(
        index: Int,
        steps: [RemoteActionStep],
        generation run: Int
    ) {
        guard run == generation else { return }
        guard index < steps.count else {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            print("[SEQ] 动作完成")
            return
        }

        let step = steps[index]
        let continuation: () -> Void = { [weak self] in
            guard let self, self.generation == run else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.stepInterval) {
                guard self.generation == run else { return }
                self.perform(index: index + 1, steps: steps, generation: run)
            }
        }

        switch step {
        case .shortcut(let shortcut):
            shortcut.post(isDown: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                [weak self] in
                // 即使动作已被取消，也要补发 keyUp，避免修饰键卡住。
                shortcut.post(isDown: false)
                guard let self, self.generation == run else { return }
                continuation()
            }

        case .insertText(let text):
            TextInjector.insert(text)
            continuation()

        case .openApplication(let app):
            app.open()
            waitForFrontmost(
                bundleID: app.bundleID,
                generation: run,
                deadline: Date().addingTimeInterval(2),
                continuation: continuation
            )

        case .focusInput:
            RemoteOneShot.focusInput()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                [weak self] in
                guard let self, self.generation == run else { return }
                continuation()
            }

        case .wait(let milliseconds):
            let clamped = max(1, min(10_000, milliseconds))
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(clamped) / 1000
            ) { [weak self] in
                guard let self, self.generation == run else { return }
                continuation()
            }

        case .voice:
            runVoiceStep(generation: run, continuation: continuation)
        }
    }

    private func waitForFrontmost(
        bundleID: String,
        generation run: Int,
        deadline: Date,
        continuation: @escaping () -> Void
    ) {
        guard run == generation else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if frontmost == bundleID {
            continuation()
            return
        }
        if Date() >= deadline {
            print("[SEQ] ⚠️ 等待 \(bundleID) 激活超时，继续下一步")
            continuation()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, self.generation == run else { return }
            self.waitForFrontmost(
                bundleID: bundleID,
                generation: run,
                deadline: deadline,
                continuation: continuation
            )
        }
    }

    /// 触发一次豆包语音，等它真正开始录音后再等录音结束。
    ///
    /// 只观察豆包自身的录音状态，不直接操作语音链路；AudioPipe 中
    /// 「豆包停止 → releaseOutputIfIdle」的既有收尾逻辑保持不变。
    private func runVoiceStep(
        generation run: Int,
        continuation: @escaping () -> Void
    ) {
        var watcher = VoiceStepWatcher(beganAt: Date())
        var finished = false
        voiceTap()
        print("[SEQ] 语音步骤：已触发豆包，等待录音结束")

        func poll() {
            guard run == generation, !finished else { return }
            switch watcher.update(recording: doubaoIsRecording(), at: Date()) {
            case .wait:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    poll()
                }
            case .finished(let reason):
                finished = true
                print("[SEQ] 语音步骤结束（\(reason.logDescription)）")
                continuation()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { poll() }
    }
}

/// 语音步骤的结束判定，纯状态机，便于自测。
///
/// 规则：先观察到豆包开始录音，再等它变成未录音；最多等 30 秒；
/// 若 2 秒内豆包根本没开始录音，直接放过这一步，避免白等。
struct VoiceStepWatcher {
    enum EndReason: Equatable {
        case recordingStopped
        case timeout
        case neverStarted

        var logDescription: String {
            switch self {
            case .recordingStopped:
                return "检测到豆包停止录音"
            case .timeout:
                return "等待超过 30 秒"
            case .neverStarted:
                return "未检测到豆包开始录音"
            }
        }
    }

    enum Decision: Equatable {
        case wait
        case finished(EndReason)
    }

    static let timeout: TimeInterval = 30
    static let startGrace: TimeInterval = 2.0

    private let beganAt: Date
    private var sawRecording = false
    private var endReason: EndReason?

    init(beganAt: Date) {
        self.beganAt = beganAt
    }

    mutating func update(recording: Bool, at now: Date) -> Decision {
        if let endReason { return .finished(endReason) }
        if recording { sawRecording = true }

        if sawRecording && !recording {
            endReason = .recordingStopped
            return .finished(.recordingStopped)
        }

        let elapsed = now.timeIntervalSince(beganAt)
        if elapsed >= Self.timeout {
            endReason = .timeout
            return .finished(.timeout)
        }
        if !sawRecording && elapsed >= Self.startGrace {
            endReason = .neverStarted
            return .finished(.neverStarted)
        }
        return .wait
    }
}
