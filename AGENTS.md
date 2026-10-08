# Repository contribution rules

## Respect separate Web and Android releases

- Web and Android have independent release channels. Before changing a platform's behavior, deployment, or release configuration, inspect the latest release for that platform, including its version/tag, notes, and artifacts. Use it as that platform's production baseline rather than assuming the default branch is deployed.
- Keep Web and Android versions, release notes, artifacts, and deployment timing independent. Do not require matching version numbers, publish both together, or change the other platform's release when a task targets only one.
- When diagnosing a production issue, compare the affected platform's code and configuration with its own release tag, then make the fix on the working branch. Preserve that platform's versioning and deployment conventions.
- Build and deployment artifacts must be traceable to an explicit platform release tag or commit. Do not deploy an unversioned local artifact or silently move an existing release tag.
- Create or publish a new release only when the task explicitly includes releasing. Tie each release's notes and artifacts to the exact platform and tag.
- The Flutter CI must validate release-mode builds for both targets on every Flutter run, while keeping publishing and deployment independently controlled for each platform.

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
