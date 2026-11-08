import AppKit
import CoreGraphics
import Foundation

enum SupportedRemoteID: String, CaseIterable, Identifiable, Codable {
    case chromecast
    case x6

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chromecast: "Chromecast Voice Remote"
        case .x6: "X6 Remote"
        }
    }

    var signature: String {
        switch self {
        case .chromecast: "18D1 · 9450"
        case .x6: "1D5A · C081"
        }
    }
}

struct RemoteButtonDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let defaultTarget: RemoteMappingTarget
    let voiceControlled: Bool
    let remappable: Bool

    init(
        id: String,
        title: String,
        symbol: String,
        defaultTarget: RemoteMappingTarget,
        voiceControlled: Bool = false,
        remappable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.defaultTarget = defaultTarget
        self.voiceControlled = voiceControlled
        self.remappable = remappable
    }
}

enum RemoteProfiles {
    static let chromecastButtons: [RemoteButtonDefinition] = [
        .init(id: "03", title: L10n.text("方向上", "Up"), symbol: "arrow.up", defaultTarget: .arrowUp),
        .init(id: "04", title: L10n.text("方向下", "Down"), symbol: "arrow.down", defaultTarget: .arrowDown),
        .init(id: "05", title: L10n.text("方向左", "Left"), symbol: "arrow.left", defaultTarget: .arrowLeft),
        .init(id: "06", title: L10n.text("方向右", "Right"), symbol: "arrow.right", defaultTarget: .arrowRight),
        .init(id: "07", title: L10n.text("确认", "Select"), symbol: "circle.inset.filled", defaultTarget: .returnKey),
        .init(id: "0B", title: L10n.text("返回", "Back"), symbol: "chevron.backward", defaultTarget: .escape),
        .init(id: "0A", title: "Home", symbol: "house", defaultTarget: .showDesktop),
        .init(id: "0E", title: "YouTube", symbol: "play.rectangle", defaultTarget: .disabled),
        .init(id: "voice", title: L10n.text("语音", "Voice"), symbol: "mic", defaultTarget: .doubaoVoice, voiceControlled: true),
        .init(id: "08", title: L10n.text("静音", "Mute"), symbol: "speaker.slash", defaultTarget: .mute),
        .init(id: "0F", title: "Netflix", symbol: "n.square", defaultTarget: .disabled),
        .init(id: "01", title: L10n.text("电源", "Power"), symbol: "power", defaultTarget: .disabled),
        .init(id: "11", title: L10n.text("信源", "Input"), symbol: "rectangle.on.rectangle", defaultTarget: .disabled),
        .init(id: "0C", title: L10n.text("音量＋", "Volume Up"), symbol: "speaker.plus", defaultTarget: .volumeUp),
        .init(id: "0D", title: L10n.text("音量－", "Volume Down"), symbol: "speaker.minus", defaultTarget: .volumeDown),
    ]

    static func buttons(for remote: SupportedRemoteID) -> [RemoteButtonDefinition] {
        switch remote {
        case .chromecast: chromecastButtons
        case .x6: x6Buttons
        }
    }

    static let x6Buttons: [RemoteButtonDefinition] = [
        .init(id: "mouseMode", title: L10n.text("鼠标模式", "Mouse Mode"), symbol: "cursorarrow.motionlines", defaultTarget: .disabled, remappable: false),
        .init(id: "k2A", title: "Delete", symbol: "delete.left", defaultTarget: .deleteBackward),
        .init(id: "cE2", title: L10n.text("静音", "Mute"), symbol: "speaker.slash", defaultTarget: .mute),
        .init(id: "c224", title: L10n.text("返回", "Back"), symbol: "chevron.backward", defaultTarget: .escape),
        .init(id: "k65", title: L10n.text("菜单", "Menu"), symbol: "line.3.horizontal", defaultTarget: .disabled),
        .init(id: "c196", title: L10n.text("浏览器/搜索", "Browser / Search"), symbol: "magnifyingglass", defaultTarget: .spotlight),
        .init(id: "k52", title: L10n.text("方向上", "Up"), symbol: "arrow.up", defaultTarget: .arrowUp),
        .init(id: "k51", title: L10n.text("方向下", "Down"), symbol: "arrow.down", defaultTarget: .arrowDown),
        .init(id: "k50", title: L10n.text("方向左", "Left"), symbol: "arrow.left", defaultTarget: .arrowLeft),
        .init(id: "k4F", title: L10n.text("方向右", "Right"), symbol: "arrow.right", defaultTarget: .arrowRight),
        .init(id: "k28", title: "OK", symbol: "circle.inset.filled", defaultTarget: .returnKey),
        .init(id: "k4B", title: "PG+", symbol: "arrow.up.to.line", defaultTarget: .pageUp),
        .init(id: "k4E", title: "PG−", symbol: "arrow.down.to.line", defaultTarget: .pageDown),
        .init(id: "voice", title: L10n.text("语音", "Voice"), symbol: "mic", defaultTarget: .doubaoVoice, voiceControlled: true),
        .init(id: "cE9", title: L10n.text("音量＋", "Volume Up"), symbol: "speaker.plus", defaultTarget: .volumeUp),
        .init(id: "cEA", title: L10n.text("音量－", "Volume Down"), symbol: "speaker.minus", defaultTarget: .volumeDown),
        .init(id: "s01", title: L10n.text("电源", "Power"), symbol: "power", defaultTarget: .disabled),
    ]
}

