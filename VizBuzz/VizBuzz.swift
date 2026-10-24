import SwiftUI
import AppKit

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(TimerAppDelegate.self) private var delegate
    @State private var menuInserted = true

    var body: some Scene {
        MenuBarExtra(isInserted: $menuInserted) {
            Text("\(delegate.model.phaseText)  \(delegate.model.timeText)")
            Text(delegate.model.stateText)
            Divider()
            Button("タイマーを表示") { delegate.showWindow() }
            Button("設定…") { delegate.showSettings() }
            Button(delegate.model.running ? "一時停止" : "開始 / 再開") { delegate.model.toggle() }
            Button("リセット") { delegate.model.reset() }
            Button("サウンドを停止") { delegate.model.stopSound() }
            Divider()
            Button("終了") { NSApplication.shared.terminate(nil) }
        } label: {
            if delegate.model.windowVisible {
                Image(systemName: "timer")
            } else {
                Text("\(delegate.model.running ? "" : "⏸ ")\(delegate.model.timeText)")
                    .monospacedDigit()
                    .accessibilityLabel("\(delegate.model.phaseText) \(delegate.model.timeText)")
            }
        }
    }
}

@MainActor
final class TimerAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = TimerModel(defaults: .standard)
    private var timerWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var visibilityTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = TimerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 170),
            styleMask: [.borderless, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "タイマー"
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentMinSize = NSSize(width: 280, height: 96)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView(model: model, showSettings: { [weak self] in
            self?.showSettings()
        }, hideWindow: { [weak self] in
            self?.timerWindow?.orderOut(nil)
            self?.updateVisibility()
        }))
        let savedWidth = UserDefaults.standard.double(forKey: "timer.windowWidth")
        let savedHeight = UserDefaults.standard.double(forKey: "timer.windowHeight")
        if savedWidth.isFinite, savedHeight.isFinite, savedWidth >= 280, savedHeight >= 96 {
            window.setContentSize(NSSize(width: savedWidth, height: savedHeight))
        }
        window.center()
        timerWindow = window
        showWindow()
        model.startHeartbeat()
        visibilityTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateVisibility()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === timerWindow else { return }
        UserDefaults.standard.set(window.frame.width, forKey: "timer.windowWidth")
        UserDefaults.standard.set(window.frame.height, forKey: "timer.windowHeight")
    }

    private func updateVisibility() {
        guard let window = timerWindow else { return }
        model.windowVisible = window.isVisible && !window.isMiniaturized && !NSApp.isHidden
            && window.occlusionState.contains(.visible)
        window.level = model.alwaysOnTop ? .floating : .normal
        settingsWindow?.level = window.level
        window.collectionBehavior = model.alwaysOnTop ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 698, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.title = "タイマーの設定"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: TimerSettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        // Keep settings accessible even when the timer floats above other windows.
        settingsWindow?.level = model.alwaysOnTop ? .floating : .normal
        NSApp.unhide(nil)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showWindow() {
        NSApp.unhide(nil)
        timerWindow?.deminiaturize(nil)
        timerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateVisibility()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        updateVisibility()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
}

@MainActor
private final class TimerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
