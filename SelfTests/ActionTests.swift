import CoreGraphics
import Foundation

// 动作步骤、映射迁移、语音步骤判定和日志轮转的行为固化。
// 不触发任何真实按键 / 剪贴板 / 音频操作。

func runActionSelfTests() {
    testActionStepCoding()
    testActionStepFormatting()
    testMappingMigration()
    testVoiceStepWatcher()
    testLogRotation()
}

private func testActionStepCoding() {
    let shortcut = RemoteCustomShortcut(
        keyCode: 0x08,
        flags: CGEventFlags.maskCommand.rawValue,
        label: "⌘C"
    )
    let app = RemoteAppLaunch(bundleID: "com.example.editor", label: "Editor")
    let sequence = RemoteActionSequence(steps: [
        .shortcut(shortcut),
        .insertText("第一行\n第二行"),
        .openApplication(app),
        .focusInput,
        .wait(750),
        .voice,
    ])

    do {
        let data = try JSONEncoder().encode(sequence)
        let decoded = try JSONDecoder().decode(
            RemoteActionSequence.self,
            from: data
        )
        require(decoded == sequence, "动作序列 JSON 往返不一致")
    } catch {
        require(false, "动作序列 JSON 编解码抛错: \(error)")
    }

    require(!sequence.isEmpty, "动作序列不应为空")
    require(RemoteActionSequence().isEmpty, "空动作序列应为空")
    require(
        RemoteActionSequence(shortcut: shortcut).steps == [.shortcut(shortcut)],
        "单步动作应等价于一个按键步骤"
    )
    pass("动作步骤 JSON 往返（按键/文本/App/聚焦/等待/语音）")
}

private func testActionStepFormatting() {
    require(
        RemoteActionStep.textPreview("abcdefghijklmnop").count == 13,
        "长文本预览应截断为 12 个字符加省略号"
    )
    require(
        !RemoteActionStep.textPreview("abcdefghijklmnop").hasSuffix("nop"),
        "长文本预览不应保留尾部字符"
    )
    require(
        RemoteActionStep.textPreview("  第一行\n第二行  ") == "第一行 第二行",
        "文本预览应压平换行并去掉首尾空白"
    )
    require(RemoteActionStep.secondsText(500) == "0.5s", "500ms 应显示为 0.5s")
    require(RemoteActionStep.secondsText(1_000) == "1s", "1000ms 应显示为 1s")
    require(RemoteActionStep.secondsText(2_500) == "2.5s", "2500ms 应显示为 2.5s")

    let shortcut = RemoteCustomShortcut(keyCode: 0x09, flags: 0, label: "Tab")
    let app = RemoteAppLaunch(bundleID: "com.example.editor", label: "Editor")
    let sequence = RemoteActionSequence(steps: [
        .shortcut(shortcut),
        .openApplication(app),
        .voice,
    ])
    require(
        sequence.summary.hasPrefix("Tab → Editor"),
        "动作摘要应以前两步的名称开头"
    )
    require(
        sequence.summary.contains("3"),
        "超过两步时动作摘要应带上总步数"
    )
    require(
        RemoteActionSequence().summary != sequence.summary,
        "空动作摘要不应与多步动作相同"
    )
    pass("动作步骤与摘要文案格式化")
}

private func testMappingMigration() {
    let suiteName = "vremote.selftest.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fail("无法创建测试用 UserDefaults")
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = RemoteMappingStore(defaults: defaults)

    guard let button = RemoteProfiles.buttons(for: .chromecast)
        .first(where: { $0.id == "05" }) else {
        fail("找不到测试按键 05")
    }
    let targetKey = "remoteMapping.chromecast.05"
    let customKey = "remoteCustomMapping.chromecast.05"

    // 1. 旧「录制任意按键」配置迁移为一步按键动作。
    let legacy = RemoteCustomShortcut(
        keyCode: 0x7B,
        flags: CGEventFlags.maskControl.rawValue,
        label: "⌃←"
    )
    defaults.set(RemoteMappingTarget.custom.rawValue, forKey: targetKey)
    do {
        defaults.set(try JSONEncoder().encode(legacy), forKey: customKey)
    } catch {
        require(false, "旧按键配置编码失败: \(error)")
    }
    require(
        store.target(for: button, remote: .chromecast) == .sequence,
        "旧按键映射应显示为多步动作"
    )
    require(
        store.sequence(for: button, remote: .chromecast)?.steps == [.shortcut(legacy)],
        "旧按键映射应读取为一步按键动作"
    )
    require(
        store.targetTitle(for: button, remote: .chromecast) == legacy.label,
        "旧按键映射标题应显示原按键名"
    )

    // 2. 目标仍是 custom 但没有按键数据时，不应伪造动作。
    defaults.removeObject(forKey: customKey)
    require(
        store.sequence(for: button, remote: .chromecast) == nil,
        "缺少按键数据时不应生成动作"
    )

    // 3. 目标已改成其他动作时，不应把残留的旧按键数据当成动作。
    defaults.set(RemoteMappingTarget.commandC.rawValue, forKey: targetKey)
    do {
        defaults.set(try JSONEncoder().encode(legacy), forKey: customKey)
    } catch {
        require(false, "旧按键配置编码失败: \(error)")
    }
    require(
        store.sequence(for: button, remote: .chromecast) == nil,
        "非 custom 目标不应继承旧按键数据"
    )

    // 4. 新多步动作的读写。
    let sequence = RemoteActionSequence(steps: [.insertText("测试文本"), .wait(500)])
    store.setSequence(sequence, for: button, remote: .chromecast)
    require(
        store.target(for: button, remote: .chromecast) == .sequence,
        "保存多步动作后目标应为多步动作"
    )
    require(
        store.sequence(for: button, remote: .chromecast) == sequence,
        "多步动作读写应一致"
    )
    require(
        store.targetTitle(for: button, remote: .chromecast)
            .hasPrefix("测试文本 →"),
        "多步动作标题应显示各步骤摘要"
    )

    // 5. 固定文本的读写。
    store.setInsertedText("固定文本", for: button, remote: .chromecast)
    require(
        store.target(for: button, remote: .chromecast) == .insertText,
        "保存固定文本后目标应为文本注入"
    )
    require(
        store.insertedText(for: button, remote: .chromecast) == "固定文本",
        "固定文本读写应一致"
    )

    // 6. 重置后应回到按钮默认目标，且不残留文本 / 动作数据。
    store.reset(.chromecast)
    require(
        store.target(for: button, remote: .chromecast) == button.defaultTarget,
        "重置后目标应回到默认值"
    )
    require(
        store.sequence(for: button, remote: .chromecast) == nil,
        "重置后不应残留多步动作"
    )
    require(
        store.insertedText(for: button, remote: .chromecast) == nil,
        "重置后不应残留固定文本"
    )
    pass("映射迁移：旧按键→多步动作、固定文本读写、重置清理")
}

