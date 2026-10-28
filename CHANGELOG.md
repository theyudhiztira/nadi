# Changelog

All notable changes to this project are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2026-10-29

First public build, released as a beta.

### Added

- Menu bar item with live graphs for CPU, RAM, CPU temperature, power and network.
- Dropdown panel with 10-minute history charts, per-core CPU load, memory pressure and swap, temperatures, GPU, fans, battery and charger details, network, disk and the top processes.
- Sensor readers for SMC temperatures, fans and power, GPU usage, GPU power through `IOReport`, and `AppleSmartBattery`.
- `scripts/bundle.sh`, which builds `Nadi.app` and signs it ad hoc.
- `Nadi --dump` and `Nadi --render-panel` debugging flags.
- README, contributing guide, code of conduct, security policy, issue and pull request templates, and a CI workflow.
- App icon, also shown at the top of the README.
- The panel footer shows the app version and build number.
- Hovering a history chart or a core bar shows its value.
- `scripts/make-zip.sh` and a Release workflow that turns a version tag into a draft GitHub release with a ZIP and its SHA-256 checksum.

### Known gaps

- No settings window, 24-hour history or alerts yet.
- Tested only on an M1 Max running macOS 27.0.1.

[Unreleased]: https://github.com/theyudhiztira/nadi/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/theyudhiztira/nadi/releases/tag/v0.0.1
