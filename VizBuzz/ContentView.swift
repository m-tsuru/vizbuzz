import SwiftUI
import AppKit

struct ContentView: View {
    let model: TimerModel
    var showSettings: () -> Void = {}
    var hideWindow: () -> Void = {}

    var body: some View {
        TimerDisplay(model: model, showSettings: showSettings, hideWindow: hideWindow)
            .padding(6)
            .frame(minWidth: 280, maxWidth: .infinity, minHeight: 96, maxHeight: .infinity)
            .background(Color.clear)
            .overlayPreferenceValue(TimerControlBoundsKey.self) { anchors in
                GeometryReader { geometry in
                    WindowResizeHandle(excludedRects: anchors.map { geometry[$0] })
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .help("ドラッグしてウィンドウのサイズを変更")
                }
            }
    }
}

struct TimerSettingsView: View {
    @Bindable var model: TimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TimerSettings(model: model)
            if model.hasStarted {
                Button("計測をリセットして設定を変更") { model.reset() }
            }
            Divider()
            Toggle("常に最前面に表示（Always on Top）", isOn: $model.alwaysOnTop)
            LoginLaunchSettings()
            HStack(spacing: 12) {
                Toggle("消音", isOn: $model.muted)
                Picker("終了音", selection: $model.soundName) {
                    ForEach(TimerModel.sounds, id: \.self) { name in Text(name).tag(name) }
                }
                .frame(width: 175)
                Slider(value: $model.volume, in: 0...1) { Text("音量") }
                    .frame(width: 120)
                    .disabled(model.muted)
                Button("試聴") { model.playSound() }
                    .disabled(model.muted)
            }
        }
        .padding(24)
        .frame(width: 650)
    }
}

private struct TimerDisplay: View {
    @Bindable var model: TimerModel
    var showSettings: () -> Void
    var hideWindow: () -> Void
    @State private var editingTime = false
    private let colors: [Color] = [
        Color(red: 1, green: 0.49, blue: 0.08),
        Color(red: 0.70, green: 0.88, blue: 0.08),
        Color(red: 0.04, green: 0.71, blue: 0.49),
        Color(red: 0.10, green: 0.43, blue: 0.99)
    ]

    var body: some View {
        GeometryReader { geometry in
            let barHeight = max(36, geometry.size.height - 20)
            let timeWidth = max(124, (geometry.size.width - 32) * 0.38)
            let digitSize = min(120, min((barHeight - 30) * 0.85, timeWidth / 3.7))
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Double(index) < ceil(model.fraction * 20) ? colors[index / 5] : Color.white.opacity(0.07))
                    }
                }
                .frame(height: barHeight)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.mode == .countUp ? "経過時間の割合" : "残り時間の割合")
                .accessibilityValue("\(Int(model.fraction * 100))パーセント")
                VStack(alignment: .center, spacing: 6) {
                    Button { editingTime = true } label: {
                        Text(model.timeText)
                        .font(.system(size: digitSize, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(model.completed ? Color.green : Color(red: 0.78, green: 0.92, blue: 1))
                    }
                    .buttonStyle(.plain)
                    .help("クリックして時間を変更")
                    .accessibilityLabel("時間を変更、現在 " + model.timeText)
                    .popover(isPresented: $editingTime) {
                        TimeEntryView(model: model) { editingTime = false }
                    }
            HStack(spacing: 0) {
                if model.isAlarmActive {
                    TimerIconButton(symbol: "bell.slash.fill", title: "アラームを停止", active: true) {
                        model.stopSound()
                    }
                }
                TimerIconButton(symbol: model.alwaysOnTop ? "pin.fill" : "pin",
                                title: "最前面表示を切り替え", active: model.alwaysOnTop) {
                    model.alwaysOnTop.toggle()
                }
                .accessibilityValue(model.alwaysOnTop ? "オン" : "オフ")
                TimerIconButton(symbol: "arrow.counterclockwise", title: "リセット") {
                    model.reset()
                }
                TimerIconButton(symbol: model.running ? "pause.fill" : "play.fill",
                                title: model.running ? "一時停止" : "開始 / 再開") {
                    model.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])
                TimerIconButton(symbol: "gearshape", title: "設定", action: showSettings)
                TimerIconButton(symbol: "minus", title: "メニューバーにしまう", action: hideWindow)
            }
                }
                .anchorPreference(key: TimerControlBoundsKey.self, value: .bounds) { [$0] }
                .padding(.top, 6)
                .frame(width: timeWidth, height: barHeight, alignment: .center)
            }
        .padding(10)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.045, green: 0.065, blue: 0.08))
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents()
        }
        }
    }
}

