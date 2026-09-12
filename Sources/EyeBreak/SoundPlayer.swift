import AppKit

/// Играет реплики из папки Sounds (крестьянин из Warcraft III, RU).
final class SoundPlayer {
    private var current: NSSound?
    private let dir: URL?

    init() {
        let fm = FileManager.default
        var candidates: [URL] = []
        // 1) Внутри .app бандла: Contents/Resources/Sounds
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("Sounds"))
        }
        // 2) Для swift run из репозитория
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var d = exe.deletingLastPathComponent()
        for _ in 0..<5 {
            candidates.append(d.appendingPathComponent("Sounds"))
            d = d.deletingLastPathComponent()
        }
        dir = candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("rabota-ne-volk.wav").path) }
    }

    func play(_ name: String) {
        guard let url = dir?.appendingPathComponent(name), FileManager.default.fileExists(atPath: url.path) else {
            NSSound.beep()
            return
        }
        current?.stop()
        current = NSSound(contentsOf: url, byReference: true)
        current?.play()
    }

    /// Начало перерыва: «Работа не волк, в лес не убежит»
    func playBreakStart() { play("rabota-ne-volk.wav") }
    /// Конец перерыва: «Опять работа!?»
    func playBreakEnd() { play("opyat-rabota.wav") }
}
