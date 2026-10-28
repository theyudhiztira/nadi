# Releasing Nadi

Releases are ad-hoc signed ZIPs on GitHub Releases. There is no Apple Developer ID and no notarization, so users go through the Open Anyway step in the README's Install section.

Why a ZIP and not a DMG: on macOS 27, Finder refuses to copy an app that Apple has not notarized from a disk image into Applications ("This Mac could not verify the app, so nothing was installed"). An app unpacked from a ZIP copies in fine and only asks for Open Anyway on first launch.

`Resources/Info.plist` holds the version. The build number is the commit count, set by `scripts/bundle.sh`, so the panel footer reads like `v0.1.0 (64)`.

## Cut a release

1. Set `CFBundleShortVersionString` in `Resources/Info.plist` to the new version, for example `0.1.0`.
2. In `CHANGELOG.md`, rename `[Unreleased]` to `[0.1.0] - YYYY-MM-DD` and start a new empty `[Unreleased]` section above it.
3. Commit both files and push to `main`.
4. Tag the commit and push the tag:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. The Release workflow checks that the tag matches `Info.plist`, runs the tests, builds `Nadi-0.1.0.zip` with its `.sha256` file, and opens a draft release. Versions starting with `0.` are marked as pre-releases.
6. On GitHub, open the draft under Releases. Paste the version's CHANGELOG entry into the notes, download the ZIP once and install it on a Mac, then click Publish release.

If the workflow fails before the draft exists, fix the problem, then move the tag to the fixed commit:

```sh
git tag -f v0.1.0
git push -f origin v0.1.0
```

Only do this while the release is still a draft. Once a release is published, ship the fix as a new version.

## Build the ZIP locally

```sh
scripts/bundle.sh
scripts/make-zip.sh
```

The ZIP and its checksum land in `dist/`, which git ignores.
