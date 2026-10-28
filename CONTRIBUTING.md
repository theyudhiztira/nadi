# Contributing to Nadi

Thanks for looking at Nadi. Bug reports, sensor dumps from other Macs and pull requests are all welcome.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems through [SECURITY.md](SECURITY.md), not the public tracker.

## Report a bug

Open an issue with the bug report template. Include:

- Mac model and chip, macOS version, Nadi version or commit.
- What you expected and what happened.
- Output of `.build/release/Nadi --dump 3` if a reading is missing or wrong.

Nadi has only been tested on an M1 Max. If a metric shows a dash on your Mac, a dump is the most useful thing you can send. Sensor names change between chip generations.

## Propose a change

For anything larger than a small fix, open an issue first so we can agree on the approach before you write code. Settings, history and alerts are already planned, so say in the issue if you want to take one of them.

## Set up

You need an Apple Silicon Mac on macOS 14 or later and a Swift 6 toolchain (Xcode 16 or later, or Command Line Tools with Swift 6).

```sh
git clone https://github.com/theyudhiztira/nadi.git
cd nadi
swift build
swift test
scripts/bundle.sh && open Nadi.app
```

## Code layout

- `NadiCore` is pure logic. It must not import AppKit or IOKit, so that tests can run it with fake sensors.
- `NadiSensors` holds one reader per sensor family. A reader returns `nil` on failure and never crashes the app. Keep every private API inside this module and `CPrivate`.
- `NadiApp` holds the status item, the renderer and the SwiftUI panel.

## Rules for pull requests

- One topic per pull request. Keep it small enough to review in one sitting.
- Add or update tests for logic in `NadiCore`. Sensor readers that need real hardware are checked by hand: say what you ran and on which Mac.
- `swift test` and `scripts/bundle.sh` must pass.
- Keep the CPU budget: under 1% CPU and under 50 MB of memory with the panel closed. If your change adds work to every tick, measure it and put the numbers in the pull request.
- No new dependencies without discussion. Nadi has none today.
- No network access and no telemetry.
- Match the surrounding code: naming, comment density and idiom. Comments explain why, not what.
- Write commit messages in the imperative, with a short subject line and a body that says why the change is needed.
- Fill in the pull request template.

## Add support for a new Mac or sensor

1. Run `.build/release/Nadi --dump 3` and note which metrics are missing.
2. Find the sensor keys for your chip. The existing readers in `Sources/NadiSensors` show which SMC keys and IOKit properties Nadi tries today.
3. Add the keys to the reader in `Sources/NadiSensors`, keeping the existing keys as the first choice.
4. In the pull request, list the Mac model, chip and macOS version you checked on.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE).
