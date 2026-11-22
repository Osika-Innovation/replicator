#!/usr/bin/env python3
"""desktop_constants.h against coordination/system_constants.json. Exit 1 on drift."""
import json, pathlib, re, sys
here = pathlib.Path(__file__).resolve().parent
c = json.loads((here / "../../../../coordination/system_constants.json").read_text())
h = (here / "../desktop_constants.h").read_text()
def macro(name):
    m = re.search(r"#define\s+%s\s+(.+?)\s*(//.*)?$" % name, h, re.M)
    if not m: sys.exit("missing " + name)
    return m.group(1).strip()
def num(name): return float(macro(name).rstrip("uf"))
def txt(name): return macro(name).strip('"')
def lst(name): return [float(x) for x in macro(name).strip("{} ").split(",")]
cb, hp, dg, sm, br = c["clock_and_bus"], c["haptic_pzt"], c["desktop_geometry"], c["mosquito_smi"], c["cadence_brain"]
want = [
    ("DR_XIN_HZ", cb["xin_hz"]), ("DR_SYS_CLK_HZ", cb["sys_clk_hz"]), ("DR_SYNC_SKEW_MAX_NS", cb["sync_skew_max_ns"]),
    ("DR_MCU_COUNT", cb["mcu_count_full_machine"]), ("DR_PCB_COUNT", cb["pcb_count"]),
    ("DR_SIGMA_DELTA_FS_HZ", hp["sigma_delta_fs_hz"]), ("DR_ULTRASONIC_BW_HZ", hp["ultrasonic_bw_hz"]),
    ("DR_SFDR_GATE_MIN_DB", hp["sfdr_gate_min_db"]), ("DR_SFDR_SIMULATED_DBC", hp["sfdr_simulated_dbc"]),
    ("DR_TRANSMIT_RING_US", cb["transmit_ring_us"]), ("DR_CAPTURE_BURST_US", cb["capture_burst_us"]),
    ("DR_HBRIDGE_DRIVER_V_MAX", hp["hbridge_driver_v_max"]), ("DR_MAX_DRIVE_VRMS", hp["max_drive_vrms"]),
    ("DR_C0_NOMINAL_PF", hp["c0_nominal_pf"]), ("DR_C0_BORO12_PF", hp["c0_boro12_pf"]),
    ("DR_PZT_DIAMETER_MM", dg["pzt_diameter_mm"]), ("DR_PZT_THICKNESS_MM", dg["pzt_thickness_mm"]),
    ("DR_PLATE_BENDING_STRESS_LIMIT_MPA", dg["plate_bending_stress_limit_mpa"]),
    ("DR_AD7380_FALLBACK_TRIGGERED", int(hp["ad7380_fallback_triggered"])), ("DR_BRIDGE_RAIL_V", hp["bridge_rail_v"]),
    ("DR_HBRIDGE_DRIVER_HAS_TRISTATE_PIN", int(hp["hbridge_driver_has_tristate_pin"])),
    ("DR_PORTS_PER_PLATE", dg["ports_per_plate"]), ("DR_COMB_TONES", len(dg["comb_tones_hz"])),
    ("DR_GOLOMB_BAND_LO_HZ", dg["golomb_band_khz"][0] * 1e3), ("DR_GOLOMB_BAND_HI_HZ", dg["golomb_band_khz"][1] * 1e3),
    ("DR_AIR_TEMP_TOLERANCE_K", dg["air_temp_tolerance_k"]),
    ("DR_SMI_OMMATIDIA", sm["total_ommatidia"]), ("DR_SMI_TIA_AC_GAIN", sm["tia_ac_gain"]),
    ("DR_CADENCE_SPARSE_MAX_BYTES", br["cadence_sparse_max_kb"] * 1e3),
    ("DR_CADENCE_DENSITY_MIN", br["target_block_sparsity_range"][0]), ("DR_CADENCE_DENSITY_MAX", br["target_block_sparsity_range"][1]),
    ("DR_CADENCE_SETTLE_MS_MIN", br["rp2350_settle_target_ms_range"][0]), ("DR_CADENCE_SETTLE_MS_MAX", br["rp2350_settle_target_ms_range"][1]),
]
bad = [(n, num(n), v) for n, v in want if abs(num(n) - v) > 1e-6 * max(1.0, abs(v))]
for n, v in (("DR_COMB_TONES_HZ", dg["comb_tones_hz"]), ("DR_BORO12_COMB_TONES_HZ", dg["boro12_comb_tones_hz"])):
    if lst(n) != [float(x) for x in v]: bad.append((n, lst(n), v))
for n, v in (("DR_FIRST_PARTICLE", hp["first_particle"]), ("DR_HBRIDGE_DRIVER_MPN", hp["hbridge_driver_mpn"])):
    if txt(n) != v: bad.append((n, txt(n), v))
tick_us = 1e6 / cb["sys_clk_hz"]
derived = [("DR_TX_RING_TICKS", tick_us, cb["transmit_ring_us"]), ("DR_TX_RING_WORDS", 2 * tick_us, cb["transmit_ring_us"]),
           ("DR_BURST_SAMPLES", 1e6 / hp["sigma_delta_fs_hz"], cb["capture_burst_us"]), ("DR_BURST_WORDS", 4e6 / hp["sigma_delta_fs_hz"], cb["capture_burst_us"])]
for n, unit, v in derived:
    if abs(num(n) * unit - v) > 1e-6: bad.append((n, "%g us" % (num(n) * unit), "%g us" % v))
if hp["bridge_rail_v"] > hp["hbridge_driver_v_max"]: bad.append(("bridge_rail_v", hp["bridge_rail_v"], "above hbridge_driver_v_max %s" % hp["hbridge_driver_v_max"]))
for b in bad: print("DRIFT %s: header %s, constants %s" % b)
print("constants: %d values checked, %d drifted" % (len(want) + 9, len(bad)))
sys.exit(1 if bad else 0)
