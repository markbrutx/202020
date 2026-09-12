import AppKit

/// Играет случайную реплику из папки Sounds (пеон/крестьянин из Warcraft III, RU).
final class SoundPlayer {
    private var current: NSSound?
    private var lastPlayed: URL?
    private let files: [URL]

    init() {
        let fm = FileManager.default
        var candidates: [URL] = []
        // 1) Внутри .app бандла: Contents/Resources/Sounds
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("Sounds"))
        }
        // 2) Для swift run из репозитория
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var dir = exe.deletingLastPathComponent()
        for _ in 0..<5 {
            candidates.append(dir.appendingPathComponent("Sounds"))
            dir = dir.deletingLastPathComponent()
        }

        var found: [URL] = []
        for dirURL in candidates {
            if let items = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) {
                found = items.filter { ["wav", "mp3", "aiff", "ogg"].contains($0.pathExtension.lowercased()) }
                if !found.isEmpty { break }
            }
        }
        files = found
    }

    func playRandom() {
        guard !files.isEmpty else { NSSound.beep(); return }
        var pick = files.randomElement()!
        if files.count > 1, pick == lastPlayed { pick = files.first { $0 != pick }! }
        lastPlayed = pick
        current?.stop()
        current = NSSound(contentsOf: pick, byReference: true)
        current?.play()
    }
}
