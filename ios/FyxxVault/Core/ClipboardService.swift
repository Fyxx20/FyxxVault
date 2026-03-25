import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Clipboard Service

enum ClipboardService {
    private static var clearTask: DispatchWorkItem?

    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        scheduleClear(text: text)
    }

    private static func scheduleClear(text: String) {
        let autoClear = UserDefaults.standard.bool(forKey: SettingsKey.clipboardAutoClear)
        guard autoClear else { return }
        let delay = UserDefaults.standard.integer(forKey: SettingsKey.clipboardDelay)
        let seconds = [15, 30, 60].contains(delay) ? delay : 30

        clearTask?.cancel()
        let task = DispatchWorkItem { clearIfSame(text: text) }
        clearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds), execute: task)
    }

    private static func clearIfSame(text: String) {
        #if canImport(UIKit)
        if (UIKit.UIPasteboard.general.string ?? "") == text {
            UIKit.UIPasteboard.general.string = ""
        }
        #elseif canImport(AppKit)
        if AppKit.NSPasteboard.general.string(forType: .string) == text {
            AppKit.NSPasteboard.general.clearContents()
        }
        #endif
    }
}
