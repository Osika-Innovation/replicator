// ══════════════════════════════════════════════════════════════════
// LPOH Table Assembly — The Last Piece of Hardware
// ══════════════════════════════════════════════════════════════════
// 6+6 ultrasonic transducers in hex ring layout,
// top plate rotated 30° for acoustic path diversity.

// ── Parameters ─────────────────────────────────────────────────
transducer_od     = 16;
transducer_height = 12;
hole_clearance    = 0.5;
hole_dia          = transducer_od + hole_clearance;

pin_dia           = 0.6;
pin_length        = 5;
pin_spacing       = 10;

plate_thickness   = 3;
ring_radius       = 26;
edge_margin       = 4;
plate_radius      = ring_radius + hole_dia/2 + edge_margin;
corner_radius     = 5;

gap               = 50;
top_rotation      = 30;

// (plate shape is a circle now)

// ── Transducer ─────────────────────────────────────────────────
module transducer(pins_up = true) {
    color("DimGray")
    cylinder(h = transducer_height, d = transducer_od, $fn = 32);

    // Two pin legs
    pin_z = pins_up ? transducer_height : -pin_length;
    color("Gold")
    for (dx = [-pin_spacing/2, pin_spacing/2]) {
        translate([dx, 0, pin_z])
        cylinder(h = pin_length, d = pin_dia, $fn = 8);
    }
}

// ── Ring positions (6 transducers, no center) ──────────────────
function ring_positions(r, offset_deg = 0) =
    [for (k = [0:5])
        [r * cos(offset_deg + k * 60),
         r * sin(offset_deg + k * 60)]
    ];

// ── Array plate (hex aligned with transducer ring) ─────────────
module array_plate(ring_offset_deg = 0) {
    positions = ring_positions(ring_radius, ring_offset_deg);

    difference() {
        // Circular plate
        color("SteelBlue", 0.7)
        cylinder(h = plate_thickness, r = plate_radius, $fn = 64);

        // Transducer holes
        for (p = positions) {
            translate([p[0], p[1], -0.1])
            cylinder(h = plate_thickness + 0.2, d = hole_dia, $fn = 32);
        }
    }
}

// ══════════════════════════════════════════════════════════════════
// ASSEMBLY
// ══════════════════════════════════════════════════════════════════

// ── Bottom plate ───────────────────────────────────────────────
array_plate(0);

// ── Bottom transducers (pins down) ─────────────────────────────
for (p = ring_positions(ring_radius, 0)) {
    translate([p[0], p[1], plate_thickness - transducer_height])
    transducer(pins_up = false);
}

// ── Top plate ──────────────────────────────────────────────────
translate([0, 0, plate_thickness + gap])
array_plate(top_rotation);

// ── Top transducers (pins up) ──────────────────────────────────
for (p = ring_positions(ring_radius, top_rotation)) {
    translate([p[0], p[1], plate_thickness + gap + plate_thickness])
    transducer(pins_up = true);
}

// ── Build volume indicator ─────────────────────────────────────
%translate([0, 0, plate_thickness + 8])
color("Yellow", 0.05)
cylinder(h = gap - 16, r = ring_radius - 5, $fn = 32);
