import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Настройки
    private let workInterval: TimeInterval = 20 * 60   // 20 минут
    private let breakDuration: TimeInterval = 20       // 20 секунд

    private var statusItem: NSStatusItem!
    private var tickTimer: Timer?
    private var nextBreakAt: Date = .distantFuture
    private var pausedUntil: Date?
    private let breakController = BreakController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        scheduleNextBreak()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)

        // После пробуждения мака — начинаем отсчёт заново
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil
        )
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "👁 20:00"

        let menu = NSMenu()
        menu.addItem(withTitle: "Перерыв сейчас", action: #selector(breakNow), keyEquivalent: "b")
        menu.addItem(withTitle: "Отложить на 5 минут", action: #selector(postpone), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Пауза на 1 час", action: #selector(pauseHour), keyEquivalent: "")
        menu.addItem(withTitle: "Возобновить", action: #selector(resume), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выход", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        if let until = pausedUntil, until > Date() {
            button.title = "👁 ⏸"
            return
        }
        let remaining = max(0, Int(nextBreakAt.timeIntervalSinceNow.rounded()))
        button.title = String(format: "👁 %02d:%02d", remaining / 60, remaining % 60)
    }

    // MARK: - Timer logic

    private func scheduleNextBreak() {
        nextBreakAt = Date().addingTimeInterval(workInterval)
        updateTitle()
    }

    private func tick() {
        if let until = pausedUntil {
            if until <= Date() {
                pausedUntil = nil
                scheduleNextBreak()
            } else {
                updateTitle()
                return
            }
        }
        if breakController.isShowing { return }
        if Date() >= nextBreakAt {
            startBreak()
        } else {
            updateTitle()
        }
    }

    private func startBreak() {
        statusItem.button?.title = "👁 👀"
        breakController.show(duration: breakDuration) { [weak self] in
            self?.scheduleNextBreak()
        }
    }

    // MARK: - Actions

    @objc private func breakNow() {
        pausedUntil = nil
        startBreak()
    }

    @objc private func postpone() {
        nextBreakAt = Date().addingTimeInterval(5 * 60)
        updateTitle()
    }

    @objc private func pauseHour() {
        pausedUntil = Date().addingTimeInterval(60 * 60)
        updateTitle()
    }

    @objc private func resume() {
        pausedUntil = nil
        scheduleNextBreak()
    }

    @objc private func didWake() {
        if pausedUntil == nil { scheduleNextBreak() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
