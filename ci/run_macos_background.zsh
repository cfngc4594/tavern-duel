#!/bin/zsh
set -eu

godot_app=${TAVERN_DUEL_GODOT_APP:-/Applications/Godot.app}
expected_version=4.7.1.stable.official.a13da4feb
if [[ $(uname -s) != Darwin || $("$godot_app/Contents/MacOS/Godot" --headless --version) != "$expected_version" ]]; then
    print -u2 "Background rendering requires Godot $expected_version on macOS."
    exit 78
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/tavern-duel-background.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
background_app="$scratch/Tavern Duel Benchmark.app"
cp -cR "$godot_app" "$background_app"
plist="$background_app/Contents/Info.plist"
# Launch Services reads this before the process can change its Cocoa policy.
plutil -replace LSUIElement -bool true "$plist"
plutil -replace CFBundleIdentifier -string dev.tavernduel.godot-benchmark "$plist"
codesign --force --sign - "$background_app" 2> "$scratch/codesign.log" || {
    cat "$scratch/codesign.log" >&2
    exit 78
}
godot="$background_app/Contents/MacOS/Godot"
xcrun clang -dynamiclib -fobjc-arc -framework AppKit \
    -o "$scratch/window.dylib" "${0:A:h}/macos_background_window.m"

# Probe with a headless invocation so failed injection cannot flash a window.
preflight=$(TAVERN_DUEL_BACKGROUND_PREFLIGHT=1 DYLD_INSERT_LIBRARIES="$scratch/window.dylib" \
    "$godot" --headless --version)
if [[ "$preflight" != *TAVERN_DUEL_BACKGROUND_READY* ]]; then
    print -u2 'Could not install the Godot background window handler.'
    exit 78
fi

print -r -- 'MACOS_BENCHMARK_MODE background'
DYLD_INSERT_LIBRARIES="$scratch/window.dylib${DYLD_INSERT_LIBRARIES:+:$DYLD_INSERT_LIBRARIES}" "$godot" "$@"
