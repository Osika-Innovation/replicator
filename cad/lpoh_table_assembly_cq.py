"""
LPOH Table Assembly — CadQuery version for the live browser viewer.
View at http://localhost:8321 (auto-reloads on save).

7+7 hex ring layout: center + 6 at 60° spacing.
Top plate rotated 30° for acoustic path diversity.
"""
import cadquery as cq
import math

# ── Parameters (edit these, save, viewer auto-reloads) ──
TRANSDUCER_OD     = 16.0
TRANSDUCER_HEIGHT = 12.0
HOLE_CLEARANCE    = 0.5
HOLE_DIA          = TRANSDUCER_OD + HOLE_CLEARANCE

PLATE_THICKNESS   = 3.0
RING_RADIUS       = 22.0
EDGE_MARGIN       = 4.0
PLATE_RADIUS      = RING_RADIUS + HOLE_DIA/2 + EDGE_MARGIN

GAP               = 60.0     # between inner plate faces
TOP_ROTATION      = 30.0     # degrees

PILLAR_DIA        = 8.0      # M8
PILLAR_HOLE_DIA   = PILLAR_DIA + 0.4
PILLAR_OFFSET     = PLATE_RADIUS - 6.0
N_PILLARS         = 3
PILLAR_HEIGHT     = GAP + 2 * PLATE_THICKNESS

MATCHING_HEIGHT   = 4.0      # gradient matching layer thickness

STANDOFF_HOLE_DIA = 3.2
N_STANDOFFS       = 3
STANDOFF_RADIUS   = PLATE_RADIUS - 5.0


def hex_positions(r, offset_deg=0):
    pts = [(0.0, 0.0)]
    for k in range(6):
        a = math.radians(offset_deg + k * 60)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def make_plate(ring_offset_deg=0):
    pts = hex_positions(RING_RADIUS, ring_offset_deg)
    plate = cq.Workplane("XY").circle(PLATE_RADIUS).extrude(PLATE_THICKNESS)
    plate = plate.faces(">Z").workplane().pushPoints(pts).hole(HOLE_DIA, PLATE_THICKNESS + 0.1)
    standoffs = [
        (STANDOFF_RADIUS * math.cos(i * 2*math.pi/N_STANDOFFS + math.pi/6),
         STANDOFF_RADIUS * math.sin(i * 2*math.pi/N_STANDOFFS + math.pi/6))
        for i in range(N_STANDOFFS)
    ]
    plate = plate.faces(">Z").workplane().pushPoints(standoffs).hole(STANDOFF_HOLE_DIA, PLATE_THICKNESS + 0.1)
    return plate


def make_transducer():
    body = cq.Workplane("XY").circle(TRANSDUCER_OD/2).extrude(TRANSDUCER_HEIGHT)
    face = cq.Workplane("XY").workplane(offset=TRANSDUCER_HEIGHT - 0.5).circle(TRANSDUCER_OD/2 - 1).extrude(0.5)
    return body.union(face)


def make_pillar():
    return cq.Workplane("XY").circle(PILLAR_DIA/2).extrude(PILLAR_HEIGHT)


def make_matching_layer():
    return cq.Workplane("XY").circle(PLATE_RADIUS - 1).extrude(MATCHING_HEIGHT)


def make_viewer_assembly():
    assy = cq.Assembly(name="LPOH_table")

    bot_pos = hex_positions(RING_RADIUS, 0)
    top_pos = hex_positions(RING_RADIUS, TOP_ROTATION)

    # Bottom plate
    assy.add(make_plate(0),
             name="bottom_plate",
             color=cq.Color(0.27, 0.51, 0.71, 0.8))

    # Bottom transducers
    for k, (x, y) in enumerate(bot_pos):
        t = make_transducer()
        assy.add(t, name=f"bot_transducer_{k}",
                 loc=cq.Location((x, y, PLATE_THICKNESS - TRANSDUCER_HEIGHT)),
                 color=cq.Color(0.3, 0.3, 0.3, 0.9))

    # Bottom matching layer
    assy.add(make_matching_layer(),
             name="bottom_matching",
             loc=cq.Location((0, 0, PLATE_THICKNESS)),
             color=cq.Color(0.7, 0.9, 1.0, 0.25))

    # Pillars
    for k in range(N_PILLARS):
        a = math.radians(k * 360 / N_PILLARS + 30)
        px = PILLAR_OFFSET * math.cos(a)
        py = PILLAR_OFFSET * math.sin(a)
        assy.add(make_pillar(), name=f"pillar_{k}",
                 loc=cq.Location((px, py, 0)),
                 color=cq.Color(0.5, 0.5, 0.5, 0.4))

    # Top matching layer
    z_top_match = PLATE_THICKNESS + GAP - MATCHING_HEIGHT
    assy.add(make_matching_layer(),
             name="top_matching",
             loc=cq.Location((0, 0, z_top_match)),
             color=cq.Color(0.7, 0.9, 1.0, 0.25))

    # Top plate
    z_top = PLATE_THICKNESS + GAP
    assy.add(make_plate(TOP_ROTATION),
             name="top_plate",
             loc=cq.Location((0, 0, z_top)),
             color=cq.Color(0.27, 0.51, 0.71, 0.8))

    # Top transducers
    for k, (x, y) in enumerate(top_pos):
        t = make_transducer()
        assy.add(t, name=f"top_transducer_{k}",
                 loc=cq.Location((x, y, z_top + PLATE_THICKNESS)),
                 color=cq.Color(0.3, 0.3, 0.3, 0.9))

    return assy
