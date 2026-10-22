// nod: answer a yes/no question with AirPods head motion. Usage: nod [question] [--voice NAME] [--debug]
// Exit 0 = nod (yes), 1 = shake (no), 2 = timeout/unavailable.
import CoreMotion
import Foundation

var args = Array(CommandLine.arguments.dropFirst())
let debug = args.contains("--debug")
args.removeAll { $0 == "--debug" }
var voice = "Sangeeta (Enhanced)"  // falls back to the system voice if it isn't installed
if let i = args.firstIndex(of: "--voice"), i + 1 < args.count { voice = args[i + 1]; args.removeSubrange(i...i + 1) }
let question = args.joined(separator: " ")
let timeout = 6.0  // listening window after the tone, like AirPods call gestures

let mm = CMHeadphoneMotionManager()
guard mm.isDeviceMotionAvailable else { print("unavailable: no supported AirPods"); exit(2) }

func run(_ path: String, _ arguments: [String]) -> String {
    let p = Process(), out = Pipe()
    p.executableURL = URL(fileURLWithPath: path); p.arguments = arguments; p.standardOutput = out
    try? p.run(); p.waitUntilExit()
    return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
let hasVoice = run("/usr/bin/say", ["-v", "?"]).split(separator: "\n").contains { $0.hasPrefix(voice + " ") }
func speak(_ text: String) { _ = run("/usr/bin/say", (hasVoice ? ["-v", voice] : []) + ["-r", "200", text]) }

// Sounds like Apple's: a tone when listening starts, then one per outcome.
func chime(_ name: String) { _ = run("/usr/bin/afplay", ["/System/Library/Sounds/\(name).aiff"]) }
func finish(_ word: String, _ sound: String, _ code: Int32) -> Never { print(word); chime(sound); exit(code) }

// A gesture is a run of back-and-forth swings, not one big move: turning to look somewhere is a single swing.
// ponytail: swing-counting heuristic; swap for a small classifier if false positives persist
let window = 1.5, swing = 0.12  // seconds; radians (~7°) a move must cover to count as a swing

final class Swings {
    var extreme: Double?, dir = 0, times: [Double] = []
    func add(_ v: Double, _ t: Double) -> Int {
        guard let e = extreme else { extreme = v; return 0 }
        let d = v > e ? 1 : -1
        if d == dir || dir == 0 && abs(v - e) < swing { if d == dir { extreme = v }; return count(t) }
        if abs(v - e) >= swing { times.append(t); dir = d; extreme = v }
        return count(t)
    }
    func count(_ t: Double) -> Int { times.removeAll { t - $0 > window }; return times.count }
}

if !question.isEmpty { speak(question) }
chime("Tink")
var pitch = Swings(), yaw = Swings(), start = Date(), done = false, retried = false, listening = true

mm.startDeviceMotionUpdates(to: OperationQueue.main) { m, err in
    if let err { print("error: \(err.localizedDescription)"); exit(2) }
    guard !done, listening, let a = m?.attitude else { return }
    let now = Date().timeIntervalSince(start)
    let ps = pitch.add(a.pitch, now), ys = yaw.add(a.yaw, now)
    if debug { print(String(format: "pitch %+.2f yaw %+.2f  swings p %d y %d", a.pitch, a.yaw, ps, ys)) }
    if ys >= 3 && ys > ps { done = true; finish("shake", "Basso", 1) }
    if ps >= 3 && ps > ys { done = true; finish("nod", "Glass", 0) }
}

// One retry: if nothing was caught, say so and listen once more before giving up.
func expire() {
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        if done { return }
        if retried { finish("timeout", "Bottle", 2) }
        retried = true; listening = false
        speak("Sorry, nod or shake?")
        pitch = Swings(); yaw = Swings(); start = Date(); listening = true
        chime("Tink"); expire()
    }
}
expire()
dispatchMain()
