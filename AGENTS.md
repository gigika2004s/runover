# Repository contribution rules

## Automatic return to correction on failures

- Treat every failed test, analyzer check, or build as unfinished work. Resume diagnosis and correction in the same task; do not stop after reporting the failure.
- Read the complete failure output, identify the failing behavior, make the smallest appropriate fix, and rerun the failing command.
- After a focused check passes, run the full relevant suite and build before calling the work complete or creating a final commit.
- Do not hide, skip, weaken, or delete a check to get a green result. Update an assertion only when the intended product behavior changed, and keep regression coverage for that behavior.
- If a failure cannot be fixed because required information or access is missing, state the specific blocker and leave the work marked incomplete.

## Protect Android signing credentials before every commit

- Keep `app/android/key.properties` and the upload keystore local; never force-add or commit them.
- Before every commit, inspect the staged file list and diff for signing credentials. This repository's `.githooks/pre-commit` blocks signing files and checks staged content against local signing passwords.
- Enable the hook once in each clone with `git config core.hooksPath .githooks`. Do not bypass the hook to get a commit through.
- If signing material is ever committed or pushed, treat it as compromised: revoke/rotate it and remove it from repository history before continuing.

## Required Flutter checks

Run these from `app/` before completing Flutter changes:

```sh
flutter analyze
flutter test
flutter build web
```

The GitHub `Tests / flutter` checks must pass before a change is considered ready to merge.
