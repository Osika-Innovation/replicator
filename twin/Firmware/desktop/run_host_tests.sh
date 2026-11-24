#!/bin/sh
# Host tests of the Desktop Replicator firmware. Touches no board.
#   ./run_host_tests.sh            C tests + constants check
#   PIOASM=/path/to/pioasm ./run_host_tests.sh    also assembles the .pio files
set -e
cd "$(dirname "$0")"
OUT="${TMPDIR:-/tmp}/desktop_fw_host"
mkdir -p "$OUT"
python3 tests/check_constants.py
cc -std=c11 -O2 -Wall -Wextra -Werror -o "$OUT/host_test" tests/host_test.c \
   lockin_xor.c cadence_sparse_q8.c frame_scheduler.c pulse_shocklet.c spinal_bus.c \
   resonance_lock.c bench_gate0.c plinth_io.c desktop_ram.c -lm
# CSQ8 images SIM exported; the NumPy reference settles one input for the C loader to match.
# PY=/path/to/python with MLX also cross-checks the reference against SIM's own class.
export CSQ8_DIR="${CSQ8_DIR:-$(cd ../../../holo/runs 2>/dev/null && pwd)}" CSQ8_REF="$OUT"
rm -f "$OUT"/*.ref "$OUT"/*.hleq "$OUT"/*.hleqref "$OUT"/*.fixref "$OUT"/lmq8_*
for n in sparse_cadence_q8 sparse_cadence_q8_quick; do
    [ -f "$CSQ8_DIR/$n.bin" ] && "${PY:-python3}" tests/csq8_reference.py "$CSQ8_DIR/$n.bin" "$OUT/$n.ref" || echo "csq8 reference: $n not made"
done
# LMQ8 calibration images at +0, +0.3 and +1 K from SIM's operators, one HLEQ goal packet, scenes and expected estimates.
"${PY:-python3}" tests/lmq8_reference.py "$OUT" || echo "lmq8 reference: not made"
"$OUT/host_test"
if [ -n "$PIOASM" ]; then
    for f in haptic smi_strip spinal_bus; do "$PIOASM" "$f.pio" "$OUT/$f.pio.h" && echo "pioasm: $f.pio assembled"; done
else
    echo "pioasm: skipped (set PIOASM to assemble the .pio files)"
fi
