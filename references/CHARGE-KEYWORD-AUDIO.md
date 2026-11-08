# Charge keyword audio: independent archive finding

Checked 2026-10-16 at 10:43–10:47 UTC.

## Result

Found and downloaded the exact archive-named `Charge_Summon.wav` from the public HearthSounds Google Storage archive documented by its maintainer. The unchanged file is copied to `assets/audio/abilities/Charge_Summon.wav`. No scripts, existing voice mappings, or existing audio manifest changed.

The cue qualifies as `exact_named` archive identity. The same archive separately lists `Rush_Summon.wav` and generic `FX_MinionSummon` cast/drop/hand-transition files, supporting Charge keyword summon identity rather than the Charge spell or a generic landing effect. This is a strong filename/context inference, not an independently verified client event binding.

## Evidence

- Repository: https://github.com/mtimkovich/hearthsounds
- File base URL is explicit in the source: https://github.com/mtimkovich/hearthsounds/blob/1479994b696cde168345fb68cf67aef3af5f0d9a/hearthsounds.py#L22
- Maintainer describes reading raw audio filenames: https://github.com/mtimkovich/hearthsounds/issues/4#issuecomment-456666577
- Public Charge listing: https://storage.googleapis.com/hearthsounds?prefix=Charge
- Public Rush listing: https://storage.googleapis.com/hearthsounds?prefix=Rush
- Public generic summon listing: https://storage.googleapis.com/hearthsounds?prefix=FX_MinionSummon
- Direct bytes: https://storage.googleapis.com/hearthsounds/Charge_Summon.wav
- Archive modification time: 2018-11-29T11:40:21.211Z
- Size: 234,796 bytes
- PCM16 stereo, 48 kHz, 1.222667 seconds
- SHA-256: 53f86605126b1459a94a7194e8021b6d4bd54ed7e0f0c9d96954d44dfe885091
- MD5: d6cdee97ddd5dd7bbee3ff16efa56d59, matches the archive ETag

The downloaded source bytes and project copy are identical. Nothing was synthesized, substituted, locally transcoded, or cut from mixed gameplay audio.

## Limits

No claim is made about the exact 2014 client, original mix, onset timing, or a Blizzard-client hash. No subjective listening verification was performed. A numerical waveform comparison with the previously downloaded 2013 official Priest-vs-Hunter video did not produce a convincing matching event, and is not used as positive evidence.

Previously denied Firestone CDN, wiki/CardSFX, HearthSFX S3 and other download routes were not retried or bypassed. Original game audio remains copyrighted; public archive access does not establish redistribution rights.
