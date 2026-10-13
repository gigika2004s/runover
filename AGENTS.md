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

## Protect Android signing credentials before every commit

- Keep `app/android/key.properties` and the upload keystore local; never force-add or commit them.
- Before every commit, inspect the staged file list and diff for signing credentials. This repository's `.githooks/pre-commit` blocks signing files and checks staged content against local signing passwords.
- Enable the hook once in each clone with `git config core.hooksPath .githooks`. Do not bypass the hook to get a commit through.
- If signing material is ever committed or pushed, treat it as compromised: revoke/rotate it and remove it from repository history before continuing.
- The GitHub `Secret scan` check is the remote backstop. Keep it required alongside the local hook; never suppress a finding without verifying that it is a documented test value.

## Keep platform releases independent

- Web deploys through Render from `main`; Android releases use `android-vMAJOR.MINOR.PATCH` tags and publish a signed APK to a GitHub Release.
- Do not change or publish both platforms as one release. Keep Android version/build numbers derived from the Android tag and workflow run.
- Keep production CORS origins explicit in `CORS_ALLOWED_ORIGINS`; do not restore wildcard origins.

## Required Flutter checks

The app has Web and Android releases. Run these from `app/` before completing Flutter changes:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

- A Flutter change is incomplete until both release-mode builds succeed. These are CI compile checks; the Android APK currently uses the debug signing key and is not a distributable production release.
- Tests remain `flutter test`; do not replace them with release builds. Run the analyzer, tests, and both release builds before considering the change ready to merge.
- The GitHub `Tests / flutter` checks must pass before a change is considered ready to merge.

## Keep the codebase consistent

- Reuse shared helpers instead of duplicating logic: `formatPoints` (`app/lib/format.dart`), `findItem`, `styledName`, `bannerGradient`, `profileAvatarImage` (`app/lib/widgets/cosmetics.dart`). Do not copy regexes, gradients, or avatar-resolution chains into screens.
- Every field a router returns must be declared on its response schema. Pydantic silently drops undeclared fields, which looks exactly like "not saved" (see the `pronouns` regression and `backend/tests/test_profile_fields.py`).
- Every mutating endpoint must call `lock_mutations(db)`, then commit (and refresh before returning the updated object). Include each router exactly once in `backend/app/main.py`.
- API errors speak pt-BR, end with a period, and use a fixed status map: 400 validation, 401 credentials, 402 insufficient funds, 403 permission, 404 missing, 409 duplicate/conflict.
- Shop catalog rules are enforced in code: unique ids and names (`_assert_unique`), everything animated, and scope guards in both directions (`user`/`team`/`pass` items are only purchasable and equippable in their own store).
- Remove code orphaned by a change (widgets, helpers, constants) in the same task; do not leave dead private members behind.
- Never mention other apps or services in code, strings, or docs.
- New backend tests use pytest function style with the `conftest.py` fixtures (`client`, `registered_user`, `db_session`); leave the existing unittest-style files untouched. Run the suites the CI runs (`unittest discover`, the documented pytest files); a red full-directory `pytest` run is a known runner-mixing artifact, not a regression.
- Widget tests must use `pump` (never `pumpAndSettle`) on screens with looping animations (storefront glow, particles, `Breathe`). If a pre-existing first-frame artifact appears, drain it once with a comment instead of masking the final exception guard.
- Alembic revisions stay in a single chain; when adding one, update the head asserted in `test_migrations_stamp_current_version`.