enum RemoteGesture: String, Codable, CaseIterable, Identifiable {
    case single
    case double
    case long

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: L10n.text("单击", "Single")
        case .double: L10n.text("双击", "Double")
        case .long: L10n.text("长按", "Long")
        }
    }
}

enum RemoteMappingTarget: String, CaseIterable, Identifiable, Codable, Hashable {
    case disabled
    case doubaoVoice
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case scrollUp
    case scrollDown
    case focusInput
    case returnKey
    case escape
    case deleteBackward
    case tab
    case space
    case home
    case end
    case pageUp
    case pageDown
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case showDesktop
    case spotlight
    case commandC
    case commandV
    case commandZ
    case custom
    case insertText
    case sequence
    case openApplication

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: L10n.text("禁用", "Disabled")
        case .doubaoVoice: L10n.text("豆包语音输入", "Doubao Voice Input")
        case .arrowUp: L10n.text("方向上", "Up Arrow")
        case .arrowDown: L10n.text("方向下", "Down Arrow")
        case .arrowLeft: L10n.text("方向左", "Left Arrow")
        case .arrowRight: L10n.text("方向右", "Right Arrow")
        case .scrollUp: L10n.text("向上滚动", "Scroll Up")
        case .scrollDown: L10n.text("向下滚动", "Scroll Down")
        case .focusInput: L10n.text("聚焦输入框", "Focus Input")
        case .returnKey: "Return"
        case .escape: "Escape"
        case .deleteBackward: "Delete"
        case .tab: "Tab"
        case .space: L10n.text("空格", "Space")
        case .home: "Home"
        case .end: "End"
        case .pageUp: "Page Up"
        case .pageDown: "Page Down"
        case .volumeUp: L10n.text("系统音量＋", "System Volume Up")
        case .volumeDown: L10n.text("系统音量－", "System Volume Down")
        case .mute: L10n.text("系统静音", "System Mute")
        case .playPause: L10n.text("播放/暂停", "Play / Pause")
        case .showDesktop: L10n.text("显示桌面", "Show Desktop")
        case .spotlight: "Spotlight (⌘Space)"
        case .commandC: L10n.text("复制 (⌘C)", "Copy (⌘C)")
        case .commandV: L10n.text("粘贴 (⌘V)", "Paste (⌘V)")
        case .commandZ: L10n.text("撤销 (⌘Z)", "Undo (⌘Z)")
        case .custom: L10n.text("录制任意按键…", "Record a key…")
        case .insertText: L10n.text("输入固定文本…", "Insert fixed text…")
        case .sequence: L10n.text("多步动作…", "Multi-step action…")
        case .openApplication: L10n.text("打开 App…", "Open App…")
        }
    }

    var keyboard: (keyCode: CGKeyCode, flags: CGEventFlags)? {
        switch self {
        case .arrowUp: (0x7E, [])
        case .arrowDown: (0x7D, [])
        case .arrowLeft: (0x7B, [])
        case .arrowRight: (0x7C, [])
        case .returnKey: (0x24, [])
        case .escape: (0x35, [])
        case .deleteBackward: (0x33, [])
        case .tab: (0x30, [])
        case .space: (0x31, [])
        case .home: (0x73, [])
        case .end: (0x77, [])
        case .pageUp: (0x74, [])
        case .pageDown: (0x79, [])
        case .showDesktop: (0x67, [.maskSecondaryFn])
        case .spotlight: (0x31, [.maskCommand])
        case .commandC: (0x08, [.maskCommand])
        case .commandV: (0x09, [.maskCommand])
        case .commandZ: (0x06, [.maskCommand])
        default: nil
        }
    }

    var mediaKey: Int32? {
        switch self {
        case .volumeUp: 0
        case .volumeDown: 1
        case .mute: 7
        case .playPause: 16
        default: nil
        }
    }

    func post(isDown: Bool) {
        guard self != .disabled, self != .doubaoVoice else { return }
        if self == .scrollUp || self == .scrollDown {
            if isDown { RemoteOneShot.scroll(lines: self == .scrollUp ? 3 : -3) }
            return
        }
        if self == .focusInput {
            if isDown { RemoteOneShot.focusInput() }
            return
        }
        if let keyboard {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyboard.keyCode,
                keyDown: isDown
            ) else { return }
            event.flags = keyboard.flags
            event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
            event.post(tap: .cghidEventTap)
        } else if let mediaKey, isDown {
            postMediaKey(mediaKey)
        }
    }

    private func postMediaKey(_ key: Int32) {
        func post(state: Int32) {
            let data1 = Int((key << 16) | (state << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )?.cgEvent else { return }
            event.post(tap: .cghidEventTap)
        }
        post(state: 0xA)
        post(state: 0xB)
    }
}

