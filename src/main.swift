import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import GameController

struct CLIOptions {
    let configPath: String
    let dryRunOverride: Bool?
    let promptAccessibility: Bool

    static func parse(arguments: [String]) throws -> CLIOptions {
        var configPath = "config/mappings.json"
        var dryRunOverride: Bool?
        var promptAccessibility = false

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config":
                let valueIndex = index + 1
                guard valueIndex < arguments.count else {
                    throw BridgeError.invalidArguments("Missing value for --config")
                }
                configPath = arguments[valueIndex]
                index = valueIndex + 1
            case "--dry-run":
                dryRunOverride = true
                index += 1
            case "--no-dry-run":
                dryRunOverride = false
                index += 1
            case "--help", "-h":
                Self.printHelp()
                Foundation.exit(0)
            case "--prompt-accessibility":
                promptAccessibility = true
                index += 1
            default:
                throw BridgeError.invalidArguments("Unknown argument: \(argument)")
            }
        }

        return CLIOptions(
            configPath: configPath,
            dryRunOverride: dryRunOverride,
            promptAccessibility: promptAccessibility
        )
    }

    static func printHelp() {
        let help = """
        Stadia macOS Controller Bridge

        Usage:
          swift run stadia-controller-bridge [options]

        Options:
          --config <path>   Path to mappings config JSON (default: config/mappings.json)
          --dry-run         Force dry-run mode (no key/command execution)
          --no-dry-run      Force live mode
          --prompt-accessibility  Ask macOS to show Accessibility permission prompt
          --help, -h        Show this help text
        """
        print(help)
    }
}

struct BridgeConfig: Decodable {
    let appProfiles: [String: String]
    let profiles: [String: ProfileConfig]
    let alwaysOn: AlwaysOnConfig?
    let safety: SafetyConfig
}

struct AlwaysOnConfig: Decodable {
    let analog: AnalogConfig?
    let mappings: [String: MappingConfig]?
}

struct ProfileConfig: Decodable {
    let enabled: Bool?
    let analog: AnalogConfig?
    let mappings: [String: MappingConfig]
}

struct AnalogConfig: Decodable {
    let leftStickVerticalScroll: StickVerticalScrollConfig?
    let rightStickVerticalScroll: StickVerticalScrollConfig?
    let rightStickPointer: StickPointerConfig?
    let rightStickVerticalActions: StickVerticalActionConfig?
    let rightStickHorizontalActions: StickHorizontalActionConfig?
}

struct StickVerticalScrollConfig: Decodable {
    let enabled: Bool?
    let deadzone: Double?
    let intervalMs: Int?
    let minLinesPerTick: Int?
    let maxLinesPerTick: Int?
    let responseExponent: Double?
    let invert: Bool?
}

struct StickPointerConfig: Decodable {
    let enabled: Bool?
    let deadzone: Double?
    let intervalMs: Int?
    let minPixelsPerTick: Int?
    let maxPixelsPerTick: Int?
    let responseExponent: Double?
    let invertX: Bool?
    let invertY: Bool?
}

struct StickHorizontalActionConfig: Decodable {
    let enabled: Bool?
    let deadzone: Double?
    let repeatIntervalMs: Int?
    let edgeTrigger: Bool?
    let leftAction: ActionConfig?
    let rightAction: ActionConfig?
}

struct StickVerticalActionConfig: Decodable {
    let enabled: Bool?
    let deadzone: Double?
    let repeatIntervalMs: Int?
    let edgeTrigger: Bool?
    let upAction: ActionConfig?
    let downAction: ActionConfig?
}

struct MappingConfig: Decodable {
    let action: ActionConfig
    let debounceMs: Int?
    let edgeTrigger: Bool?
}

struct SafetyConfig: Decodable {
    let dryRun: Bool
    let emergencyToggleButton: String?
}

struct ActionConfig: Decodable {
    let type: ActionType
    let keyCode: Int?
    let modifiers: [String]?
    let command: String?
    let script: String?
    let ghosttyAction: String?
    let text: String?
    let mouseButton: String?
    let pressEnter: Bool?
    let delayMs: Int?
    let preKeyCode: Int?
    let preModifiers: [String]?
    let preDelayMs: Int?
    let description: String?
}

enum ActionType: String, Decodable {
    case keystroke
    case holdKeystroke
    case shell
    case applescript
    case ghosttyAction
    case text
    case mouseClick
}

struct ControllerEvent {
    let controllerID: String
    let button: String
    let pressed: Bool
    let timestamp: Date
    let isRepeat: Bool
}

enum BridgeError: Error, LocalizedError {
    case invalidArguments(String)
    case configLoadFailed(String)
    case configValidationFailed(String)
    case actionExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        case .configLoadFailed(let message):
            return message
        case .configValidationFailed(let message):
            return message
        case .actionExecutionFailed(let message):
            return message
        }
    }
}

struct ConfigLoader {
    static func load(path: String) throws -> BridgeConfig {
        let absolutePath = absolutePath(for: path)
        let data: Data

        do {
            data = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
        } catch {
            throw BridgeError.configLoadFailed("Failed to read config at \(absolutePath): \(error.localizedDescription)")
        }

        let decoder = JSONDecoder()
        let config: BridgeConfig
        do {
            config = try decoder.decode(BridgeConfig.self, from: data)
        } catch {
            throw BridgeError.configLoadFailed("Failed to decode JSON config: \(error.localizedDescription)")
        }

        try validate(config: config)
        return config
    }

    static func absolutePath(for path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
    }

