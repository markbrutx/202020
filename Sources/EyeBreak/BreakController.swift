import AppKit

/// Показывает непрозрачные окна на всех экранах поверх всего на заданное время.
final class BreakController {
    private var windows: [NSWindow] = []
    private var countdownTimer: Timer?
    private var remaining: Int = 0
    private var onFinish: (() -> Void)?

    var isShowing: Bool { !windows.isEmpty }

    func show(duration: TimeInterval, onFinish: @escaping () -> Void) {
        guard !isShowing else { return }
        self.onFinish = onFinish
        remaining = Int(duration)

        for screen in NSScreen.screens {
            let window = BreakWindow(screen: screen)
            let view = BreakView(frame: screen.frame)
            view.remaining = remaining
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.hide()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.countdownTick()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func countdownTick() {
        remaining -= 1
        if remaining <= 0 {
            hide()
            return
        }
        for w in windows {
            (w.contentView as? BreakView)?.remaining = remaining
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

    // Глотаем все клавиши (включая Cmd+Q и Esc), чтобы перерыв нельзя было пропустить
    override func keyDown(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

final class BreakView: NSView {
    var remaining: Int = 0 { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

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

        // Прогресс-полоска снизу
        let barHeight: CGFloat = 4
        NSColor(white: 0.15, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: barHeight).fill()
        NSColor(white: 0.7, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width * CGFloat(remaining) / 20.0, height: barHeight).fill()
    }
}