struct RemoteCustomShortcut: Codable, Hashable {
    let keyCode: UInt16
    let flags: UInt64
    let label: String

    /// 方向键 / Home / End / Page Up / Page Down 在真机上属于
    /// “secondary function”按键，硬件事件的 flags 会带 NX_SECONDARYFNMASK。
    private static let secondaryFunctionKeyCodes: Set<UInt16> = [
        0x7B, 0x7C, 0x7D, 0x7E,
        0x73, 0x77, 0x74, 0x79,
    ]

    func post(isDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(keyCode),
            keyDown: isDown
        ) else { return }
        var eventFlags = CGEventFlags(rawValue: flags)
        // 系统「切换桌面」等符号热键按 flags 位精确匹配。合成的 ⌃← 若不带
        // Fn 位，WindowServer 不认这个组合，会把它当普通 ⌃← 交给前台 App
        // （表现是移动光标而不是切桌面）。补上与硬件一致的 Fn 位。
        if eventFlags.contains(.maskControl),
           Self.secondaryFunctionKeyCodes.contains(keyCode) {
            eventFlags.insert(.maskSecondaryFn)
        }
        event.flags = eventFlags
        event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}

struct RemoteAppLaunch: Codable, Hashable {
    let bundleID: String
    let label: String

    func open() {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            print("[CAST-MAP] 找不到 App \(label) (\(bundleID))")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) {
            _, error in
            if let error {
                print("[CAST-MAP] 打开 \(label) 失败: \(error.localizedDescription)")
            }
        }
    }
}

