import AppKit

/// Показывает непрозрачные окна на всех экранах поверх всего на заданное время.
/// По умолчанию перерыв длится `fullDuration`; если пользователь нажмёт любую
/// клавишу — сокращается до `shortDuration`.
final class BreakController {
    private var windows: [NSWindow] = []
    private var countdownTimer: Timer?
    private var remaining: Int = 0
    private var total: Int = 0
    private var shortDuration: Int = 0
    private var acknowledged = false
    private var onFinish: (() -> Void)?

    var isShowing: Bool { !windows.isEmpty }

    func show(fullDuration: TimeInterval, shortDuration: TimeInterval, onFinish: @escaping () -> Void) {
        guard !isShowing else { return }
        self.onFinish = onFinish
        self.shortDuration = Int(shortDuration)
        remaining = Int(fullDuration)
        total = remaining
        acknowledged = false

        for screen in NSScreen.screens {
            let window = BreakWindow(screen: screen)
            window.onKeyPress = { [weak self] in self?.acknowledge() }
            let view = BreakView(frame: screen.frame)
            view.update(remaining: remaining, total: total, acknowledged: false)
            window.contentView = view
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.hide()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.countdownTick()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    /// Пользователь подтвердил, что увидел перерыв — сокращаем до короткого.
    private func acknowledge() {
        guard !acknowledged else { return }
        acknowledged = true
        if remaining > shortDuration {
            remaining = shortDuration
            total = shortDuration
        }
        refreshViews()
    }

    private func countdownTick() {
        remaining -= 1
        if remaining <= 0 {
            hide()
            return
        }
        refreshViews()
    }

    private func refreshViews() {
        for w in windows {
            (w.contentView as? BreakView)?.update(remaining: remaining, total: total, acknowledged: acknowledged)
        }
    }

    private func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        NSCursor.unhide()
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        let cb = onFinish
        onFinish = nil
        cb?()
    }
}

final class BreakWindow: NSWindow {
    var onKeyPress: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        level = .screenSaver               // выше меню-бара и fullscreen-приложений
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Любая клавиша = подтверждение. Ничего дальше не пропускаем (Cmd+Q, Esc и т.п.)
    override func keyDown(with event: NSEvent) { onKeyPress?() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onKeyPress?()
        return true
    }
}

final class BreakView: NSView {
    private var remaining: Int = 0
    private var total: Int = 1
    private var acknowledged = false

    override var acceptsFirstResponder: Bool { true }

    func update(remaining: Int, total: Int, acknowledged: Bool) {
        self.remaining = remaining
        self.total = max(1, total)
        self.acknowledged = acknowledged
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1).setFill()
        bounds.fill()

        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        let numberAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 180, weight: .thin),
            .foregroundColor: NSColor(white: 0.9, alpha: 1),
        ]
        let number = NSAttributedString(string: "\(remaining)", attributes: numberAttrs)
        let nSize = number.size()
        number.draw(at: NSPoint(x: center.x - nSize.width / 2, y: center.y - nSize.height / 2 + 40))

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .light),
            .foregroundColor: NSColor(white: 0.6, alpha: 1),
        ]
        let text = NSAttributedString(
            string: "Встань и посмотри на что-нибудь в 6 метрах от тебя",
            attributes: textAttrs
        )
        let tSize = text.size()
        text.draw(at: NSPoint(x: center.x - tSize.width / 2, y: center.y - nSize.height / 2 - 30))

        if !acknowledged {
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: NSColor(white: 0.35, alpha: 1),
            ]
            let hint = NSAttributedString(string: "нажми любую клавишу — сократится до 20 сек", attributes: hintAttrs)
            let hSize = hint.size()
            hint.draw(at: NSPoint(x: center.x - hSize.width / 2, y: center.y - nSize.height / 2 - 80))
        }

        // Прогресс-полоска снизу
        let barHeight: CGFloat = 4
        NSColor(white: 0.15, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: barHeight).fill()
        NSColor(white: 0.7, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width * CGFloat(remaining) / CGFloat(total), height: barHeight).fill()
    }
}
