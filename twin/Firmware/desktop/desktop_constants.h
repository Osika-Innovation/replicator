// Desktop Replicator Rev F: the numbers the firmware shares with every lane.
// Source of truth: coordination/system_constants.json. tests/check_constants.py
// fails the host test run when a value here drifts from that file.
#ifndef DESKTOP_CONSTANTS_H
#define DESKTOP_CONSTANTS_H

// clock_and_bus
#define DR_XIN_HZ 12000000u
#define DR_SYS_CLK_HZ 150000000u
#define DR_SYNC_SKEW_MAX_NS 2.0f
#define DR_TRANSMIT_RING_US 125.0f
#define DR_CAPTURE_BURST_US 500.0f
#define DR_MCU_COUNT 6
#define DR_PCB_COUNT 3

// haptic_pzt
#define DR_SIGMA_DELTA_FS_HZ 75000000u
#define DR_ULTRASONIC_BW_HZ 200000u
#define DR_SFDR_GATE_MIN_DB 72.0f
#define DR_SFDR_SIMULATED_DBC 60.9f
#define DR_AD7380_FALLBACK_TRIGGERED 1
#define DR_BRIDGE_RAIL_V 18.0f                 // INS-30 (was 12.0)
#define DR_HBRIDGE_DRIVER_MPN "IXDD604SITR"    // CAD #35; was TC4427A (18 V limit, no enable pin)
#define DR_HBRIDGE_DRIVER_V_MAX 35.0f          // IXDD604 supply range 4.5-35 V; the 18 V rail has 17 V of headroom
#define DR_MAX_DRIVE_VRMS 16.2f
#define DR_C0_NOMINAL_PF 4450.0f               // O16 x 0.4 mm PZT disc, per port
#define DR_C0_BORO12_PF 171.0f
#define DR_FIRST_PARTICLE "eps_foam_30"
#define DR_HBRIDGE_DRIVER_HAS_TRISTATE_PIN 1   // EN low = both outputs high impedance: receive windows, interlock fault

// desktop_geometry
#define DR_PORTS_PER_PLATE 6
#define DR_PZT_DIAMETER_MM 16.0f
#define DR_PZT_THICKNESS_MM 0.4f
#define DR_PLATE_BENDING_STRESS_LIMIT_MPA 10.0f
#define DR_COMB_TONES 5
#define DR_COMB_TONES_HZ { 32000, 64000, 96000, 128000, 160000 }
#define DR_BORO12_COMB_TONES_HZ { 40000, 80000, 120000, 160000, 200000 }
#define DR_GOLOMB_BAND_LO_HZ 20000.0f
#define DR_GOLOMB_BAND_HI_HZ 198000.0f
#define DR_AIR_TEMP_TOLERANCE_K 0.1f

// mosquito_smi
#define DR_SMI_OMMATIDIA 24
#define DR_SMI_TIA_AC_GAIN 200

// cadence_brain
#define DR_CADENCE_SPARSE_MAX_BYTES 60000u
#define DR_CADENCE_DENSITY_MIN 0.05f
#define DR_CADENCE_DENSITY_MAX 0.10f
#define DR_CADENCE_SETTLE_MS_MIN 8.0f
#define DR_CADENCE_SETTLE_MS_MAX 15.0f

// Derived here (stated arithmetic, not in the JSON).
// One transmit ring: 18750 system ticks = 125 us = 4 periods of 32 kHz
// (desktop-200mm) = 5 periods of 40 kHz (boro12) = transmit_ring_us. 9375
// ticks (62.5 us, coherent_comb_window_us) holds 2 periods of 32 kHz but 2.5
// of 40 kHz, so it is not used as a ring.
#define DR_TX_RING_TICKS 18750u
#define DR_TX_RING_WORDS 9375u                 // two 12-pin steps per word
// The same ring on the 100 ns grid (haptic_tx at clock divider 15, CAD's
// HA0Drive grid): 1250 steps, 625 words, DMA at 5 M words/s instead of 75 M.
#define DR_TX_GRID_100NS_DIV 15u
#define DR_TX_RING_STEPS_100NS 1250u
#define DR_TX_RING_WORDS_100NS 625u
// One capture burst: capture_burst_us = 500 us = 37500 sigma-delta samples = 4 transmit rings
// = 16 periods of 32 kHz = 20 periods of 40 kHz. 125 us (9375 samples) is
// coherent too but is not a whole number of 32-bit capture words.
#define DR_BURST_SAMPLES 37500u
#define DR_BURST_WORDS 9375u                   // four 8-channel samples per word
#endif
