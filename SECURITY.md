# Security policy

## Supported versions

Nadi is pre-release. Only the latest commit on `main` receives fixes. Once tagged releases exist, only the latest release will.

## Report a vulnerability

Do not open a public issue for a security problem.

Use GitHub's private reporting: open the repository's Security tab and choose "Report a vulnerability". Include:

- What the problem is and which file or feature it touches.
- Steps to reproduce, with your Mac model and macOS version.
- What an attacker could do with it.

You can expect an acknowledgement within 7 days. Nadi is maintained by one person, so a fix may take longer, and you will get status updates while it is open. Credit in the release notes is given if you want it.

## What counts

Nadi runs as your user, makes no network connections, and needs no elevated privileges. Reports in scope include:

- Memory-safety or parsing bugs in the code that reads SMC, IOKit or `IOReport` data.
- Anything that makes Nadi write outside its own data folder, execute external input, or open a network connection.
- A flaw in `scripts/bundle.sh` or the CI workflows that could tamper with a built app.

Out of scope:

- Nadi uses undocumented system interfaces by design (SMC, `IOHIDEventSystemClient`, `IOReport`). That alone is not a vulnerability. See the [README](README.md#private-apis).
- Release builds are ad-hoc signed and not notarized, which is documented.
- Vulnerabilities in macOS itself.
