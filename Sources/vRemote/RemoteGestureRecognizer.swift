import Foundation

/// 把遥控器按键的按下 / 松开识别成单击、双击与长按。
///
/// 桥接层只上报 down / up（helper 已按 usage 去重），没有系统按键重复事件，
/// 因此可以只按时间窗口判定。实例在主线程使用。
final class RemoteGestureRecognizer {
    /// (按键 id, 手势, 是否按下)
    var onGesture: ((String, RemoteGesture, Bool) -> Void)?

    /// 只有配置了双击 / 长按的按键才走手势判定；其余按键保持即时
    /// 按下 / 松开，避免 280 ms 的单击延迟与按住不重复的问题。
    var isGestureEnabled: ((String) -> Bool)?

    private static let longPressDelay: TimeInterval = 0.60
    private static let doubleTapInterval: TimeInterval = 0.28

    private struct ActivePress {
        let buttonID: String
        var longPressTriggered: Bool
    }

    private var activePress: ActivePress?
    private var pressSequence = 0
    private var longPressTimer: DispatchWorkItem?

    private var lastRelease: (buttonID: String, at: Date)?
    private var pendingSingles: [String: Int] = [:]
    private var singleTimers: [String: DispatchWorkItem] = [:]
    private var singleSequence = 0

    func handle(buttonID: String, isDown: Bool) {
        guard isGestureEnabled?(buttonID) ?? false else {
            // 快速路径：原样转发按下 / 松开，行为与旧版完全一致。
            onGesture?(buttonID, .single, isDown)
            return
        }
        if isDown {
            beginPress(buttonID: buttonID)
        } else {
            endPress(buttonID: buttonID)
        }
    }

    /// 清空所有待发事件（不接受任何残余的单次 / 长按触发）。
    func cancelPending() {
        pressSequence += 1
        singleSequence += 1
        longPressTimer?.cancel()
        longPressTimer = nil
        // 已触发的长按只发过 down，这里补一次 up，避免目标键卡住。
        if let press = activePress, press.longPressTriggered {
            onGesture?(press.buttonID, .long, false)
        }
        activePress = nil
        lastRelease = nil
        pendingSingles.removeAll()
        for timer in singleTimers.values { timer.cancel() }
        singleTimers.removeAll()
    }

    private func beginPress(buttonID: String) {
        pressSequence += 1
        let sequence = pressSequence
        activePress = ActivePress(buttonID: buttonID, longPressTriggered: false)

        longPressTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.triggerLongPress(buttonID: buttonID, sequence: sequence)
        }
        longPressTimer = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.longPressDelay,
            execute: item
        )
    }

    private func triggerLongPress(buttonID: String, sequence: Int) {
        guard pressSequence == sequence,
              var press = activePress,
              press.buttonID == buttonID,
              !press.longPressTriggered
        else { return }
        press.longPressTriggered = true
        activePress = press
        longPressTimer = nil
        onGesture?(buttonID, .long, true)
    }

    private func endPress(buttonID: String) {
        guard let press = activePress, press.buttonID == buttonID else { return }
        activePress = nil
        pressSequence += 1
        longPressTimer?.cancel()
        longPressTimer = nil

        if press.longPressTriggered {
            // 长按已在按下阶段触发，松手只补一次 up，不再产生单击 / 双击。
            lastRelease = nil
            onGesture?(buttonID, .long, false)
            return
        }

        let now = Date()
        if let last = lastRelease, last.buttonID == buttonID,
           now.timeIntervalSince(last.at) < Self.doubleTapInterval {
            lastRelease = nil
            cancelPendingSingle(buttonID: buttonID)
            emit(.double, buttonID: buttonID)
            return
        }

        lastRelease = (buttonID, now)
        scheduleSingle(buttonID: buttonID)
    }

    private func scheduleSingle(buttonID: String) {
        singleSequence += 1
        let sequence = singleSequence
        pendingSingles[buttonID] = sequence

        singleTimers[buttonID]?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.triggerSingle(buttonID: buttonID, sequence: sequence)
        }
        singleTimers[buttonID] = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.doubleTapInterval,
            execute: item
        )
    }

    private func triggerSingle(buttonID: String, sequence: Int) {
        guard pendingSingles[buttonID] == sequence else { return }
        pendingSingles[buttonID] = nil
        singleTimers[buttonID] = nil
        emit(.single, buttonID: buttonID)
    }

    private func cancelPendingSingle(buttonID: String) {
        pendingSingles[buttonID] = nil
        singleTimers.removeValue(forKey: buttonID)?.cancel()
    }

    /// 单击 / 双击都只产生一次瞬时动作。
    private func emit(_ gesture: RemoteGesture, buttonID: String) {
        onGesture?(buttonID, gesture, true)
        onGesture?(buttonID, gesture, false)
    }
}
