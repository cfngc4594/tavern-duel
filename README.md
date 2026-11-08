# Tavern Duel

Private Godot card-battle prototype. This snapshot contains the latest `godot-child` particle optimization candidate from 2026-11-06. It is not a claim of improved whole-game FPS or Android stability.

## Build APK

Run **Actions → Android candidate APK → Run workflow**. The artifact contains the APK, SHA256 and validation report. Godot 4.7.1, ARM64, Android 7+.

The CI build uses a fresh disposable debug signing key on every run. It is a test build, not a release: it may not install over an existing build with the same package name and a different signature. Do not uninstall an existing app with data you need. No production signing key is stored in this repository.

## Source and scope

Production code is copied from `godot-child/TavernDuel`. CI configuration changes only packaging: platform texture import, portable template paths, package identity and version. No gameplay or particle code changes.

Git LFS is not required for this initial snapshot: largest file is below GitHub's 100 MiB per-file limit (about 27.9 MB), and the total source is about 580 MB. APKs, build output and imported Godot cache are excluded. Using regular Git avoids additional LFS bandwidth/storage quotas for Actions; reconsider LFS if large binary histories grow.

Third-party game artwork/audio retain their respective owners' rights. Keep private; no public distribution license is granted. Personal, non-commercial fan prototype.
