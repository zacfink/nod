# Nod

Answer your AI with your head. `nod "Merge the branch?"` reads the question out loud through your AirPods, plays a
tone, then listens for 6 seconds: nod for yes, shake for no.

- **Yes:** three up-down swings → prints `nod`, exit code 0
- **No:** three side-to-side swings → prints `shake`, exit code 1
- **Nothing:** turning to look at something is a single swing, so it doesn't count → `timeout`, exit code 2

Because the answer is an exit code, any script or AI agent can use it:

```bash
if nod "Run the tests again?"; then ./test.sh; fi
```

I use it with Claude Code for plain yes/no questions. Anything outward (sending, posting, deleting, buying) still
gets confirmed at the keyboard, not with a nod.

## Build

Needs macOS 14+, Xcode's command line tools, and AirPods that report head motion (AirPods Pro, AirPods 3/4 or Max).

```bash
swiftc -O nod.swift -o nod -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
./nod "Does this work?"   # macOS asks for motion access the first time
```

Add `--debug` to print the live pitch and yaw. It's one 60-line Swift file using `CMHeadphoneMotionManager`.
