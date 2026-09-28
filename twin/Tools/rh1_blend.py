"""RH-1 render model (rev3) from the twin's OBJ export.

Run headless:
    blender -b --python Tools/rh1_blend.py -- cad-out/rh1.obj ../cad/rh1_freestanding_rev3.blend [preview.png]

Supersedes lpoh/cad/rh1_freestanding_rev2.blend as the render source: rev2
predates the 2026-08-03 bore resize and carries one middle plate, no door,
arcade or panels. This file is GENERATED from RH1Design via `fieldc cad
export` — edit the design, re-export, re-run; do not hand-edit geometry.

Scene: metres (the OBJ is mm), Z up, front = +X. Finishes per spec §8.
The section cutter (RH1_SectionCutter, a quarter wedge) is wired to every part
as a Boolean modifier, disabled — enable the modifiers to cut.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
obj_path = argv[0] if argv else "cad-out/rh1.obj"
out_path = argv[1] if len(argv) > 1 else "rh1_freestanding_rev3.blend"
preview = argv[2] if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0

bpy.ops.wm.obj_import(filepath=obj_path, global_scale=0.001,
                      forward_axis="Y", up_axis="Z")

# Kd straight from the MTL (the importer's viewport colour is not reliable)
KD = {}
try:
    cur = None
    for line in open(obj_path[:-4] + ".mtl"):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "newmtl":
            cur = parts[1]
        elif parts[0] == "Kd" and cur:
            KD[cur] = tuple(float(v) for v in parts[1:4])
except OSError:
    pass


def principled(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def setp(bsdf, name, value):
    if name in bsdf.inputs:
        bsdf.inputs[name].default_value = value


FINISH = {
    # material: (metallic, roughness, transmission, emission, alpha)
    "anodized": (0.75, 0.34, 0.0, 0.0, 1.0),
    "plateMetal": (1.0, 0.30, 0.0, 0.0, 1.0),
    "columnMetal": (1.0, 0.45, 0.0, 0.0, 1.0),
    "copper": (1.0, 0.25, 0.0, 0.0, 1.0),
    "bronze": (1.0, 0.30, 0.0, 0.0, 1.0),
    "pzt": (0.6, 0.35, 0.0, 0.0, 1.0),
    "ceramic": (0.0, 0.80, 0.0, 0.0, 1.0),
    "former": (0.0, 0.55, 0.0, 0.0, 1.0),
    "fr4": (0.0, 0.50, 0.0, 0.0, 1.0),
    "polymer": (0.0, 0.40, 0.0, 0.0, 1.0),
    "glass": (0.0, 0.05, 0.0, 0.0, 0.16),
    "photonic": (0.0, 0.15, 0.0, 0.0, 0.45),
    "emissive": (0.0, 0.50, 0.0, 4.0, 1.0),
    "placeholder": (0.0, 0.60, 0.0, 0.0, 0.45),
}
for mat in bpy.data.materials:
    key = mat.name.split(".")[0]
    if key not in FINISH or not mat.use_nodes:
        continue
    b = principled(mat)
    if b is None:
        continue
    metallic, rough, trans, emit, alpha = FINISH[key]
    if key in KD:
        r, g, bb = KD[key]
        setp(b, "Base Color", (r, g, bb, 1.0))
        mat.diffuse_color = (r, g, bb, 1.0)
    setp(b, "Metallic", metallic)
    setp(b, "Roughness", rough)
    setp(b, "Transmission Weight", trans)
    setp(b, "IOR", 1.52 if trans > 0 else 1.45)
    if emit > 0:
        setp(b, "Emission Color", b.inputs["Base Color"].default_value)
        setp(b, "Emission Strength", emit)
    setp(b, "Alpha", alpha)
    if alpha < 1.0 or trans > 0:
        try:
            mat.surface_render_method = "BLENDED"
        except (AttributeError, TypeError):
            pass

# collections per assembly (object names are "assembly__part")
root = bpy.data.collections.new("RH1_rev3")
scene.collection.children.link(root)
by_asm = {}
for ob in list(scene.objects):
    if ob.type != "MESH":
        continue
    asm = ob.name.split("__")[0] if "__" in ob.name else "misc"
    col = by_asm.get(asm)
    if col is None:
        col = bpy.data.collections.new(asm)
        root.children.link(col)
        by_asm[asm] = col
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    col.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for poly in ob.data.polygons:
        poly.use_smooth = False

# section cutter: a quarter wedge (x > 0, y < 0), wired but disabled
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.5, -0.5, 0.9))
cutter = bpy.context.active_object
cutter.name = "RH1_SectionCutter"
cutter.scale = (1.0, 1.0, 2.0)
cutter.display_type = "WIRE"
cutter.hide_render = True
for ob in scene.objects:
    if ob.type == "MESH" and ob is not cutter:
        m = ob.modifiers.new("section", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = cutter
        m.show_viewport = False
        m.show_render = False

# camera and lights (rev2 placements)
cam_data = bpy.data.cameras.new("Camera")
cam_data.lens = 50
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
cam.location = (2.9, -1.6, 1.45)
target = bpy.data.objects.new("RH1_Pivot", None)
scene.collection.objects.link(target)
target.location = (0, 0, 0.86)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
for name, loc, energy, size in [("Key", (2.6, 2.9, 2.6), 260, 1.6),
                                ("Fill", (-3.0, 2.0, 1.4), 90, 2.2),
                                ("Rim", (-0.6, -3.2, 2.2), 180, 1.2)]:
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(lo)
    lo.location = loc
    tc = lo.constraints.new("TRACK_TO")
    tc.target = target
    tc.track_axis = "TRACK_NEGATIVE_Z"
    tc.up_axis = "UP_Y"

world = bpy.data.worlds.new("World")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.20, 0.21, 0.23, 1)
bg.inputs[1].default_value = 0.55
scene.view_settings.exposure = -0.3
scene.world = world

# Deck-quality default: Cycles, denoised. The preview below uses Eevee.
try:
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
except (TypeError, AttributeError):
    pass
bpy.ops.wm.save_as_mainfile(filepath=out_path)
print(f"RH1BLEND saved {out_path}: {sum(1 for o in scene.objects if o.type == 'MESH') - 1} parts in "
      f"{len(by_asm)} assembly collections")

if preview:
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except TypeError:
            pass
    scene.render.resolution_x, scene.render.resolution_y = 1200, 1500
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print(f"RH1BLEND preview {preview} ({scene.render.engine})")