private struct TimerSettings: View {
    @Bindable var model: TimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("計測モード", selection: $model.mode) {
                ForEach(TimerMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .disabled(model.hasStarted)

            HStack(alignment: .top, spacing: 24) {
                if model.mode != .countUp {
                    DurationEditor(title: model.mode == .repeating ? "作業時間" : "設定時間", seconds: $model.workSeconds)
                    if model.mode == .repeating {
                        DurationEditor(title: "休憩時間", seconds: $model.restSeconds)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("作業の回数").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(model.repetitions) 回", value: $model.repetitions, in: 1...99)
                        }
                    } else {
                        Button("25分に設定") { model.workSeconds = 1500 }
                            .padding(.top, 24)
                    }
                } else {
                    Text("00:00 から最大 199:59 まで計測します。\nバーは経過時間に合わせて左から増えます。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .disabled(model.hasStarted)

            HStack {
                Toggle("半分経過で通知", isOn: $model.halfwayAlert)
                    .disabled(model.mode == .countUp)
                Spacer()
                if model.mode == .repeating {
                    Text("作業 → 休憩を繰り返し、最後の作業で完了")
                        .font(.caption).foregroundStyle(.secondary)
                } else if model.hasStarted {
                    Text("設定変更はリセット後に").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DurationEditor: View {
    let title: String
    @Binding var seconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Picker("分", selection: Binding(
                    get: { seconds / 60 },
                    set: { seconds = max(1, $0 * 60 + seconds % 60) }
                )) {
                    ForEach(0..<200) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 72)
                Text("分")
                Picker("秒", selection: Binding(
                    get: { seconds % 60 },
                    set: { seconds = max(1, seconds / 60 * 60 + $0) }
                )) {
                    ForEach(0..<60) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 62)
                Text("秒")
            }
        }
    }
}

#Preview("コンパクト") {
    ContentView(model: TimerModel()).frame(width: 280, height: 96)
}

#Preview("ワイド") {
    ContentView(model: TimerModel()).frame(width: 900, height: 260)
}

#Preview("縦長") {
    ContentView(model: TimerModel()).frame(width: 460, height: 500)
}

private struct TimeEntryView: View {
    let model: TimerModel
    let dismiss: () -> Void
    @State private var minutes = ""
    @State private var seconds = ""
    @FocusState private var minutesFocused: Bool

    private var total: Int? {
        guard let m = Int(minutes), let s = Int(seconds),
              (0...199).contains(m), (0...59).contains(s),
              m * 60 + s > 0 else { return nil }
        return m * 60 + s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("時間を変更").font(.headline)
            HStack {
                TextField("分", text: $minutes)
                    .focused($minutesFocused)
                    .frame(width: 65)
                    .accessibilityLabel("分")
                Text("分")
                TextField("秒", text: $seconds)
                    .frame(width: 55)
                    .accessibilityLabel("秒")
                Text("秒")
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit { apply() }
            Text("1秒〜199分59秒。変更すると計測をリセットします。")
                .font(.caption).foregroundStyle(.secondary)
            if model.mode == .repeating {
                Text("作業時間を変更し、1回目から開始します。")
                    .font(.caption).foregroundStyle(.secondary)
            } else if model.mode == .countUp {
                Text("カウントダウンに切り替えます。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("キャンセル", action: dismiss).keyboardShortcut(.cancelAction)
                Spacer()
                Button("変更") { apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(total == nil)
            }
        }
        .padding(20)
        .onAppear {
            let value = model.mode == .repeating ? model.workSeconds : max(1, Int(ceil(model.seconds)))
            minutes = String(value / 60)
            seconds = String(value % 60)
            minutesFocused = true
        }
    }

    private func apply() {
        guard let total else { return }
        model.reset()
        if model.mode == .countUp { model.mode = .countdown }
        model.workSeconds = total
        dismiss()
    }
}

// A dedicated handle provides resizing for the title-bar-free window without
// competing with the drag gestures used to move the timer.
private struct TimerControlBoundsKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

private struct WindowResizeHandle: NSViewRepresentable {
    let excludedRects: [CGRect]

    func makeNSView(context: Context) -> ResizeHandleView { ResizeHandleView() }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.excludedRects = excludedRects
    }
}

private final class ResizeHandleView: NSView {
    private var initialFrame: NSRect = .zero
    private var initialMouse: NSPoint = .zero
    private var resizeWidth = false
    private var resizeHeight = false

    var excludedRects: [CGRect] = []

    // Fixed point sizes do not shrink with the window. Actual control bounds
    // take priority, including the alarm button when it appears.
    private func resizeAxes(at point: NSPoint) -> (width: Bool, height: Bool) {
        let inCorner = point.x >= bounds.maxX - 64 && point.y <= 64
        return (point.x >= bounds.maxX - 24 || inCorner, point.y <= 24 || inCorner)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        let swiftUIPoint = CGPoint(x: local.x, y: bounds.height - local.y)
        guard !excludedRects.contains(where: {
            $0.insetBy(dx: -3, dy: -3).contains(swiftUIPoint)
        }) else { return nil }
        let axes = resizeAxes(at: local)
        return axes.width || axes.height ? self : nil
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        for offset in [CGFloat(5), 10, 15] {
            path.move(to: NSPoint(x: bounds.maxX - offset, y: 5))
            path.line(to: NSPoint(x: bounds.maxX - 5, y: offset))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let local = convert(event.locationInWindow, from: nil)
        let axes = resizeAxes(at: local)
        resizeWidth = axes.width
        resizeHeight = axes.height
        initialFrame = window.frame
        initialMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let point = NSEvent.mouseLocation
        let width = max(window.minSize.width, max(window.contentMinSize.width,
            initialFrame.width + (resizeWidth ? point.x - initialMouse.x : 0)))
        let height = max(window.minSize.height, max(window.contentMinSize.height,
            initialFrame.height + (resizeHeight ? initialMouse.y - point.y : 0)))
        window.setFrame(NSRect(x: initialFrame.minX, y: initialFrame.maxY - height,
                               width: width, height: height), display: true)
    }
}

private struct TimerIconButton: View {
    let symbol: String
    let title: String
    var active = false
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovered ? Color.white : Color.white.opacity(active ? 0.8 : 0.4))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}
