# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-27

### Added

- Settings window to pick and reorder menu bar metrics, set the refresh rate, switch between Celsius and Fahrenheit, and toggle Open at login (`SMAppService`).
- "Keep awake with lid closed" switch in the panel (`pmset -a disablesleep` with a one-time `/etc/sudoers.d/nadi-keep-awake` rule and automatic reset on quit or launch).
- Update notice in the panel that checks GitHub Releases once a day.
- App icons in the processes list.

### Changed

- Redesigned the panel in the Readout layout with full-width Canvas charts and an isolated panel store so opening and scrolling stay smooth.
- Replaced the grey track boxes in the menu bar strip with a thin baseline.

### Removed

- Red threshold tints and yellow slow-charging tint.

## [0.0.1] - 2026-10-29

First public beta.

### Added

- Menu bar strip for CPU, RAM, CPU temperature, power and network.
- Dropdown panel with 10-minute charts, per-core CPU load, memory pressure and swap, temperatures, GPU, fans, battery and adapter stats, network, disk and top processes.
- Sensor readers for SMC temperatures, fans and power, GPU usage, GPU power (`IOReport`) and `AppleSmartBattery`.
- `scripts/bundle.sh`, `scripts/make-zip.sh` and the GitHub Actions CI and Release workflows.

[Unreleased]: https://github.com/theyudhiztira/nadi/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/theyudhiztira/nadi/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/theyudhiztira/nadi/releases/tag/v0.0.1
