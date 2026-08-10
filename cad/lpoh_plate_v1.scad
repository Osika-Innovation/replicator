// lpoh_plate_v1.scad
// ------------------------------------------------------------------
// Last Piece Of Hardware — Phase 1 plate.
//
// 200 × 200 × 5 mm acrylic/PLA plate. Three-machines-in-one host:
//   - acoustic hologram  (4 × 40 kHz tweeters, phased)
//   - optical compute     (4 × 5 mm RGB LED + 4 × 5 mm photodiode)
//   - 3D printer mode     (UV 365 nm LED bores up through the centre)
//
// Mount holes for a Waveshare RP2350B + 2.8" LCD module off to one side.
// Edge slots for 4 × 16 mm piezo transducers acting as large-area RX.
//
// Generated as a single flat part. Rendered to STL, then printed
// face-down on FDM. Drill slightly if fits are tight.
// ------------------------------------------------------------------

// ---- PARAMETERS ----
plate_x          = 200;
plate_y          = 200;
plate_z          = 5;

// Acoustic hologram: 4 tweeters in a square, symmetric about centre.
tweeter_od       = 16.2;    // 16 mm tweeter + 0.2 mm clearance
tweeter_pitch    = 110;     // centre-to-centre, opposing tweeters aim
                            // at each other across 110 mm

// Piezo RX disks: 4 × 16 mm, mounted on the edges (between tweeters).
piezo_od         = 20.5;    // 20 mm piezo disc + 0.5 mm clearance
piezo_edge_off   = 18;      // centre of piezo, from plate edge

// Optical IO: 4 × 5 mm RGB LED + 4 × 5 mm photodiode. Interleaved
// around the inner ring so each LED faces a PD across the chamber.
opt_ring_radius  = 32;      // radius of optical IO ring, mm
opt_led_od       = 5.2;     // 5 mm LED + 0.2 mm clearance
opt_pd_od        = 5.2;
opt_count        = 8;       // 4 LED + 4 PD alternating

// UV printer LED (centre): points UP through a small hole, lights
// the levitation volume for resin cure.
uv_od            = 5.2;

// Waveshare RP2350B + 2.8" LCD mounting: 4 × M2.5 standoffs in a
// 52 × 70 rectangle (verify against your exact board silkscreen).
lcd_origin       = [65, 0];
lcd_rect         = [52, 70];
standoff_od      = 3.0;     // through-hole for M2.5

// Perf-board scratch pad off to the opposite side.
perf_origin      = [-65, 0];
perf_rect        = [40, 60];
perf_standoff    = 3.0;

// General cosmetics
fn_global        = 64;
label_depth      = 0.6;     // engraved text depth
// --------------------

$fn = fn_global;

module plate_blank() {
    translate([0, 0, -plate_z / 2])
        cube([plate_x, plate_y, plate_z], center = false)
        ;
}

// --- Acoustic tweeters: 4 in a square at ±pitch/2 ---
tweeter_pos = [
    [plate_x/2 - tweeter_pitch/2, plate_y/2 - tweeter_pitch/2],
    [plate_x/2 + tweeter_pitch/2, plate_y/2 - tweeter_pitch/2],
    [plate_x/2 + tweeter_pitch/2, plate_y/2 + tweeter_pitch/2],
    [plate_x/2 - tweeter_pitch/2, plate_y/2 + tweeter_pitch/2],
];

module tweeter_holes() {
    for (p = tweeter_pos)
        translate([p[0], p[1], -plate_z])
            cylinder(h = plate_z * 3, d = tweeter_od);
}

// --- Piezo RX discs: 4 edge-centered between tweeters ---
piezo_pos = [
    [plate_x/2, piezo_edge_off],             // south edge
    [plate_x - piezo_edge_off, plate_y/2],   // east  edge
    [plate_x/2, plate_y - piezo_edge_off],   // north edge
    [piezo_edge_off, plate_y/2],             // west  edge
];

