# Repository contribution rules

## Use published GitHub releases as the production reference

- Before changing behavior, deployment, or release configuration, inspect the latest published GitHub Release and its tag/changelog. Use that release as the production baseline; do not assume the default branch is what users currently run.
- When diagnosing a production issue, compare the affected code and configuration with the release tag, then make the fix on the working branch. Preserve the release's versioning and deployment conventions.
- Build and deployment artifacts must be traceable to an explicit release tag or commit. Do not deploy an unversioned local artifact or silently move an existing release tag.
- Create or publish a new GitHub Release only when the task explicitly includes releasing. Keep release notes and artifacts tied to the exact tag.
- For this Flutter app, validate release-mode builds for both supported targets, Web and Android, on every Flutter CI run.

## Automatic return to correction on failures

- Treat every failed test, analyzer check, or build as unfinished work. Resume diagnosis and correction in the same task; do not stop after reporting the failure.
- Read the complete failure output, identify the failing behavior, make the smallest appropriate fix, and rerun the failing command.
- After a focused check passes, run the full relevant suite and build before calling the work complete or creating a final commit.
- Do not hide, skip, weaken, or delete a check to get a green result. Update an assertion only when the intended product behavior changed, and keep regression coverage for that behavior.
- If a failure cannot be fixed because required information or access is missing, state the specific blocker and leave the work marked incomplete.

## Required Flutter checks

The app has Web and Android releases. Run these from `app/` before completing Flutter changes:

```sh
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

- A Flutter change is incomplete until both production builds succeed. Keep checks for both platforms in GitHub Actions so a green Web build cannot hide an Android release failure, or vice versa.
- Tests remain `flutter test`; do not replace them with release builds. Run the analyzer, tests, and both release builds before considering the change ready to merge.
- The GitHub `Tests / flutter` checks must pass before a change is considered ready to merge.
