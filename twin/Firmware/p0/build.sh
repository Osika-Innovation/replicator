#!/bin/sh
# Compile the P0 controller firmware. Compiling is not flashing: this script
# never touches a board.
#   PICO_SDK_PATH=/path/to/pico-sdk PICO_TOOLCHAIN_PATH=/path/to/arm-gnu-toolchain ./build.sh [build-dir]
# Built 2026-11-12 with: pico-sdk tag 2.1.1 (commit bddd20f9), Arm GNU
# Toolchain 14.2.rel1 arm-none-eabi (developer.arm.com; Homebrew's
# arm-none-eabi-gcc has no C library and will not do), cmake 4.2.
set -e
cd "$(dirname "$0")"
: "${PICO_SDK_PATH:?set PICO_SDK_PATH to a pico-sdk checkout (tag 2.1.1)}"
OUT="${1:-build}"
cmake -S . -B "$OUT" -DCMAKE_BUILD_TYPE=Release ${PICO_TOOLCHAIN_PATH:+-DPICO_TOOLCHAIN_PATH="$PICO_TOOLCHAIN_PATH"} > "$OUT.configure.log" 2>&1 || { tail -20 "$OUT.configure.log"; exit 1; }
cmake --build "$OUT" -j 8 > "$OUT.build.log" 2>&1 || { grep -E 'error|Error' -A3 "$OUT.build.log" | head -40; exit 1; }
"${PICO_TOOLCHAIN_PATH:+$PICO_TOOLCHAIN_PATH/bin/}arm-none-eabi-size" "$OUT/p0.elf"
shasum -a 256 "$OUT/p0.uf2" "$OUT/p0.elf"
