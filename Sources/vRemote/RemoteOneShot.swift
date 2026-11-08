import AppKit
import ApplicationServices

/// 「向上/向下滚动」与「聚焦输入框」这类一次性动作。
enum RemoteOneShot {
    /// 正数向上滚动，负数向下滚动。
    static func scroll(lines: Int32) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(
                  scrollWheelEvent2Source: source,
                  units: .line,
                  wheelCount: 1,
                  wheel1: lines,
                  wheel2: 0,
                  wheel3: 0
              )
        else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Key.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    /// 把前台 App 的文本输入框设为焦点；部分 App 的窗口需要一点时间才可访问，
    /// 因此最多重试两次。
    static func focusInput() {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        attemptFocus(appElement: appElement, attempt: 0)
    }

    private static func attemptFocus(appElement: AXUIElement, attempt: Int) {
        if applyFocus(appElement: appElement) { return }
        guard attempt < 2 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            attemptFocus(appElement: appElement, attempt: attempt + 1)
        }
    }

    private static func applyFocus(appElement: AXUIElement) -> Bool {
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        ) == .success,
            let window = windowValue,
            CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return false }
        let root = window as! AXUIElement
        if let focused = focusedElement(in: root), isTextInput(focused) { return true }
        guard let target = firstTextInput(in: root) else { return false }
        return AXUIElementSetAttributeValue(
            target,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        ) == .success
    }

    private static var textInputRoles: Set<String> {
        [
            "AXTextField",
            "AXTextArea",
            "AXSearchField",
            "AXComboBox",
        ]
    }

    private static func isTextInput(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        ) == .success,
            let role = roleValue as? String
        else { return false }
        return textInputRoles.contains(role)
    }

    private static func focusedElement(in root: AXUIElement) -> AXUIElement? {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            root,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
            let focused = focusedValue,
            CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        return (focused as! AXUIElement)
    }

    private static func firstTextInput(in root: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth <= 18 else { return nil }
        if isTextInput(root) { return root }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            root,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success,
            let children = childrenValue as? [AXUIElement]
        else { return nil }
        for child in children.prefix(80) {
            if let found = firstTextInput(in: child, depth: depth + 1) { return found }
        }
        return nil
    }
}