    private static func validate(config: BridgeConfig) throws {
        for (bundleID, profileName) in config.appProfiles {
            guard config.profiles[profileName] != nil else {
                throw BridgeError.configValidationFailed(
                    "appProfiles entry '\(bundleID)' references unknown profile '\(profileName)'"
                )
            }
        }

        for (profileName, profile) in config.profiles {
            for (button, mapping) in profile.mappings {
                try validateAction(mapping.action, context: "Profile '\(profileName)' button '\(button)'")
            }

            if let analogConfig = profile.analog {
                if let left = analogConfig.leftStickVerticalScroll {
                    try validateVerticalScrollConfig(left, profileName: profileName, configName: "leftStickVerticalScroll")
                }
                if let right = analogConfig.rightStickVerticalScroll {
                    try validateVerticalScrollConfig(right, profileName: profileName, configName: "rightStickVerticalScroll")
                }
                if let pointer = analogConfig.rightStickPointer {
                    try validateStickPointerConfig(pointer, profileName: profileName, configName: "rightStickPointer")
                }
                if let verticalActions = analogConfig.rightStickVerticalActions {
                    try validateStickVerticalActionConfig(
                        verticalActions,
                        profileName: profileName,
                        configName: "rightStickVerticalActions"
                    )
                }
                if let horizontalActions = analogConfig.rightStickHorizontalActions {
                    try validateStickHorizontalActionConfig(
                        horizontalActions,
                        profileName: profileName,
                        configName: "rightStickHorizontalActions"
                    )
                }
            }
        }

        if let alwaysOn = config.alwaysOn {
            if let mappings = alwaysOn.mappings {
                for (button, mapping) in mappings {
                    try validateAction(mapping.action, context: "alwaysOn button '\(button)'")
                }
            }

            if let analogConfig = alwaysOn.analog {
                if let left = analogConfig.leftStickVerticalScroll {
                    try validateVerticalScrollConfig(left, profileName: "alwaysOn", configName: "leftStickVerticalScroll")
                }
                if let right = analogConfig.rightStickVerticalScroll {
                    try validateVerticalScrollConfig(right, profileName: "alwaysOn", configName: "rightStickVerticalScroll")
                }
                if let pointer = analogConfig.rightStickPointer {
                    try validateStickPointerConfig(pointer, profileName: "alwaysOn", configName: "rightStickPointer")
                }
                if let verticalActions = analogConfig.rightStickVerticalActions {
                    try validateStickVerticalActionConfig(
                        verticalActions,
                        profileName: "alwaysOn",
                        configName: "rightStickVerticalActions"
                    )
                }
                if let horizontalActions = analogConfig.rightStickHorizontalActions {
                    try validateStickHorizontalActionConfig(
                        horizontalActions,
                        profileName: "alwaysOn",
                        configName: "rightStickHorizontalActions"
                    )
                }
            }
        }
    }

    private static func validateAction(_ action: ActionConfig, context: String) throws {
        switch action.type {
        case .keystroke:
            guard action.keyCode != nil else {
                throw BridgeError.configValidationFailed("\(context) keystroke action requires keyCode")
            }
        case .holdKeystroke:
            guard action.keyCode != nil else {
                throw BridgeError.configValidationFailed("\(context) holdKeystroke action requires keyCode")
            }
        case .shell:
            guard let command = action.command, !command.isEmpty else {
                throw BridgeError.configValidationFailed("\(context) shell action requires command")
            }
        case .applescript:
            guard let script = action.script, !script.isEmpty else {
                throw BridgeError.configValidationFailed("\(context) applescript action requires script")
            }
        case .ghosttyAction:
            guard let ghosttyAction = action.ghosttyAction, !ghosttyAction.isEmpty else {
                throw BridgeError.configValidationFailed("\(context) ghosttyAction action requires ghosttyAction")
            }
        case .text:
            guard let text = action.text, !text.isEmpty else {
                throw BridgeError.configValidationFailed("\(context) text action requires text")
            }
        case .mouseClick:
            if let mouseButton = action.mouseButton {
                let normalized = mouseButton.lowercased()
                guard ["left", "right", "center"].contains(normalized) else {
                    throw BridgeError.configValidationFailed("\(context) mouseClick action mouseButton must be left, right, or center")
                }
            }
        }
    }

    private static func validateVerticalScrollConfig(
        _ analog: StickVerticalScrollConfig,
        profileName: String,
        configName: String
    ) throws {
        if let deadzone = analog.deadzone, deadzone < 0 || deadzone >= 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) deadzone must be >= 0 and < 1")
        }
        if let intervalMs = analog.intervalMs, intervalMs < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) intervalMs must be >= 1")
        }
        if let minLines = analog.minLinesPerTick, minLines < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) minLinesPerTick must be >= 1")
        }
        if let maxLines = analog.maxLinesPerTick, maxLines < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) maxLinesPerTick must be >= 1")
        }
        if let minLines = analog.minLinesPerTick,
           let maxLines = analog.maxLinesPerTick,
           maxLines < minLines {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) maxLinesPerTick must be >= minLinesPerTick")
        }
        if let responseExponent = analog.responseExponent, responseExponent <= 0 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) responseExponent must be > 0")
        }
    }

    private static func validateStickPointerConfig(
        _ pointer: StickPointerConfig,
        profileName: String,
        configName: String
    ) throws {
        if let deadzone = pointer.deadzone, deadzone < 0 || deadzone >= 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) deadzone must be >= 0 and < 1")
        }
        if let intervalMs = pointer.intervalMs, intervalMs < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) intervalMs must be >= 1")
        }
        if let minPixels = pointer.minPixelsPerTick, minPixels < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) minPixelsPerTick must be >= 1")
        }
        if let maxPixels = pointer.maxPixelsPerTick, maxPixels < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) maxPixelsPerTick must be >= 1")
        }
        if let minPixels = pointer.minPixelsPerTick,
           let maxPixels = pointer.maxPixelsPerTick,
           maxPixels < minPixels {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) maxPixelsPerTick must be >= minPixelsPerTick")
        }
        if let responseExponent = pointer.responseExponent, responseExponent <= 0 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) responseExponent must be > 0")
        }
    }

    private static func validateStickHorizontalActionConfig(
        _ config: StickHorizontalActionConfig,
        profileName: String,
        configName: String
    ) throws {
        if let deadzone = config.deadzone, deadzone < 0 || deadzone >= 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) deadzone must be >= 0 and < 1")
        }
        if let repeatIntervalMs = config.repeatIntervalMs, repeatIntervalMs < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) repeatIntervalMs must be >= 1")
        }

        guard let leftAction = config.leftAction else {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) requires leftAction")
        }
        guard let rightAction = config.rightAction else {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) requires rightAction")
        }

        try validateAction(leftAction, context: "Profile '\(profileName)' \(configName) leftAction")
        try validateAction(rightAction, context: "Profile '\(profileName)' \(configName) rightAction")
    }

    private static func validateStickVerticalActionConfig(
        _ config: StickVerticalActionConfig,
        profileName: String,
        configName: String
    ) throws {
        if let deadzone = config.deadzone, deadzone < 0 || deadzone >= 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) deadzone must be >= 0 and < 1")
        }
        if let repeatIntervalMs = config.repeatIntervalMs, repeatIntervalMs < 1 {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) repeatIntervalMs must be >= 1")
        }
        guard config.upAction != nil || config.downAction != nil else {
            throw BridgeError.configValidationFailed("Profile '\(profileName)' \(configName) requires upAction or downAction")
        }
        if let upAction = config.upAction {
            try validateAction(upAction, context: "Profile '\(profileName)' \(configName) upAction")
        }
        if let downAction = config.downAction {
            try validateAction(downAction, context: "Profile '\(profileName)' \(configName) downAction")
        }
    }
}

