#!/usr/bin/env bash
# Build a performance-oriented Phira APK native library for 32-bit ARM (armv7).
#
# This script implements the compile-time part of the low-end-device optimization:
#   - opt-level=3 / thin LTO / panic=abort / codegen-units=1 come from the
#     workspace [profile.release] in Cargo.toml
#   - default features are dropped (no video decoding, no bundled extras) via
#     --no-default-features
#   - NEON is enabled for SIMD-accelerated image/audio work on modern ARMv7 CPUs.
#     If you must support NEON-less ARMv7 chips, drop `+neon` from RUSTFLAGS.
#
# The runtime visual downgrade (disable MSAA/shader/particles) is applied
# automatically at startup in prpr/src/config.rs for 32-bit ARM targets.
#
# Usage:
#   ANDROID_NDK_HOME=/path/to/ndk ./scripts/build_armv7_lite.sh [extra cargo args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

TARGET="armv7-linux-androideabi"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    echo "Error: ANDROID_NDK_HOME is not set." >&2
    echo "Set it to your Android NDK path, e.g. ANDROID_NDK_HOME=/opt/android-ndk" >&2
    exit 1
fi

# API level 21 is the minimum that still targets armv7 with modern NDKs.
API="${NDK_API_LEVEL:-21}"
HOST_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$HOST_TAG" in
    linux*)   HOST_TAG="linux-x86_64" ;;
    darwin*)  HOST_TAG="darwin-x86_64" ;;
    msys*|mingw*|cygwin*) HOST_TAG="windows-x86_64" ;;
esac

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"
export PATH="$TOOLCHAIN:$PATH"
export CC_armv7_linux_androideabi="$TOOLCHAIN/armv7a-linux-androideabi${API}-clang"
export CXX_armv7_linux_androideabi="$TOOLCHAIN/armv7a-linux-androideabi${API}-clang++"
export AR_armv7_linux_androideabi="$TOOLCHAIN/llvm-ar"

# ARMv7-A + NEON. Remove +neon if targeting NEON-less CPUs.
export RUSTFLAGS="${RUSTFLAGS:-} -C target-feature=+neon -C link-arg=-fuse-ld=lld"

echo "==> Building $TARGET (lite / optimized for low-end devices)"
cargo build --release --locked \
    --target "$TARGET" \
    -p phira \
    --no-default-features \
    "$@"

echo "==> Done. Native library:"
ls -lh "target/$TARGET/release/libphira.so"