private func testVoiceStepWatcher() {
    let start = Date(timeIntervalSince1970: 1_000)

    // 先开始录音，再停止。
    var watcher = VoiceStepWatcher(beganAt: start)
    require(
        watcher.update(recording: false, at: start.addingTimeInterval(0.5)) == .wait,
        "未观察到录音时不应提前结束"
    )
    require(
        watcher.update(recording: true, at: start.addingTimeInterval(1.0)) == .wait,
        "开始录音后应继续等待"
    )
    require(
        watcher.update(recording: false, at: start.addingTimeInterval(1.6))
            == .finished(.recordingStopped),
        "录音停止后应结束语音步骤"
    )
    require(
        watcher.update(recording: true, at: start.addingTimeInterval(2.0))
            == .finished(.recordingStopped),
        "结束后判定应保持幂等"
    )

    // 豆包一直没开始录音：2 秒后跳过，不白等 30 秒。
    var neverStarted = VoiceStepWatcher(beganAt: start)
    require(
        neverStarted.update(recording: false, at: start.addingTimeInterval(1.9))
            == .wait,
        "2 秒宽限期内不应跳过"
    )
    require(
        neverStarted.update(recording: false, at: start.addingTimeInterval(2.0))
            == .finished(.neverStarted),
        "超过 2 秒仍未开始录音应结束"
    )

    // 一直处于录音：30 秒超时。
    var timeout = VoiceStepWatcher(beganAt: start)
    require(
        timeout.update(recording: true, at: start.addingTimeInterval(1.0)) == .wait,
        "录音中应继续等待"
    )
    require(
        timeout.update(recording: true, at: start.addingTimeInterval(29.9)) == .wait,
        "未到 30 秒不应超时"
    )
    require(
        timeout.update(recording: true, at: start.addingTimeInterval(30.0))
            == .finished(.timeout),
        "满 30 秒应超时结束"
    )

    // 很晚才停止录音：也按录音停止处理，而不是超时。
    var lateStop = VoiceStepWatcher(beganAt: start)
    _ = lateStop.update(recording: true, at: start.addingTimeInterval(0.5))
    require(
        lateStop.update(recording: false, at: start.addingTimeInterval(29.5))
            == .finished(.recordingStopped),
        "30 秒内停下都按正常结束处理"
    )
    pass("语音步骤判定：开始→停止、2 秒跳过、30 秒超时、幂等")
}

private func testLogRotation() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("vremote-logtest-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    do {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    } catch {
        require(false, "无法创建日志测试目录: \(error)")
    }

    let current = directory.appendingPathComponent("RemoteMic.log")
    let archive = directory.appendingPathComponent("RemoteMic.log.1")

    do {
        try "第一份".write(to: current, atomically: true, encoding: .utf8)
    } catch {
        require(false, "写入测试日志失败: \(error)")
    }
    require(
        Log.rotateFiles(current: current, archive: archive),
        "存在日志时应轮转成功"
    )
    require(
        !FileManager.default.fileExists(atPath: current.path),
        "轮转后当前日志应被移走"
    )
    require(
        (try? String(contentsOf: archive, encoding: .utf8)) == "第一份",
        "轮转后上一份日志内容应保留"
    )

    do {
        try "第二份".write(to: current, atomically: true, encoding: .utf8)
    } catch {
        require(false, "写入测试日志失败: \(error)")
    }
    require(
        Log.rotateFiles(current: current, archive: archive),
        "第二次轮转应成功"
    )
    require(
        (try? String(contentsOf: archive, encoding: .utf8)) == "第二份",
        "第二次轮转应替换更早的上一份"
    )
    require(
        !Log.rotateFiles(current: current, archive: archive),
        "当前日志不存在时轮转应返回 false"
    )
    pass("日志轮转：移动、替换上一份、缺失时跳过")
}
