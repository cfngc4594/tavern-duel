# Actual frozen-candidate GUI evidence

Six cases run in one process: both initial turn orders, win/lose/tie, real current-card lethal rules, original hero animation and result UI, repeated requests/Continue, restart during animation, and render target/audio cleanup.

The untouched original fixture log contains119 direct passes and6 dispatch equality failures. Independent strict numeric field comparison shows all6 actual side/spell types match the original source oracle. These are JSON numeric-type/Dictionary equality fixture failures, not corrected production behavior. Both raw failure records and independent reconciliation are preserved.

MovieWriter recorded1602 actual OpenGL frames at30 encoded FPS (53.4seconds), taking605.48 wall seconds on this llvmpipe cloud host. Encoded FPS is not a claim of real-time rendering performance. Original audio is the same engine Master mix, not manually overlaid clips. Actual PCM peak.57376, no fullscale samples. Exact source event fingerprints and weakness of mixed low-volume loops are separately documented; waveform correlation is not a claim of exact Unity mixing.

Normal-input full match acceptance is now recorded separately in normal_seat0/: original seed19031, actual Input.parse_input_event from start through turn7 natural defeat[-1,26],3 attacks/10 cards/1 hero power,16/16 checks, normal exit0 after510.72 wall seconds, stable hashes. Actual GUI only, no MovieWriter audio in that fallback. All13 selected rule/action/terminal fields match the earlier normal-input baseline. The six-case movie uses labeled preset lethal scenes and must not be relabeled as this natural game. The separate longer seat1 MovieWriter run stopped atturn10 with exit-9; its root cause remains unresolved, as documented in normal-seat1-exit-diagnostic.md.

Victory six-second delayed loop separately passed7 actual-mixer checks, including source-delay timing, actual player playback, close fade, and BGM restoration. Its9-second mixed WAV has no fullscale samples. Final independent CPU control suite222/222 and both-seat headless normal-input30/30 plus26 baseline comparisons also passed; these are not substitutes for the actual GUI results.

Host cause queries for the failed longer run were limited: dmesg returned Operation not permitted; journalctl had no journal files; cgroup event files were absent. No access was bypassed and no OOM explanation is claimed.
