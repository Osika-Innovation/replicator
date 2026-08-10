// icosahedron_12port_v5.scad
// ------------------------------------------------------------------
// v5 — simplified first prototype for 3 mm pre-wired LEDs.
//
// Solid SLA icosahedron. 12 bores at vertices with:
//   - external cylindrical collar (2 mm tall, 6 mm OD) for glue joint
//   - 3.2 mm bore (0.2 mm clearance for 3 mm LED + glue)
//   - 4.5 mm cylindrical depth for LED body
//   - hemispheric seat at the bore tip for the LED's dome
//
// Assembly:
//   LEDs inserted tip-first from OUTSIDE the body. Dome seats into the
//   hemispheric cap at the bore's inner end. Wires stick out through
//   the collar. Dab of UV resin in the bore before insertion bonds
//   everything when cured.
//
// Physics unchanged from v3: solid SLA body IS the optical medium.
// Photons propagate from one LED dome through the bulk to other LED
// domes. Just smaller LEDs, cleaner vertex ports.
// ------------------------------------------------------------------

// ---- PARAMETERS ----
circumradius       = 20;    // center → outer vertex (mm)
socket_diameter    = 3.2;   // 3 mm LED + 0.2 mm glue clearance
socket_depth       = 3.0;   // cylindrical portion of bore (until hemisphere)
dome_radius        = 1.6;   // hemispheric seat for LED dome (≈ socket/2)
collar_od          = 6.0;   // external collar outer diameter
collar_height      = 2.0;   // how far collar protrudes past outer face
collar_embed       = 9.0;   // how far collar cylinder extends INWARD to merge
                            // cleanly with the icosahedron's faces (instead
                            // of floating on the pointy vertex).
fn_global          = 48;    // curves; bump to 96 for final if needed
// --------------------

$fn = fn_global;

// --- Icosahedron geometry (same math as v3 / v4) ---
phi            = (1 + sqrt(5)) / 2;
icos_raw_norm  = sqrt(1 + phi * phi);
icos_scale     = circumradius / icos_raw_norm;

icos_vertices_raw = [
    [0,  1,  phi], [0,  1, -phi], [0, -1,  phi], [0, -1, -phi],
    [ 1,  phi, 0], [ 1, -phi, 0], [-1,  phi, 0], [-1, -phi, 0],
    [ phi, 0,  1], [ phi, 0, -1], [-phi, 0,  1], [-phi, 0, -1],
];

// Orient so one FACE points down (stable base, all 12 vertices pointy).
face_center_raw  = [(0 + phi + 1) / 3, (-1 + 0 - phi) / 3, (-phi - 1 + 0) / 3];
face_center_unit = face_center_raw / norm(face_center_raw);
rot_axis         = cross(face_center_unit, [0, 0, -1]);
rot_axis_norm    = norm(rot_axis);
rot_angle        = acos(face_center_unit * [0, 0, -1]);

function apply_rotation(p) =
    rot_axis_norm < 1e-6 ? p :
    (let (k = rot_axis / rot_axis_norm, c = cos(rot_angle), s = sin(rot_angle))
     p * c + cross(k, p) * s + k * (k * p) * (1 - c));

icos_unit  = [ for (v = icos_vertices_raw) apply_rotation(v) / icos_raw_norm ];
icos_outer = [ for (u = icos_unit) u * circumradius ];

icos_faces = [
    [0, 2, 8], [0, 8, 4], [0, 4, 6], [0, 6, 10], [0, 10, 2],
    [3, 9, 5], [3, 5, 7], [3, 7, 11], [3, 11, 1], [3, 1, 9],
    [8, 2, 5], [8, 5, 9], [8, 9, 4], [4, 9, 1], [4, 1, 6],
    [6, 1, 11], [6, 11, 10], [10, 11, 7], [10, 7, 2], [2, 7, 5],
];

module solid_icosahedron() {
    polyhedron(points = icos_outer, faces = icos_faces, convexity = 4);
}

// ---- Per-vertex feature helpers ----

// Apply the rotation that takes local +Z to the outward radial direction
// at a vertex u, then run children() in that frame.
module at_vertex(u) {
    outward   = u;
    axis      = cross([0, 0, 1], outward);
    axis_norm = norm(axis);
    ang       = acos(outward[2]);
    translate(outward * circumradius) {
        if (axis_norm > 1e-6)       rotate(a = ang, v = axis) children();
        else if (outward[2] > 0)                              children();
        else                         rotate([180, 0, 0])      children();
    }
}

// External collar: a raised ring around each vertex's bore.
// In local frame, +z is outward, z = 0 is the outer vertex point. The
// cylinder extends INWARD by collar_embed (so it merges cleanly with
// the triangular faces meeting at the vertex) and OUTWARD by
// collar_height (the visible raised lip).
module collar(u) {
    at_vertex(u) {
        translate([0, 0, -collar_embed])
            cylinder(h = collar_embed + collar_height, d = collar_od);
    }
}

// Bore + hemispheric dome seat, subtracted through the collar and body.
module bore_with_dome(u) {
    at_vertex(u) {
        // Clear out the collar + body to depth socket_depth from the
        // outer face. Local z goes from z = collar_height (top of collar)
        // DOWN to z = -socket_depth (inside the body).
        translate([0, 0, -socket_depth])
            cylinder(h = socket_depth + collar_height + 0.5,
                     d = socket_diameter);

        // Hemispheric seat: half-sphere at z = -socket_depth, dome
        // opening further negative z (inward). LED's 3 mm dome seats
        // into this 1.6 mm-radius cup with ~0.1 mm glue clearance.
        translate([0, 0, -socket_depth])
            sphere(r = dome_radius);
    }
}

// ---- Assembled part ----
module icosahedron_12port() {
    difference() {
        union() {
            solid_icosahedron();
            for (u = icos_unit) collar(u);
        }
        for (u = icos_unit) bore_with_dome(u);
    }
}

icosahedron_12port();

// ---- Informational echos ----
echo("circumradius (to vertex)  =", circumradius, "mm");
echo("outer edge length         =", 2 * icos_scale, "mm (LED-to-LED spacing)");
echo("socket bore               =", socket_diameter, "mm × depth", socket_depth, "mm");
echo("dome seat radius          =", dome_radius, "mm");
echo("collar                    = OD", collar_od, "mm, height", collar_height, "mm");
echo("LED tip depth from vertex =", socket_depth + dome_radius, "mm");
echo("LED tip distance from center =", circumradius - socket_depth - dome_radius, "mm");
echo("A5 irrep decomposition on 12 vertices: 1 + 3 + 3' + 5");