module piezo_holes() {
    for (p = piezo_pos)
        translate([p[0], p[1], -plate_z])
            cylinder(h = plate_z * 3, d = piezo_od);
}

// --- Optical ring: 8 holes alternating LED / PD around centre ---
module optical_ring() {
    for (i = [0 : opt_count - 1]) {
        ang = 360 * i / opt_count;
        x = plate_x/2 + opt_ring_radius * cos(ang);
        y = plate_y/2 + opt_ring_radius * sin(ang);
        d = (i % 2 == 0) ? opt_led_od : opt_pd_od;
        translate([x, y, -plate_z])
            cylinder(h = plate_z * 3, d = d);
    }
}

// --- UV LED: single 5 mm hole in the dead centre ---
module uv_hole() {
    translate([plate_x/2, plate_y/2, -plate_z])
        cylinder(h = plate_z * 3, d = uv_od);
}

// --- Board mounting standoffs ---
module rect_standoffs(origin_xy, rect_wh, d) {
    cx = plate_x/2 + origin_xy[0];
    cy = plate_y/2 + origin_xy[1];
    w  = rect_wh[0];
    h  = rect_wh[1];
    for (dx = [-w/2, w/2], dy = [-h/2, h/2])
        translate([cx + dx, cy + dy, -plate_z])
            cylinder(h = plate_z * 3, d = d);
}

module lcd_standoffs() { rect_standoffs(lcd_origin,  lcd_rect,  standoff_od); }
module perf_standoffs() { rect_standoffs(perf_origin, perf_rect, perf_standoff); }

// --- Engraved labels (cosmetic, shallow) ---
module label_at(xy, text_str, sz) {
    translate([xy[0], xy[1], -label_depth])
        linear_extrude(height = label_depth + 0.01)
            text(text_str, size = sz, halign = "center",
                 valign = "center", font = "Helvetica");
}

module labels() {
    // Corner labels near each tweeter
    for (i = [0 : 3]) {
        p = tweeter_pos[i];
        ang = 360 * i / 4 + 45;
        off = 15;
        translate([p[0] + off * cos(ang), p[1] + off * sin(ang), 0])
            label_at([0, 0], str("T", i + 1), 4);
    }
    // Edge piezo labels
    piezo_tags = ["P1", "P2", "P3", "P4"];
    for (i = [0 : 3])
        translate([piezo_pos[i][0], piezo_pos[i][1] +
                   (i == 0 ? 14 : i == 2 ? -14 : 0), 0]) {
            // offset text off-axis so it isn't under the piezo
            if (i == 1) translate([-14, 0, 0]) label_at([0, 0], piezo_tags[i], 4);
            else if (i == 3) translate([14, 0, 0]) label_at([0, 0], piezo_tags[i], 4);
            else label_at([0, 0], piezo_tags[i], 4);
        }
    // Centre label
    translate([plate_x/2, plate_y/2 - 10, 0])
        label_at([0, 0], "UV", 3);
}

// --- Assembled plate ---
module lpoh_plate() {
    difference() {
        plate_blank();
        tweeter_holes();
        piezo_holes();
        optical_ring();
        uv_hole();
        lcd_standoffs();
        perf_standoffs();
        labels();
    }
}

lpoh_plate();

// ---- Informational echos ----
echo("plate                =", plate_x, "x", plate_y, "x", plate_z, "mm");
echo("tweeter pitch        =", tweeter_pitch, "mm (opposing pair baseline)");
echo("tweeter OD           =", tweeter_od, "mm");
echo("piezo OD             =", piezo_od, "mm");
echo("optical ring radius  =", opt_ring_radius, "mm");
echo("optical holes        =", opt_count, "(4 LED + 4 PD alternating)");
echo("UV centre hole OD    =", uv_od, "mm");
echo("LCD standoffs rect   =", lcd_rect, "mm (M2.5)");
echo("perf standoffs rect  =", perf_rect, "mm (M2.5)");
