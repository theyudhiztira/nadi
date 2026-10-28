## What and why

<!-- What does this change, and why is it needed? Link the issue if there is one. -->

## How I checked it

<!-- Commands you ran. For sensor changes: Mac model, chip and macOS version. -->

## Checklist

- [ ] `swift test` passes
- [ ] `scripts/bundle.sh` builds
- [ ] New logic in `NadiCore` has tests
- [ ] CPU stays under 1% with the panel closed, or I put measurements below
- [ ] Private APIs stay inside `NadiSensors` and `CPrivate`
- [ ] No new dependency and no network access
- [ ] `CHANGELOG.md` updated under Unreleased, if the change is user-visible