final class ProfileResolver {
    private let appProfiles: [String: String]

    init(appProfiles: [String: String]) {
        self.appProfiles = appProfiles
    }

    func resolveActiveProfile() -> String? {
        guard let bundleID = currentFrontmostBundleID() else {
            return nil
        }

        return appProfiles[bundleID]
    }

    func currentFrontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

final class ActionExecutor {
    private let dryRun: Bool
    private var activeHeldModifierFlags = CGEventFlags()
    private let ghosttyBundleID = "com.mitchellh.ghostty"

    init(dryRun: Bool) {
        self.dryRun = dryRun
    }

    func execute(action: ActionConfig, profile: String, button: String) throws {
        let description = action.description ?? "(no description)"

        if dryRun {
            print("[DRY-RUN] profile=\(profile) button=\(button) action=\(description)")
            return
        }

        switch action.type {
        case .keystroke:
            guard let keyCodeValue = action.keyCode else {
                throw BridgeError.actionExecutionFailed("Keystroke action missing keyCode")
            }

            if !AXIsProcessTrusted() {
                throw BridgeError.actionExecutionFailed("Accessibility permission is required for keystroke injection")
            }

            let keyCode = CGKeyCode(keyCodeValue)
            let flags = effectiveModifierFlags(from: action.modifiers ?? [])
            try postKeystroke(keyCode: keyCode, modifiers: flags)
            print("[ACTION] keystroke keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")

        case .holdKeystroke:
            throw BridgeError.actionExecutionFailed("holdKeystroke must be handled as press/release lifecycle")

        case .shell:
            guard let command = action.command else {
                throw BridgeError.actionExecutionFailed("Shell action missing command")
            }

            try runProcess(executable: "/bin/zsh", arguments: ["-lc", command])
            print("[ACTION] shell profile=\(profile) button=\(button) command=\(command)")

        case .applescript:
            guard let script = action.script else {
                throw BridgeError.actionExecutionFailed("AppleScript action missing script")
            }

            try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
            print("[ACTION] applescript profile=\(profile) button=\(button)")

        case .ghosttyAction:
            guard let ghosttyAction = action.ghosttyAction else {
                throw BridgeError.actionExecutionFailed("ghosttyAction action missing ghosttyAction")
            }

            try executeGhosttyAction(ghosttyAction)
            print("[ACTION] ghostty-action action=\(ghosttyAction) profile=\(profile) button=\(button)")

        case .text:
            guard let text = action.text else {
                throw BridgeError.actionExecutionFailed("Text action missing text")
            }

            if !AXIsProcessTrusted() {
                throw BridgeError.actionExecutionFailed("Accessibility permission is required for typed text injection")
            }

            if let preKeyCodeValue = action.preKeyCode {
                let preFlags = modifierFlags(from: action.preModifiers ?? [])
                try postKeystroke(keyCode: CGKeyCode(preKeyCodeValue), modifiers: preFlags)

                if let preDelayMs = action.preDelayMs, preDelayMs > 0 {
                    Thread.sleep(forTimeInterval: Double(preDelayMs) / 1000.0)
                }
            }

            try postText(text)

            if let delayMs = action.delayMs, delayMs > 0 {
                Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
            }

            if action.pressEnter == true {
                try postKeystroke(keyCode: 36, modifiers: [])
            }

            print("[ACTION] text profile=\(profile) button=\(button) text=\(text)")

        case .mouseClick:
            try clickMouse(
                button: mouseButton(from: action.mouseButton),
                profile: profile,
                source: button
            )
        }
    }

    func beginHold(action: ActionConfig, profile: String, button: String) throws {
        guard action.type == .holdKeystroke else {
            throw BridgeError.actionExecutionFailed("beginHold requires holdKeystroke action")
        }
        guard let keyCodeValue = action.keyCode else {
            throw BridgeError.actionExecutionFailed("holdKeystroke action missing keyCode")
        }

        if dryRun {
            print("[DRY-RUN] hold-begin profile=\(profile) button=\(button) keyCode=\(keyCodeValue)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for hold keystroke injection")
        }

        let keyCode = CGKeyCode(keyCodeValue)
        let flags = modifierFlags(from: action.modifiers ?? [])
        try postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: flags)
        if let heldFlag = modifierFlag(forHeldKeyCode: keyCode) {
            activeHeldModifierFlags.formUnion(heldFlag)
        }
        print("[ACTION] hold-begin keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")
    }

