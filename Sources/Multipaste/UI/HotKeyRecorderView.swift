import AppKit
import Combine
import SwiftUI

/// Captures the next key combination typed while recording.
final class HotKeyRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var registrationFailed = false

    private var monitor: Any?

    func toggle(settings: AppSettings) {
        if isRecording {
            stop()
        } else {
            start(settings: settings)
        }
    }

    func start(settings: AppSettings) {
        guard !isRecording else { return }
        isRecording = true
        registrationFailed = false
        // Suspend the live shortcut so pressing it again can be recorded.
        HotKeyManager.shared.unregister()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let recorder = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasMainModifier = flags.contains(.command) || flags.contains(.control) || flags.contains(.option)

            if event.keyCode == 53 && !hasMainModifier {
                recorder.stop()
                return nil
            }
            guard hasMainModifier else {
                // A shortcut needs ⌘, ⌃ or ⌥ so it cannot swallow normal typing.
                NSSound.beep()
                return nil
            }
            settings.hotKeyCode = Int(event.keyCode)
            settings.hotKeyModifiers = KeyCombo.carbonModifiers(from: flags)
            recorder.stop()
            return nil
        }
    }

    func stop() {
        guard isRecording else { return }
        if let active = monitor {
            NSEvent.removeMonitor(active)
        }
        monitor = nil
        isRecording = false
        // The app delegate re-registers the (possibly new) shortcut synchronously.
        NotificationCenter.default.post(name: .multipasteHotKeyChanged, object: nil)
        registrationFailed = !HotKeyManager.shared.isRegistered
    }
}

struct HotKeyRecorderView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var recorder = HotKeyRecorder()

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: { recorder.toggle(settings: settings) }) {
                    Text(recorder.isRecording ? "Type shortcut…" : settings.hotKeyDisplay)
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 110)
                }
                .help("Click, then press the new shortcut. Esc cancels.")

                Button("Reset") {
                    recorder.stop()
                    settings.hotKeyCode = AppSettings.defaultHotKeyCode
                    settings.hotKeyModifiers = AppSettings.defaultHotKeyModifiers
                    NotificationCenter.default.post(name: .multipasteHotKeyChanged, object: nil)
                    recorder.registrationFailed = !HotKeyManager.shared.isRegistered
                }
                .disabled(settings.hotKeyCode == AppSettings.defaultHotKeyCode
                          && settings.hotKeyModifiers == AppSettings.defaultHotKeyModifiers)
            }
            if recorder.registrationFailed {
                Text("That shortcut is taken by the system or another app. Pick another one.")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .onDisappear {
            recorder.stop()
        }
    }
}
