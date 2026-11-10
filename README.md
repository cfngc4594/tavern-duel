# Tavern Duel

Godot card-battle prototype based on the `godot-child` particle optimization candidate from 2026-11-06. It is not a claim of improved whole-game FPS or Android stability.

## Build APK

Run **Actions → Android candidate APK → Run workflow**. The artifact contains the APK, SHA256 and validation report. Godot 4.7.1, ARM64, Forward+, and a compatible Vulkan 1.1+ Android device. Android version alone does not establish GPU/driver compatibility. Desktop and mobile both select Forward+; automatic OpenGL fallback is disabled. Headless CI verifies logic and packaging, not actual GPU rendering or device performance.

The CI build uses a fresh disposable debug signing key on every run. New test builds use a run-specific package ID (`org.dot.tavernduel.childcandidate.ciN`) and label so they install alongside earlier tests rather than overwriting their data. Existing CI1-CI4 builds shared a package ID and cannot update one another because their signatures differ. Do not uninstall an existing app with data you need. No persistent signing key is stored in this repository.

For privacy-sensitive device testing, run the Android workflow on **develop** with `privacy_test=true`. This produces a distinct `.privacy` package with a black screen and muted game audio. Do not install or launch the ordinary candidate as a privacy test. See [privacy-test precautions](ci/privacy-test.md). Physical screen-off behavior still requires separate validation and is not proved by the build.

## Source and scope

Desktop and mobile now use the same source-native board UI by default, including hand, heroes/powers, mana, decks, opening and targeting. Mouse input retains hover previews, a desktop drag threshold, right-click and Escape cancellation; touch keeps its existing gestures. The shared camera adapts to window aspect and preserves horizontal framing below the original 3:2 source anchor. See [UI synchronization and verification](ci/desktop-ui-sync-checkpoint.md) for tested sizes, reproducible checks and limits. This change is not a performance improvement claim.

The original snapshot came from `godot-child/TavernDuel`; subsequent commits fix packaging, mobile interaction and presentation bugs. Focused headless regressions run in CI, but do not replace Android device testing.

Git LFS is not required for this initial snapshot: largest file is below GitHub's 100 MiB per-file limit (about 27.9 MB), and the total source is about 580 MB. APKs, build output and imported Godot cache are excluded. Using regular Git avoids additional LFS bandwidth/storage quotas for Actions; reconsider LFS if large binary histories grow.

Third-party game artwork/audio retain their respective owners' rights. Keep private; no public distribution license is granted. Personal, non-commercial fan prototype.
