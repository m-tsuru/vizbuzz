import AppKit
import Observation

enum TimerMode: String, CaseIterable, Identifiable {
    case countdown = "カウントダウン"
    case countUp = "カウントアップ"
    case repeating = "リピート"
    var id: String { rawValue }
}

@MainActor @Observable
final class TimerModel {
    var mode: TimerMode = .countdown { didSet { reset(); defaults?.set(mode.rawValue, forKey: "timer.mode") } }
    var workSeconds = 1500 { didSet { if !hasStarted { reset() }; defaults?.set(workSeconds, forKey: "timer.workSeconds") } }
    var restSeconds = 300 { didSet { defaults?.set(restSeconds, forKey: "timer.restSeconds") } }
    var repetitions = 4 { didSet { defaults?.set(repetitions, forKey: "timer.repetitions") } }
    var halfwayAlert = false
    var soundName = "Glass"
    var volume = 0.6
    var muted = false
    var alwaysOnTop = false { didSet { defaults?.set(alwaysOnTop, forKey: "timer.alwaysOnTop") } }
    var windowVisible = true
    private(set) var isAlarmActive = false
    private(set) var running = false
    private(set) var hasStarted = false
    private(set) var completed = false
    private(set) var resting = false
    private(set) var round = 1
    private(set) var seconds: Double = 1500
    private var anchor: Date?
    private var anchorSeconds: Double = 0
    private var halfwayNotified = false
    private var heartbeat: Task<Void, Never>?
    private var alarmStop: Task<Void, Never>?
    private var sound: NSSound?

    @ObservationIgnored private var defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            mode = TimerMode(rawValue: defaults.string(forKey: "timer.mode") ?? "") ?? .countdown
            if defaults.object(forKey: "timer.workSeconds") != nil {
                workSeconds = min(11999, max(1, defaults.integer(forKey: "timer.workSeconds")))
            }
            if defaults.object(forKey: "timer.restSeconds") != nil {
                restSeconds = min(11999, max(1, defaults.integer(forKey: "timer.restSeconds")))
            }
            if defaults.object(forKey: "timer.repetitions") != nil {
                repetitions = min(99, max(1, defaults.integer(forKey: "timer.repetitions")))
            }
            alwaysOnTop = defaults.bool(forKey: "timer.alwaysOnTop")
        }
        self.defaults = defaults
        reset()
    }

    static let maximum = 11999.0
    static let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
                         "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    var duration: Double { Double(resting ? restSeconds : workSeconds) }
    var fraction: Double {
        mode == .countUp ? min(seconds / Self.maximum, 1) : min(max(seconds / max(duration, 1), 0), 1)
    }
    var timeText: String {
        let value = Int(mode == .countUp ? floor(seconds) : ceil(seconds))
        return String(format: "%02d:%02d", max(0, value) / 60, max(0, value) % 60)
    }
    var phaseText: String {
        if completed { return "完了" }
        if mode == .repeating { return "\(resting ? "休憩" : "作業")  ·  \(round) / \(repetitions)" }
        return mode.rawValue
    }
    var stateText: String { completed ? "おつかれさまでした" : running ? "計測中" : hasStarted ? "一時停止中" : "準備完了" }

    func startHeartbeat() {
        guard heartbeat == nil else { return }
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func toggle(now: Date = Date()) {
        if running {
            tick(now: now)
            running = false
            anchor = nil
        } else {
            if completed { reset() }
            stopSound()
            hasStarted = true
            running = true
            anchor = now
            anchorSeconds = seconds
        }
    }

    func reset() {
        running = false
        hasStarted = false
        completed = false
        resting = false
        round = 1
        halfwayNotified = false
        anchor = nil
        seconds = mode == .countUp ? 0 : Double(workSeconds)
        stopSound()
    }

    // Use elapsed wall time, not tick counts, so delayed updates and sleep do not drift.
    func tick(now: Date = Date()) {
        guard running, let anchor else { return }
        let elapsed = max(0, now.timeIntervalSince(anchor))
        if mode == .countUp {
            seconds = min(Self.maximum, anchorSeconds + elapsed)
            if seconds >= Self.maximum { finish() }
            return
        }
        var remaining = anchorSeconds - elapsed
        var transitioned = false
        while remaining <= 0 {
            if mode != .repeating || (!resting && round >= repetitions) {
                seconds = 0
                finish()
                return
            }
            if resting { round += 1 }
            resting.toggle()
            remaining += max(duration, 1)
            halfwayNotified = false
            transitioned = true
        }
        if transitioned {
            self.anchor = now
            anchorSeconds = remaining
            playSound(for: 3)
        }
        seconds = remaining
        if halfwayAlert && !halfwayNotified && remaining <= duration / 2 {
            halfwayNotified = true
            if !transitioned { playSound(for: 1) }
        }
    }

    private func finish() {
        running = false
        completed = true
        anchor = nil
        playSound(for: 10)
    }

    func playSound(for duration: Double = 1) {
        stopSound()
        isAlarmActive = true
        alarmStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.stopSound()
        }
        guard !muted, volume > 0 else { return }
        guard let effect = NSSound(named: NSSound.Name(soundName)) else {
            NSSound.beep()
            return
        }
        effect.volume = Float(volume)
        effect.loops = duration > 1
        sound = effect
        effect.play()
    }

    func stopSound() {
        isAlarmActive = false
        alarmStop?.cancel()
        alarmStop = nil
        sound?.stop()
        sound = nil
    }
}