/// 出厂默认按键映射（Chromecast 遥控器）。
///
/// 用 `UserDefaults.register` 注册，而不是在首次启动时写盘：
/// - 新装用户开箱即用这套映射；
/// - 已有用户手动改过的值优先级更高，不会被覆盖；
/// - 用户在控制台里改回默认值时仍然可读到这些注册值。
enum RemoteMappingDefaults {
    static func values() -> [String: Any] {
        var values: [String: Any] = [
            "remoteMappingEnabled.chromecast": true,
            "remoteMapping.chromecast.03": RemoteMappingTarget.scrollUp.rawValue,
            "remoteMapping.chromecast.03.double": RemoteMappingTarget.disabled.rawValue,
            "remoteMapping.chromecast.04": RemoteMappingTarget.scrollDown.rawValue,
            "remoteMapping.chromecast.05": RemoteMappingTarget.custom.rawValue,
            "remoteMapping.chromecast.05.double": RemoteMappingTarget.arrowLeft.rawValue,
            "remoteMapping.chromecast.06": RemoteMappingTarget.custom.rawValue,
            "remoteMapping.chromecast.06.double": RemoteMappingTarget.arrowRight.rawValue,
            "remoteMapping.chromecast.07": RemoteMappingTarget.returnKey.rawValue,
            "remoteMapping.chromecast.07.long": RemoteMappingTarget.space.rawValue,
            "remoteMapping.chromecast.0B": RemoteMappingTarget.deleteBackward.rawValue,
            "remoteMapping.chromecast.0B.double": RemoteMappingTarget.disabled.rawValue,
            "remoteMapping.chromecast.0B.long": RemoteMappingTarget.focusInput.rawValue,
            "remoteMapping.chromecast.01": RemoteMappingTarget.openApplication.rawValue,
            "remoteMapping.chromecast.0E": RemoteMappingTarget.openApplication.rawValue,
            "remoteMapping.chromecast.0F": RemoteMappingTarget.openApplication.rawValue,
            "remoteMapping.chromecast.11": RemoteMappingTarget.openApplication.rawValue,
        ]

        let shortcuts: [String: RemoteCustomShortcut] = [
            "remoteCustomMapping.chromecast.05": RemoteCustomShortcut(
                keyCode: 0x7B,
                flags: CGEventFlags.maskControl.rawValue,
                label: "⌃←"
            ),
            "remoteCustomMapping.chromecast.06": RemoteCustomShortcut(
                keyCode: 0x7C,
                flags: CGEventFlags.maskControl.rawValue,
                label: "⌃→"
            ),
        ]
        let apps: [String: RemoteAppLaunch] = [
            "remoteAppMapping.chromecast.01": RemoteAppLaunch(
                bundleID: "cn.trae.app",
                label: "TRAE CN"
            ),
            "remoteAppMapping.chromecast.0E": RemoteAppLaunch(
                bundleID: "com.google.Chrome",
                label: "Google Chrome"
            ),
            "remoteAppMapping.chromecast.0F": RemoteAppLaunch(
                bundleID: "com.openai.codex",
                label: "ChatGPT"
            ),
            "remoteAppMapping.chromecast.11": RemoteAppLaunch(
                bundleID: "local.simaqingfeng.vRemote",
                label: "RemoteMic"
            ),
        ]

        let encoder = JSONEncoder()
        for (key, shortcut) in shortcuts {
            if let data = try? encoder.encode(shortcut) {
                values[key] = data
            }
        }
        for (key, app) in apps {
            if let data = try? encoder.encode(app) {
                values[key] = data
            }
        }
        return values
    }
}

final class RemoteMappingStore: ObservableObject {
    static let shared = RemoteMappingStore()

