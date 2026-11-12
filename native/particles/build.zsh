#!/bin/zsh
set -eu

source_dir="${0:A:h}"
project_dir="${source_dir:h:h}"
deps_dir="$project_dir/build/native-particles/godot-cpp"
addon_dir="$project_dir/addons/tavern_native_particles"
godot_cpp_revision=ed79ed472127e86f619d0ecc1274a943278d5257
target="${1:-all}"
jobs="${TAVERN_NATIVE_JOBS:-$(getconf _NPROCESSORS_ONLN)}"

case "$target" in
  all|macos|android) ;;
  *) print -u2 "Usage: $0 [all|macos|android]"; exit 2 ;;
esac

mkdir -p "$deps_dir" "$addon_dir"
if [[ ! -d "$deps_dir/.git" ]]; then
  git init -q "$deps_dir"
fi
if [[ "$(git -C "$deps_dir" rev-parse --verify HEAD 2>/dev/null || true)" != "$godot_cpp_revision" ]]; then
  git -C "$deps_dir" fetch --depth=1 https://github.com/godotengine/godot-cpp.git "$godot_cpp_revision"
  git -C "$deps_dir" checkout --quiet --detach "$godot_cpp_revision"
fi

build_library() {
  scons -Q -C "$source_dir" -j "$jobs" platform="$1" arch=arm64 target=template_release \
    build_profile="$source_dir/build_profile.json" precision=single
}

if [[ "$target" == all || "$target" == macos ]]; then
  build_library macos
fi
if [[ "$target" == all || "$target" == android ]]; then
  if [[ -z "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}${ANDROID_NDK_ROOT:-}" && "$(uname -s)" == Darwin ]]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
  fi
  build_library android
fi
cp "$source_dir/tavern_native_particles.gdextension" "$addon_dir/"
cp "$deps_dir/LICENSE.md" "$addon_dir/godot-cpp.LICENSE.txt"