    func endHold(action: ActionConfig, profile: String, button: String) throws {
        guard action.type == .holdKeystroke else {
            throw BridgeError.actionExecutionFailed("endHold requires holdKeystroke action")
        }
        guard let keyCodeValue = action.keyCode else {
            throw BridgeError.actionExecutionFailed("holdKeystroke action missing keyCode")
        }

        if dryRun {
            print("[DRY-RUN] hold-end profile=\(profile) button=\(button) keyCode=\(keyCodeValue)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for hold keystroke injection")
        }

        let keyCode = CGKeyCode(keyCodeValue)
        if let heldFlag = modifierFlag(forHeldKeyCode: keyCode) {
            activeHeldModifierFlags.remove(heldFlag)
        }
        let flags = modifierFlags(from: action.modifiers ?? [])
        try postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: flags)
        print("[ACTION] hold-end keyCode=\(keyCodeValue) profile=\(profile) button=\(button)")
    }

    func scrollVertical(lines: Int, profile: String, source: String) throws {
        guard lines != 0 else {
            return
        }

        if dryRun {
            print("[DRY-RUN] scroll profile=\(profile) source=\(source) lines=\(lines)")
            return
        }

        if currentFrontmostBundleID() == ghosttyBundleID {
            do {
                try executeGhosttyScroll(y: lines)
                print("[ACTION] ghostty-scroll profile=\(profile) source=\(source) lines=\(lines)")
                return
            } catch {
                print("[WARN] ghostty-scroll fallback to system scroll: \(error.localizedDescription)")
            }
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for scroll injection")
        }

        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let scrollEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .line,
                wheelCount: 1,
                wheel1: Int32(lines),
                wheel2: 0,
                wheel3: 0
              ) else {
            throw BridgeError.actionExecutionFailed("Failed to create scroll event")
        }

        scrollEvent.post(tap: .cghidEventTap)
        print("[ACTION] scroll profile=\(profile) source=\(source) lines=\(lines)")
    }

    func movePointerRelative(dx: Int, dy: Int, profile: String, source: String) throws {
        guard dx != 0 || dy != 0 else {
            return
        }

        if dryRun {
            print("[DRY-RUN] pointer profile=\(profile) source=\(source) dx=\(dx) dy=\(dy)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for pointer injection")
        }

        let current = NSEvent.mouseLocation
        let target = CGPoint(x: current.x + CGFloat(dx), y: current.y + CGFloat(dy))

        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let moveEvent = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .mouseMoved,
                mouseCursorPosition: target,
                mouseButton: .left
              ) else {
            throw BridgeError.actionExecutionFailed("Failed to create pointer move event")
        }

        moveEvent.post(tap: .cghidEventTap)
        print("[ACTION] pointer profile=\(profile) source=\(source) dx=\(dx) dy=\(dy)")
    }

    func clickMouse(button: CGMouseButton, profile: String, source: String) throws {
        if dryRun {
            print("[DRY-RUN] mouse-click profile=\(profile) source=\(source) button=\(button.rawValue)")
            return
        }

        if !AXIsProcessTrusted() {
            throw BridgeError.actionExecutionFailed("Accessibility permission is required for mouse click injection")
        }

        let location = NSEvent.mouseLocation
        let mouseType: CGEventType
        let mouseUpType: CGEventType

        switch button {
        case .left:
            mouseType = .leftMouseDown
            mouseUpType = .leftMouseUp
        case .right:
            mouseType = .rightMouseDown
            mouseUpType = .rightMouseUp
        case .center:
            mouseType = .otherMouseDown
            mouseUpType = .otherMouseUp
        @unknown default:
            mouseType = .leftMouseDown
            mouseUpType = .leftMouseUp
        }

        guard let eventSource = CGEventSource(stateID: .hidSystemState),
              let mouseDown = CGEvent(
                mouseEventSource: eventSource,
                mouseType: mouseType,
                mouseCursorPosition: location,
                mouseButton: button
              ),
              let mouseUp = CGEvent(
                mouseEventSource: eventSource,
                mouseType: mouseUpType,
                mouseCursorPosition: location,
                mouseButton: button
              ) else {
            throw BridgeError.actionExecutionFailed("Failed to create mouse click event")
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        print("[ACTION] mouse-click profile=\(profile) source=\(source) button=\(button.rawValue)")
    }

    private func modifierFlags(from modifiers: [String]) -> CGEventFlags {
        modifiers.reduce(CGEventFlags()) { partial, modifier in
            switch modifier.lowercased() {
            case "command", "cmd":
                return partial.union(.maskCommand)
            case "shift":
                return partial.union(.maskShift)
            case "option", "alt":
                return partial.union(.maskAlternate)
            case "control", "ctrl":
                return partial.union(.maskControl)
            default:
                return partial
            }
        }
    }

    private func mouseButton(from value: String?) -> CGMouseButton {
        switch value?.lowercased() {
        case "right":
            return .right
        case "center":
            return .center
        default:
            return .left
        }
    }

    private func effectiveModifierFlags(from modifiers: [String]) -> CGEventFlags {
        activeHeldModifierFlags.union(modifierFlags(from: modifiers))
    }

    private func modifierFlag(forHeldKeyCode keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 54, 55:
            return .maskCommand
        case 56, 60:
            return .maskShift
        case 58, 61:
            return .maskAlternate
        case 59, 62:
            return .maskControl
        default:
            return nil
        }
    }

    private func postKeystroke(keyCode: CGKeyCode, modifiers: CGEventFlags) throws {
        try postKeyEvent(keyCode: keyCode, keyDown: true, modifiers: modifiers)
        try postKeyEvent(keyCode: keyCode, keyDown: false, modifiers: modifiers)
    }


    private func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool, modifiers: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            throw BridgeError.actionExecutionFailed("Failed to create keyboard event")
        }

        event.flags = modifiers
        event.post(tap: .cghidEventTap)
    }

    private func postText(_ text: String) throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw BridgeError.actionExecutionFailed("Failed to create keyboard source for text action")
        }

        for scalar in text.utf16 {
            var character = scalar
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                throw BridgeError.actionExecutionFailed("Failed to create keyboard event for text action")
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func executeGhosttyAction(_ action: String) throws {
        let escapedAction = action
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Ghostty"
          perform action "\(escapedAction)" on focused terminal of selected tab of front window
        end tell
        """
        try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func executeGhosttyScroll(y: Int) throws {
        let script = """
        tell application "Ghostty"
          send mouse scroll x 0 y \(y) to focused terminal of selected tab of front window
        end tell
        """
        try runProcess(executable: "/usr/bin/osascript", arguments: ["-e", script])
    }

    private func currentFrontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw BridgeError.actionExecutionFailed("Process failed to start: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            throw BridgeError.actionExecutionFailed("Process exited with status \(process.terminationStatus)")
        }
    }
}

final class ControllerBridge: NSObject {
    private var config: BridgeConfig
    private var profileResolver: ProfileResolver
    private var actionExecutor: ActionExecutor

    private let configPath: String
    private let dryRunOverride: Bool?

    private var buttonStates: [String: Bool] = [:]
    private var lastTriggeredAt: [String: Date] = [:]
    private var lastAnalogScrollAt: [String: Date] = [:]
    private var lastAnalogActionAt: [String: Date] = [:]
    private var polledButtonStates: [String: Bool] = [:]
    private var analogDirectionStates: [String: Int] = [:]
    private var activeGamepads: [String: GCExtendedGamepad] = [:]
    private var activeControllers: [String: GCController] = [:]
    private var pollingTimer: Timer?
    private var configWatchTimer: Timer?
    private var configLastModified: Date?
    private var activeHolds: [String: (profileName: String, action: ActionConfig)] = [:]
    private var bridgeEnabled = true

    init(config: BridgeConfig, configPath: String, dryRunOverride: Bool?, promptAccessibility: Bool) {
        self.config = config
        self.profileResolver = ProfileResolver(appProfiles: config.appProfiles)
        self.configPath = configPath
        self.dryRunOverride = dryRunOverride

        let dryRun = Self.effectiveDryRun(for: config, dryRunOverride: dryRunOverride)
        self.actionExecutor = ActionExecutor(dryRun: dryRun)
        super.init()

        print("Bridge mode: \(dryRun ? "dry-run" : "live")")
        if !dryRun && !AXIsProcessTrusted() {
            print("WARNING: Accessibility permission is not granted. Keystroke actions will fail until enabled.")
            if promptAccessibility {
                promptForAccessibilityPermission()
            }
        }
    }

    deinit {
        pollingTimer?.invalidate()
        configWatchTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        print("[INFO] GCController.shouldMonitorBackgroundEvents=true")
        registerControllerNotifications()
        startConfigWatcher()

        let existingControllers = GCController.controllers()
        if existingControllers.isEmpty {
            print("No controller currently connected. Waiting for Stadia controller...")
        } else {
            existingControllers.forEach(registerHandlers)
        }

        GCController.startWirelessControllerDiscovery {
            print("Wireless discovery finished")
        }

        print("Bridge started. Press Ctrl+C to stop.")
        RunLoop.main.run()
    }

    private static func effectiveDryRun(for config: BridgeConfig, dryRunOverride: Bool?) -> Bool {
        dryRunOverride ?? config.safety.dryRun
    }

    private func registerControllerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleControllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleControllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc
    private func handleControllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        registerHandlers(for: controller)
    }

    @objc
    private func handleControllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        let controllerID = Self.controllerID(for: controller)
        activeGamepads.removeValue(forKey: controllerID)
        activeControllers.removeValue(forKey: controllerID)
        buttonStates = buttonStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
        lastAnalogScrollAt = lastAnalogScrollAt.filter { !$0.key.hasPrefix("\(controllerID)::") }
        lastAnalogActionAt = lastAnalogActionAt.filter { !$0.key.hasPrefix("\(controllerID)::") }
        polledButtonStates = polledButtonStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
        analogDirectionStates = analogDirectionStates.filter { !$0.key.hasPrefix("\(controllerID)::") }
        activeHolds = activeHolds.filter { !$0.key.hasPrefix("\(controllerID)::") }
        print("Controller disconnected: \(controllerID)")
    }

    private func registerHandlers(for controller: GCController) {
        let controllerID = Self.controllerID(for: controller)
        let vendor = controller.vendorName ?? "Unknown Vendor"
        print("Controller connected: \(vendor) id=\(controllerID)")

        guard let gamepad = controller.extendedGamepad else {
            print("Controller \(controllerID) does not expose extended gamepad profile; ignoring")
            return
        }

        activeGamepads[controllerID] = gamepad
        activeControllers[controllerID] = controller
        startPollingIfNeeded()
        print("[INFO] Registered polling for controller id=\(controllerID)")
    }

    private func startPollingIfNeeded() {
        if pollingTimer != nil {
            return
        }

        pollingTimer = Timer.scheduledTimer(
            timeInterval: 0.02,
            target: self,
            selector: #selector(pollControllers),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(pollingTimer!, forMode: .common)
    }

    private func startConfigWatcher() {
        configLastModified = configModificationDate(path: configPath)
        configWatchTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(checkConfigForChanges),
            userInfo: nil,
            repeats: true
        )
        if let configWatchTimer {
            RunLoop.main.add(configWatchTimer, forMode: .common)
        }
        print("[INFO] Config hot-reload watching \(configPath)")
    }

    @objc
    private func checkConfigForChanges() {
        guard let currentModified = configModificationDate(path: configPath) else {
            return
        }

        if let configLastModified, currentModified <= configLastModified {
            return
        }

        configLastModified = currentModified
        reloadConfigFromDisk()
    }

    private func reloadConfigFromDisk() {
        do {
            let newConfig = try ConfigLoader.load(path: configPath)
            let oldDryRun = Self.effectiveDryRun(for: config, dryRunOverride: dryRunOverride)
            let newDryRun = Self.effectiveDryRun(for: newConfig, dryRunOverride: dryRunOverride)

            config = newConfig
            profileResolver = ProfileResolver(appProfiles: newConfig.appProfiles)

            if oldDryRun != newDryRun {
                actionExecutor = ActionExecutor(dryRun: newDryRun)
                print("[CONFIG] Reloaded. Bridge mode changed to \(newDryRun ? "dry-run" : "live").")
            } else {
                print("[CONFIG] Reloaded mappings from disk.")
            }

            lastAnalogActionAt.removeAll()
            analogDirectionStates.removeAll()
        } catch {
            print("[CONFIG] Reload failed: \(error.localizedDescription)")
        }
    }

    private func configModificationDate(path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date else {
            return nil
        }
        return modified
    }

    @objc
    private func pollControllers() {
        for (controllerID, gamepad) in activeGamepads {
            pollButton(controllerID: controllerID, buttonName: "a", pressed: gamepad.buttonA.isPressed)
            pollButton(controllerID: controllerID, buttonName: "b", pressed: gamepad.buttonB.isPressed)
            pollButton(controllerID: controllerID, buttonName: "x", pressed: gamepad.buttonX.isPressed)
            pollButton(controllerID: controllerID, buttonName: "y", pressed: gamepad.buttonY.isPressed)
            pollButton(controllerID: controllerID, buttonName: "leftShoulder", pressed: gamepad.leftShoulder.isPressed)
            pollButton(controllerID: controllerID, buttonName: "rightShoulder", pressed: gamepad.rightShoulder.isPressed)
            pollButton(controllerID: controllerID, buttonName: "leftTrigger", pressed: gamepad.leftTrigger.isPressed)
            pollButton(controllerID: controllerID, buttonName: "rightTrigger", pressed: gamepad.rightTrigger.isPressed)
            pollButton(controllerID: controllerID, buttonName: "menu", pressed: gamepad.buttonMenu.isPressed)
            if let buttonOptions = gamepad.buttonOptions {
                pollButton(controllerID: controllerID, buttonName: "options", pressed: buttonOptions.isPressed)
            }
            if let controller = activeControllers[controllerID] {
                pollPhysicalButton(
                    controllerID: controllerID,
                    controller: controller,
                    elementName: GCInputButtonHome,
                    mappedButtonName: "home"
                )
                pollPhysicalButton(
                    controllerID: controllerID,
                    controller: controller,
                    elementName: GCInputButtonShare,
                    mappedButtonName: "share"
                )
            }
            if let leftThumbstickButton = gamepad.leftThumbstickButton {
                pollButton(controllerID: controllerID, buttonName: "leftThumbstickButton", pressed: leftThumbstickButton.isPressed)
            }
            if let rightThumbstickButton = gamepad.rightThumbstickButton {
                pollButton(controllerID: controllerID, buttonName: "rightThumbstickButton", pressed: rightThumbstickButton.isPressed)
            }
            pollButton(controllerID: controllerID, buttonName: "dpadUp", pressed: gamepad.dpad.up.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadDown", pressed: gamepad.dpad.down.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadLeft", pressed: gamepad.dpad.left.isPressed)
            pollButton(controllerID: controllerID, buttonName: "dpadRight", pressed: gamepad.dpad.right.isPressed)
            pollConfiguredVerticalScroll(controllerID: controllerID, gamepad: gamepad)
            pollConfiguredPointerMove(controllerID: controllerID, gamepad: gamepad)
            pollConfiguredVerticalActions(controllerID: controllerID, gamepad: gamepad)
            pollConfiguredHorizontalActions(controllerID: controllerID, gamepad: gamepad)
        }
    }

    private func pollPhysicalButton(
        controllerID: String,
        controller: GCController,
        elementName: String,
        mappedButtonName: String
    ) {
        guard let element = controller.physicalInputProfile.elements[elementName],
              let button = element as? GCControllerButtonInput else {
            return
        }

        pollButton(controllerID: controllerID, buttonName: mappedButtonName, pressed: button.isPressed)
    }

    private func pollButton(controllerID: String, buttonName: String, pressed: Bool) {
        let stateKey = "\(controllerID)::\(buttonName)"
        let previous = polledButtonStates[stateKey] ?? false
        guard previous != pressed else {
            return
        }

        polledButtonStates[stateKey] = pressed
        handleButtonEvent(controllerID: controllerID, buttonName: buttonName, pressed: pressed)
    }

    private func pollConfiguredVerticalScroll(controllerID: String, gamepad: GCExtendedGamepad) {
        guard bridgeEnabled else {
            return
        }

        let activeProfileName = profileResolver.resolveActiveProfile()
        let activeProfile = activeProfileName.flatMap { config.profiles[$0] }

        if let rightScroll = config.alwaysOn?.analog?.rightStickVerticalScroll, rightScroll.enabled ?? true {
            processVerticalScroll(
                controllerID: controllerID,
                profileName: "alwaysOn",
                configName: "rightStickVerticalScroll",
                source: "rightStickY",
                rawY: Double(gamepad.rightThumbstick.yAxis.value),
                config: rightScroll
            )
        } else if let activeProfileName,
                  let profile = activeProfile,
                  profile.enabled ?? true,
                  let rightScroll = profile.analog?.rightStickVerticalScroll,
                  rightScroll.enabled ?? true {
            processVerticalScroll(
                controllerID: controllerID,
                profileName: activeProfileName,
                configName: "rightStickVerticalScroll",
                source: "rightStickY",
                rawY: Double(gamepad.rightThumbstick.yAxis.value),
                config: rightScroll
            )
        }

        if let leftScroll = config.alwaysOn?.analog?.leftStickVerticalScroll, leftScroll.enabled ?? true {
            processVerticalScroll(
                controllerID: controllerID,
                profileName: "alwaysOn",
                configName: "leftStickVerticalScroll",
                source: "leftStickY",
                rawY: Double(gamepad.leftThumbstick.yAxis.value),
                config: leftScroll
            )
        } else if let activeProfileName,
                  let profile = activeProfile,
                  profile.enabled ?? true,
                  let leftScroll = profile.analog?.leftStickVerticalScroll,
                  leftScroll.enabled ?? true {
            processVerticalScroll(
                controllerID: controllerID,
                profileName: activeProfileName,
                configName: "leftStickVerticalScroll",
                source: "leftStickY",
                rawY: Double(gamepad.leftThumbstick.yAxis.value),
                config: leftScroll
            )
        }
    }

    private func processVerticalScroll(
        controllerID: String,
        profileName: String,
        configName: String,
        source: String,
        rawY: Double,
        config scroll: StickVerticalScrollConfig
    ) {
        let deadzone = min(max(scroll.deadzone ?? 0.22, 0.0), 0.99)
        let magnitude = abs(rawY)
        guard magnitude > deadzone else {
            return
        }

        let intervalMs = max(1, scroll.intervalMs ?? 45)
        let throttleKey = "\(controllerID)::\(profileName)::\(configName)"
        let now = Date()
        if let last = lastAnalogScrollAt[throttleKey] {
            let deltaMs = Int(now.timeIntervalSince(last) * 1000)
            if deltaMs < intervalMs {
                return
            }
        }

        let normalized = min(1.0, max(0.0, (magnitude - deadzone) / max(0.001, 1.0 - deadzone)))
        let responseExponent = max(0.1, scroll.responseExponent ?? 1.8)
        let curved = pow(normalized, responseExponent)
        let minLines = max(1, scroll.minLinesPerTick ?? 1)
        let maxLines = max(minLines, scroll.maxLinesPerTick ?? 8)
        let scaledLines = Double(minLines) + curved * Double(maxLines - minLines)
        let linesPerTick = max(1, Int(round(scaledLines)))

        let direction = rawY >= 0 ? 1 : -1
        let signedLines = (scroll.invert == true ? -direction : direction) * linesPerTick
        guard signedLines != 0 else {
            return
        }

        do {
            try actionExecutor.scrollVertical(
                lines: signedLines,
                profile: profileName,
                source: source
            )
            lastAnalogScrollAt[throttleKey] = now
        } catch {
            print("[ERROR] analog scroll failed: \(error.localizedDescription)")
        }
    }

    private func pollConfiguredPointerMove(controllerID: String, gamepad: GCExtendedGamepad) {
        guard bridgeEnabled else {
            return
        }

        let activeProfileName = profileResolver.resolveActiveProfile()
        let activeProfile = activeProfileName.flatMap { config.profiles[$0] }
        let pointerSource: (profileName: String, config: StickPointerConfig)?
        if let globalPointer = config.alwaysOn?.analog?.rightStickPointer, globalPointer.enabled ?? true {
            pointerSource = ("alwaysOn", globalPointer)
        } else if let activeProfileName,
                  let profile = activeProfile,
                  profile.enabled ?? true,
                  let profilePointer = profile.analog?.rightStickPointer,
                  profilePointer.enabled ?? true {
            pointerSource = (activeProfileName, profilePointer)
        } else {
            pointerSource = nil
        }

        guard let pointerSource else {
            return
        }

        let pointer = pointerSource.config

        let rawX = Double(gamepad.rightThumbstick.xAxis.value) * (pointer.invertX == true ? -1.0 : 1.0)
        let rawY = Double(gamepad.rightThumbstick.yAxis.value) * (pointer.invertY == true ? -1.0 : 1.0)
        let deadzone = min(max(pointer.deadzone ?? 0.16, 0.0), 0.99)
        let magnitude = sqrt((rawX * rawX) + (rawY * rawY))

        guard magnitude > deadzone else {
            return
        }

        let intervalMs = max(1, pointer.intervalMs ?? 16)
        let throttleKey = "\(controllerID)::\(pointerSource.profileName)::rightStickPointer"
        let now = Date()
        if let last = lastAnalogScrollAt[throttleKey] {
            let deltaMs = Int(now.timeIntervalSince(last) * 1000)
            if deltaMs < intervalMs {
                return
            }
        }

        let minPixels = max(1, pointer.minPixelsPerTick ?? 1)
        let maxPixels = max(minPixels, pointer.maxPixelsPerTick ?? 24)
        let responseExponent = max(0.1, pointer.responseExponent ?? 1.6)
        let normalizedMagnitude = min(1.0, max(0.0, (magnitude - deadzone) / max(0.001, 1.0 - deadzone)))
        let curvedMagnitude = pow(normalizedMagnitude, responseExponent)
        let pixels = max(1.0, Double(minPixels) + curvedMagnitude * Double(maxPixels - minPixels))

        let unitX = rawX / max(magnitude, 0.0001)
        let unitY = rawY / max(magnitude, 0.0001)
        var dx = Int(round(unitX * pixels))
        var dy = Int(round(unitY * pixels))

        if dx == 0 && abs(rawX) > deadzone {
            dx = rawX >= 0 ? 1 : -1
        }
        if dy == 0 && abs(rawY) > deadzone {
            dy = rawY >= 0 ? 1 : -1
        }
        guard dx != 0 || dy != 0 else {
            return
        }

        do {
            try actionExecutor.movePointerRelative(
                dx: dx,
                dy: dy,
                profile: pointerSource.profileName,
                source: "rightStick"
            )
            lastAnalogScrollAt[throttleKey] = now
        } catch {
            print("[ERROR] analog pointer failed: \(error.localizedDescription)")
        }
    }

    private func pollConfiguredHorizontalActions(controllerID: String, gamepad: GCExtendedGamepad) {
        let stateKey = "\(controllerID)::rightStickHorizontalActions"
        let rawX = Double(gamepad.rightThumbstick.xAxis.value)

        guard bridgeEnabled else {
            analogDirectionStates[stateKey] = 0
            return
        }

        let activeProfileName = profileResolver.resolveActiveProfile()
        let activeProfile = activeProfileName.flatMap { config.profiles[$0] }
        let horizontalSource: (profileName: String, config: StickHorizontalActionConfig)?
        if let globalHorizontal = config.alwaysOn?.analog?.rightStickHorizontalActions,
           globalHorizontal.enabled ?? true {
            horizontalSource = ("alwaysOn", globalHorizontal)
        } else if let activeProfileName,
                  let profile = activeProfile,
                  profile.enabled ?? true,
                  let profileHorizontal = profile.analog?.rightStickHorizontalActions,
                  profileHorizontal.enabled ?? true {
            horizontalSource = (activeProfileName, profileHorizontal)
        } else {
            horizontalSource = nil
        }

        guard let horizontalSource else {
            analogDirectionStates[stateKey] = 0
            return
        }

        processHorizontalActions(
            controllerID: controllerID,
            profileName: horizontalSource.profileName,
            rawX: rawX,
            config: horizontalSource.config
        )
    }

    private func pollConfiguredVerticalActions(controllerID: String, gamepad: GCExtendedGamepad) {
        let stateKey = "\(controllerID)::rightStickVerticalActions"
        let rawY = Double(gamepad.rightThumbstick.yAxis.value)

        guard bridgeEnabled else {
            analogDirectionStates[stateKey] = 0
            return
        }

        let activeProfileName = profileResolver.resolveActiveProfile()
        let activeProfile = activeProfileName.flatMap { config.profiles[$0] }
        let verticalSource: (profileName: String, config: StickVerticalActionConfig)?
        if let globalVertical = config.alwaysOn?.analog?.rightStickVerticalActions,
           globalVertical.enabled ?? true {
            verticalSource = ("alwaysOn", globalVertical)
        } else if let activeProfileName,
                  let profile = activeProfile,
                  profile.enabled ?? true,
                  let profileVertical = profile.analog?.rightStickVerticalActions,
                  profileVertical.enabled ?? true {
            verticalSource = (activeProfileName, profileVertical)
        } else {
            verticalSource = nil
        }

        guard let verticalSource else {
            analogDirectionStates[stateKey] = 0
            return
        }

        processVerticalActions(
            controllerID: controllerID,
            profileName: verticalSource.profileName,
            rawY: rawY,
            config: verticalSource.config
        )
    }

    private func processHorizontalActions(
        controllerID: String,
        profileName: String,
        rawX: Double,
        config: StickHorizontalActionConfig
    ) {
        let stateKey = "\(controllerID)::rightStickHorizontalActions"
        let throttleKey = "\(controllerID)::\(profileName)::rightStickHorizontalActions"
        let deadzone = min(max(config.deadzone ?? 0.58, 0.0), 0.99)
        let direction: Int

        if rawX <= -deadzone {
            direction = -1
        } else if rawX >= deadzone {
            direction = 1
        } else {
            direction = 0
        }

        let previousDirection = analogDirectionStates[stateKey] ?? 0
        guard direction != 0 else {
            analogDirectionStates[stateKey] = 0
            return
        }

        let isFreshTilt = direction != previousDirection
        if !isFreshTilt && config.edgeTrigger != false {
            return
        }

        let now = Date()
        let repeatIntervalMs = max(1, config.repeatIntervalMs ?? 260)
        if !isFreshTilt, let lastTriggeredAt = lastAnalogActionAt[throttleKey] {
            let deltaMs = Int(now.timeIntervalSince(lastTriggeredAt) * 1000)
            if deltaMs < repeatIntervalMs {
                return
            }
        }

        let action = direction < 0 ? config.leftAction : config.rightAction
        let syntheticButton = direction < 0 ? "rightStickLeft" : "rightStickRight"
        guard let action else {
            return
        }

        analogDirectionStates[stateKey] = direction
        do {
            try actionExecutor.execute(action: action, profile: profileName, button: syntheticButton)
            lastAnalogActionAt[throttleKey] = now
        } catch {
            print("[ERROR] analog horizontal action failed: \(error.localizedDescription)")
        }
    }

    private func processVerticalActions(
        controllerID: String,
        profileName: String,
        rawY: Double,
        config: StickVerticalActionConfig
    ) {
        let stateKey = "\(controllerID)::rightStickVerticalActions"
        let throttleKey = "\(controllerID)::\(profileName)::rightStickVerticalActions"
        let deadzone = min(max(config.deadzone ?? 0.58, 0.0), 0.99)
        let direction: Int

        if rawY <= -deadzone {
            direction = -1
        } else if rawY >= deadzone {
            direction = 1
        } else {
            direction = 0
        }

        let previousDirection = analogDirectionStates[stateKey] ?? 0
        guard direction != 0 else {
            analogDirectionStates[stateKey] = 0
            return
        }

        let isFreshTilt = direction != previousDirection
        if !isFreshTilt && config.edgeTrigger != false {
            return
        }

        let now = Date()
        let repeatIntervalMs = max(1, config.repeatIntervalMs ?? 260)
        if !isFreshTilt, let lastTriggeredAt = lastAnalogActionAt[throttleKey] {
            let deltaMs = Int(now.timeIntervalSince(lastTriggeredAt) * 1000)
            if deltaMs < repeatIntervalMs {
                return
            }
        }

        let action = direction < 0 ? config.downAction : config.upAction
        let syntheticButton = direction < 0 ? "rightStickDown" : "rightStickUp"
        guard let action else {
            return
        }

        analogDirectionStates[stateKey] = direction
        do {
            try actionExecutor.execute(action: action, profile: profileName, button: syntheticButton)
            lastAnalogActionAt[throttleKey] = now
        } catch {
            print("[ERROR] analog vertical action failed: \(error.localizedDescription)")
        }
    }

    private func promptForAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        print("[INFO] Requested macOS Accessibility permission prompt for this terminal app.")
    }

    private func handleButtonEvent(controllerID: String, buttonName: String, pressed: Bool) {
        let now = Date()
        let stateKey = "\(controllerID)::\(buttonName)"
        let previousState = buttonStates[stateKey] ?? false
        let isRepeat = pressed && previousState
        buttonStates[stateKey] = pressed

        let event = ControllerEvent(
            controllerID: controllerID,
            button: buttonName,
            pressed: pressed,
            timestamp: now,
            isRepeat: isRepeat
        )

        print("[EVENT] controller=\(event.controllerID) button=\(event.button) pressed=\(event.pressed) repeat=\(event.isRepeat)")

        guard event.pressed else {
            if let held = activeHolds.removeValue(forKey: stateKey) {
                do {
                    try actionExecutor.endHold(action: held.action, profile: held.profileName, button: event.button)
                } catch {
                    print("[ERROR] hold release failed: \(error.localizedDescription)")
                }
            }
            return
        }

        let bundleID = profileResolver.currentFrontmostBundleID() ?? "unknown"

        if let emergencyButton = config.safety.emergencyToggleButton,
           event.button == emergencyButton {
            bridgeEnabled.toggle()
            print("[SAFETY] bridgeEnabled=\(bridgeEnabled)")
            return
        }

        guard bridgeEnabled else {
            print("[SKIP] Bridge disabled via emergency toggle")
            return
        }

        let activeProfileName = profileResolver.resolveActiveProfile()

        guard let resolved = resolveMapping(forButton: event.button, activeProfileName: activeProfileName) else {
            if let activeProfileName {
                print("[SKIP] no mapping profile=\(activeProfileName) bundle=\(bundleID) button=\(event.button)")
            } else {
                print("[SKIP] no active app profile bundle=\(bundleID) button=\(event.button)")
            }
            return
        }

        print("[MAP] profile=\(resolved.profileName) bundle=\(bundleID) button=\(event.button)")

        if event.isRepeat && resolved.mapping.edgeTrigger != false {
            return
        }

        if resolved.mapping.action.type == .holdKeystroke {
            do {
                try actionExecutor.beginHold(action: resolved.mapping.action, profile: resolved.profileName, button: event.button)
                activeHolds[stateKey] = (resolved.profileName, resolved.mapping.action)
            } catch {
                print("[ERROR] hold begin failed: \(error.localizedDescription)")
            }
            return
        }

        let debounceMs = resolved.mapping.debounceMs ?? 200
        let debounceKey = "\(resolved.profileName)::\(event.button)"

        if let last = lastTriggeredAt[debounceKey] {
            let deltaMs = Int(now.timeIntervalSince(last) * 1000)
            if deltaMs < debounceMs {
                print("[SKIP] debounce profile=\(resolved.profileName) button=\(event.button) deltaMs=\(deltaMs)")
                return
            }
        }

        do {
            try actionExecutor.execute(action: resolved.mapping.action, profile: resolved.profileName, button: event.button)
            lastTriggeredAt[debounceKey] = now
        } catch {
            print("[ERROR] action failed: \(error.localizedDescription)")
        }
    }

    private func resolveMapping(forButton button: String, activeProfileName: String?) -> (profileName: String, mapping: MappingConfig)? {
        if let activeProfileName,
           let activeProfile = config.profiles[activeProfileName],
           activeProfile.enabled ?? true,
           let mapping = activeProfile.mappings[button] {
            return (activeProfileName, mapping)
        }

        if let mapping = config.alwaysOn?.mappings?[button] {
            return ("alwaysOn", mapping)
        }

        return nil
    }

    private static func controllerID(for controller: GCController) -> String {
        let objectID = ObjectIdentifier(controller).hashValue
        return String(objectID)
    }
}

func run() throws {
    let options = try CLIOptions.parse(arguments: CommandLine.arguments)
    let configPath = ConfigLoader.absolutePath(for: options.configPath)
    let config = try ConfigLoader.load(path: configPath)

    let bridge = ControllerBridge(
        config: config,
        configPath: configPath,
        dryRunOverride: options.dryRunOverride,
        promptAccessibility: options.promptAccessibility
    )
    bridge.start()
}

do {
    try run()
} catch {
    print("Fatal: \(error.localizedDescription)")
    Foundation.exit(1)
}
