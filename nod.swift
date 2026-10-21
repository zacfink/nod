// Spike: print "nod" or "shake" from AirPods head motion. Usage: nod [question] [--debug]
// Exit 0 = nod (yes), 1 = shake (no), 2 = timeout/unavailable.
import CoreMotion
import Foundation

let args = CommandLine.arguments.dropFirst()
let debug = args.contains("--debug")
let question = args.filter { $0 != "--debug" }.joined(separator: " ")
let timeout = 6.0  // listening window after the tone, like AirPods call gestures

let mm = CMHeadphoneMotionManager()
guard mm.isDeviceMotionAvailable else { print("unavailable: no supported AirPods"); exit(2) }

if !question.isEmpty {
    let say = Process()
    say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    say.arguments = [question]
    try? say.run(); say.waitUntilExit()
}

// Sounds like Apple's: a tone when listening starts, then one per outcome.
func chime(_ name: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
    p.arguments = ["/System/Library/Sounds/\(name).aiff"]
    try? p.run(); p.waitUntilExit()
}
func finish(_ word: String, _ sound: String, _ code: Int32) -> Never { print(word); chime(sound); exit(code) }
chime("Tink")

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
let pitch = Swings(), yaw = Swings(), start = Date()
var done = false

mm.startDeviceMotionUpdates(to: OperationQueue.main) { m, err in
    if let err { print("error: \(err.localizedDescription)"); exit(2) }
    guard !done, let a = m?.attitude else { return }
    let now = Date().timeIntervalSince(start)
    let ps = pitch.add(a.pitch, now), ys = yaw.add(a.yaw, now)
    if debug { print(String(format: "pitch %+.2f yaw %+.2f  swings p %d y %d", a.pitch, a.yaw, ps, ys)) }
    if ys >= 3 && ys > ps { done = true; finish("shake", "Basso", 1) }
    if ps >= 3 && ps > ys { done = true; finish("nod", "Glass", 0) }
}

DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish("timeout", "Bottle", 2) }
dispatchMain()