    @Published private(set) var revision = 0
    private let defaults: UserDefaults
    private let prefix = "remoteMapping."
    private let enabledPrefix = "remoteMappingEnabled."
    private let customPrefix = "remoteCustomMapping."
    private let appPrefix = "remoteAppMapping."
    private let textPrefix = "remoteTextMapping."
    private let sequencePrefix = "remoteSequenceMapping."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ remote: SupportedRemoteID) -> Bool {
        defaults.bool(forKey: enabledPrefix + remote.rawValue)
    }

    func setEnabled(_ enabled: Bool, for remote: SupportedRemoteID) {
        defaults.set(enabled, forKey: enabledPrefix + remote.rawValue)
        revision += 1
    }

    /// 单击沿用旧存储键，双击 / 长按追加手势后缀，老配置不会失效。
    private func storageKey(
        _ keyPrefix: String,
        _ button: RemoteButtonDefinition,
        _ remote: SupportedRemoteID,
        _ gesture: RemoteGesture
    ) -> String {
        let base = keyPrefix + remote.rawValue + "." + button.id
        return gesture == .single ? base : base + "." + gesture.rawValue
    }

    /// 双击 / 长按默认禁用：未配置时不再继承单击映射。
    func target(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> RemoteMappingTarget {
        guard !button.voiceControlled else { return .doubaoVoice }
        guard button.remappable else { return .disabled }
        let key = storageKey(prefix, button, remote, gesture)
        if let raw = defaults.string(forKey: key),
           let stored = RemoteMappingTarget(rawValue: raw) {
            // 组合键与宏合并为一个「多步动作」入口：旧的「录制任意按键」
            // 配置继续生效，但统一显示 / 存储为 .sequence。
            return stored == .custom ? .sequence : stored
        }
        if gesture != .single {
            return .disabled
        }
        return button.defaultTarget
    }

    func setTarget(
        _ target: RemoteMappingTarget,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) {
        guard !button.voiceControlled, button.remappable else { return }
        defaults.set(
            target.rawValue,
            forKey: storageKey(prefix, button, remote, gesture)
        )
        revision += 1
    }

    func customShortcut(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> RemoteCustomShortcut? {
        storedCustomShortcut(for: button, remote: remote, gesture: gesture)
    }

    private func storedCustomShortcut(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture
    ) -> RemoteCustomShortcut? {
        let key = storageKey(customPrefix, button, remote, gesture)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RemoteCustomShortcut.self, from: data)
    }

    func appLaunch(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> RemoteAppLaunch? {
        storedAppLaunch(for: button, remote: remote, gesture: gesture)
    }

    private func storedAppLaunch(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture
    ) -> RemoteAppLaunch? {
        let key = storageKey(appPrefix, button, remote, gesture)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RemoteAppLaunch.self, from: data)
    }

    func setAppLaunch(
        _ launch: RemoteAppLaunch,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) {
        let key = storageKey(appPrefix, button, remote, gesture)
        if let data = try? JSONEncoder().encode(launch) {
            defaults.set(data, forKey: key)
            setTarget(.openApplication, for: button, remote: remote, gesture: gesture)
        }
    }

    func insertedText(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> String? {
        defaults.string(forKey: storageKey(textPrefix, button, remote, gesture))
    }

    func setInsertedText(
        _ text: String,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) {
        defaults.set(
            text,
            forKey: storageKey(textPrefix, button, remote, gesture)
        )
        setTarget(.insertText, for: button, remote: remote, gesture: gesture)
    }

    /// 读取多步动作；旧的「录制任意按键」配置自动视为一步按键动作。
    func sequence(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> RemoteActionSequence? {
        let key = storageKey(sequencePrefix, button, remote, gesture)
        if let data = defaults.data(forKey: key),
           let sequence = try? JSONDecoder().decode(
               RemoteActionSequence.self,
               from: data
           ) {
            return sequence
        }
        if defaults.string(
            forKey: storageKey(prefix, button, remote, gesture)
        ) == RemoteMappingTarget.custom.rawValue,
           let legacy = storedCustomShortcut(
               for: button,
               remote: remote,
               gesture: gesture
           ) {
            return RemoteActionSequence(shortcut: legacy)
        }
        return nil
    }

    func setSequence(
        _ sequence: RemoteActionSequence,
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) {
        let key = storageKey(sequencePrefix, button, remote, gesture)
        if let data = try? JSONEncoder().encode(sequence) {
            defaults.set(data, forKey: key)
            setTarget(.sequence, for: button, remote: remote, gesture: gesture)
        }
    }

    func targetTitle(
        for button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single
    ) -> String {
        let value = target(for: button, remote: remote, gesture: gesture)
        switch value {
        case .custom:
            return customShortcut(for: button, remote: remote, gesture: gesture)?.label
                ?? value.title
        case .insertText:
            guard let text = insertedText(
                for: button,
                remote: remote,
                gesture: gesture
            ), !text.isEmpty else { return value.title }
            return RemoteActionStep.textPreview(text)
        case .sequence:
            return sequence(
                for: button,
                remote: remote,
                gesture: gesture
            )?.summary ?? value.title
        case .openApplication:
            return appLaunch(for: button, remote: remote, gesture: gesture)?.label
                ?? value.title
        default:
            return value.title
        }
    }

    func post(
        button: RemoteButtonDefinition,
        remote: SupportedRemoteID,
        gesture: RemoteGesture = .single,
        isDown: Bool
    ) {
        let value = target(for: button, remote: remote, gesture: gesture)
        switch value {
        case .custom:
            customShortcut(for: button, remote: remote, gesture: gesture)?
                .post(isDown: isDown)
        case .insertText:
            guard isDown,
                  let text = insertedText(
                      for: button,
                      remote: remote,
                      gesture: gesture
                  ),
                  !text.isEmpty
            else { return }
            TextInjector.insert(text)
        case .sequence:
            guard isDown,
                  let sequence = sequence(
                      for: button,
                      remote: remote,
                      gesture: gesture
                  )
            else { return }
            RemoteActionRunner.shared.run(sequence)
        case .openApplication:
            guard isDown,
                  let launch = appLaunch(
                      for: button,
                      remote: remote,
                      gesture: gesture
                  )
            else { return }
            launch.open()
        default:
            value.post(isDown: isDown)
        }
    }

    func reset(_ remote: SupportedRemoteID) {
        for button in RemoteProfiles.buttons(for: remote) {
            for gesture in RemoteGesture.allCases {
                defaults.removeObject(
                    forKey: storageKey(prefix, button, remote, gesture)
                )
                defaults.removeObject(
                    forKey: storageKey(customPrefix, button, remote, gesture)
                )
                defaults.removeObject(
                    forKey: storageKey(appPrefix, button, remote, gesture)
                )
                defaults.removeObject(
                    forKey: storageKey(textPrefix, button, remote, gesture)
                )
                defaults.removeObject(
                    forKey: storageKey(sequencePrefix, button, remote, gesture)
                )
            }
        }
        revision += 1
    }
}
