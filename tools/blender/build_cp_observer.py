# CANTEEN PROTOCOL -- CP_Observer, the overseer, built end to end.
#
# Run inside Blender. IDEMPOTENT: it clears any previous build first, so it can
# be re-run after any edit and produce the same model, texture and FBX.
#
# WHY A SCRIPT AND NOT A .blend: the same reason the arena rig is a script. A
# hand-built .blend records the RESULT; this records the DECISIONS, so changing
# one proportion is a one-line edit and a re-run rather than an archaeology
# exercise in someone else's mesh.
#
# ORDER MATTERS, and it bit twice during authoring: the per-face material zones
# ARE the texture's source data, so the collapse to a single shipping material
# must happen LAST. Consolidating early destroys the zone information and the
# painter then has nothing to read.
#
# TARGET FRAME (measured in the live place, not assumed):
#   Observer marker sits 7 studs above the table top, over the table CENTRE.
#   It is HORIZONTAL with world up -- a downward-looking frame would tilt the
#   whole figure by the same angle. Head tilt therefore belongs here, in the
#   model, not in the marker.
#   Blender is Z-up / -Y-forward; Roblox is Y-up / -Z-forward. The figure is
#   built facing -Y and the FBX exporter's default axis conversion does the rest.
#   Object origin (0,0,0) is the SHOULDER HANG POINT, because Roblox moves this
#   model by its pivot.

import bpy, math, os

OUT_DIR = r"C:\Users\Asus\Claude\Kenopsia_Roblox Project\docs\assets"
SIZE = 256          # the brief's number, and one Roblox texture upload
TRI_BUDGET = 2500

# Palette lifted from the colours already in the shipped Luau (housing 30/29/28,
# lens 150/20/16, stalk 42/40/38) so the model does not arrive looking like it
# came from a different game than the room it hangs in.
PALETTE = {
    "UniformDark": (0x1A, 0x19, 0x17),
    "UniformMid":  (0x2A, 0x28, 0x26),
    "Leather":     (0x5C, 0x53, 0x48),
    "Skin":        (0x8A, 0x84, 0x78),
    "Collar":      (0xC9, 0xC2, 0xB4),
    "LensRed":     (0x96, 0x14, 0x10),
    "Metal":       (0x6E, 0x6A, 0x62),
    "NewsPaper":   (0xB8, 0xB2, 0xA4),
    "NewsInk":     (0x17, 0x16, 0x14),
}

PAPER_HINGE = (0.0, -1.62, -1.24)   # the folded hands: where the paper pivots


# --------------------------------------------------------------- scaffolding

def wipe():
    for ob in [o for o in bpy.data.objects if o.type == 'MESH']:
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(block):
            if b.users == 0:
                block.remove(b)


def zone_materials():
    mats = {}
    for name in PALETTE:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        mats[name] = m
    return mats


MATS = {}


def _finish(ob, zone):
    ob.data.materials.clear()
    ob.data.materials.append(MATS[zone])
    return ob


def box(name, zone, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0, rz=0.0):
    """Centre and FULL size, so every number reads as a real dimension."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz))
    ob = bpy.context.object
    ob.name = name
    ob.scale = (sx, sy, sz)
    ob.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(ob, zone)


def cyl(name, zone, cx, cy, cz, radius, depth, verts=8, rx=0.0, ry=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius,
                                        depth=depth, location=(cx, cy, cz))
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = (math.radians(rx), math.radians(ry), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(ob, zone)


# -------------------------------------------------------------------- build

def build_body():
    # PROPORTIONS ARE CORRECTED FOR FORESHORTENING, not chosen from a front
    # view. Every player sees this from ~5 studs BELOW and ~10 out, which
    # projects the lower body larger and the head smaller. A first pass
    # proportioned front-on read as a bollard; head and cap were enlarged and
    # the lower body shortened until it read from the angle it is actually seen
    # from.

    # Suspension. Behind the head (y +0.95), never through it.
    cyl("Mount_Column", "Metal",   0, 0.95, 6.50, 0.30, 11.0, verts=8)
    box("Mount_Yoke",   "Metal",   0, 0.74, 0.85, 2.40, 0.55, 0.50)
    box("Mount_HookL",  "Leather", -1.05, 0.56, 0.72, 0.30, 0.55, 0.62)
    box("Mount_HookR",  "Leather",  1.05, 0.56, 0.72, 0.30, 0.55, 0.62)

    # Head, deliberately narrow against wide shoulders: a small head on a broad
    # frame reads as institutional bulk rather than as a person. No facial
    # detail is modelled because none of it survives 25-30 degrees off centre
    # in a dark room.
    box("Head", "Skin", 0, 0.02, 2.05, 1.60, 1.55, 1.75)
    box("Jaw",  "Skin", 0, -0.22, 1.35, 1.35, 1.15, 0.45)

    # The peaked cap is the officer read -- the first shape that crosses the
    # ceiling light. The crown is an 8-gon so it does not become a second head,
    # and the peak overhangs far enough to shadow the lens.
    cyl("Cap_Crown", "UniformDark", 0, 0.02, 3.15, 1.15, 0.55, verts=8)
    box("Cap_Band",  "UniformDark", 0, 0.02, 2.86, 1.72, 1.70, 0.22)
    box("Cap_Peak",  "UniformDark", 0, -1.22, 2.72, 1.85, 1.30, 0.15, rx=-7)

    # One lens where a face should be. It is the only part of this model the
    # mechanic needs read, so it faces dead -Y and sits clear of the peak.
    cyl("Lens",      "LensRed", 0, -0.86, 2.06, 0.44, 0.28, verts=8, rx=90)
    cyl("Lens_Ring", "Metal",   0, -0.76, 2.06, 0.56, 0.16, verts=8, rx=90)

    # A flared collar swallows the neck from every angle a seated player has,
    # which removes the last human proportion.
    cyl("Neck", "Skin", 0, 0.02, 1.05, 0.42, 0.60, verts=6)
    box("Collar_Back", "Collar", 0, 0.50, 1.15, 2.35, 0.30, 1.25)
    box("Collar_L",    "Collar", -1.05, 0.02, 1.00, 0.32, 1.05, 1.05)
    box("Collar_R",    "Collar",  1.05, 0.02, 1.00, 0.32, 1.05, 1.05)

    # Torso: chest 3.10 tapering to a 2.05 abdomen, then a coat hem that flares
    # back out to 2.40. Wide-over-narrow is the authority silhouette; the flare
    # gives one hard horizontal at the bottom. Two stacked boxes rather than a
    # smooth taper -- the step at the waist is a PS1 signature and costs 12
    # triangles instead of 40.
    box("Chest",   "UniformMid", 0, 0.05, -0.30, 3.10, 1.70, 2.20)
    box("Abdomen", "UniformMid", 0, 0.05, -2.15, 2.05, 1.45, 1.50)
    box("Hem",     "UniformMid", 0, 0.05, -3.30, 2.40, 1.60, 1.30)
    box("Epaulette_L", "UniformMid", -1.72, 0.05, 0.62, 1.15, 1.60, 0.36, ry=9)
    box("Epaulette_R", "UniformMid",  1.72, 0.05, 0.62, 1.15, 1.60, 0.36, ry=-9)

    # Folded arms, held clear of the torso. Arms hanging at the sides vanish
    # into the body from below; crossed arms give a hard horizontal band and
    # read as waiting rather than as hanging.
    cyl("UpperArm_L", "UniformMid", -1.78, -0.26, -0.55, 0.36, 1.80, verts=6, rx=-8, ry=6)
    cyl("UpperArm_R", "UniformMid",  1.78, -0.26, -0.55, 0.36, 1.80, verts=6, rx=-8, ry=-6)
    box("Elbow_L", "UniformMid", -1.76, -0.44, -1.38, 0.56, 0.56, 0.50)
    box("Elbow_R", "UniformMid",  1.76, -0.44, -1.38, 0.56, 0.56, 0.50)
    box("Forearm_Low",  "UniformMid",  0.10, -1.20, -1.42, 2.85, 0.50, 0.48, ry=-5)
    box("Forearm_High", "UniformMid", -0.10, -1.44, -1.04, 2.75, 0.48, 0.46, ry=6)
    box("Glove_L", "Leather", -1.58, -1.38, -1.00, 0.62, 0.64, 0.56, ry=6)
    box("Glove_R", "Leather",  1.60, -1.14, -1.48, 0.62, 0.64, 0.56, ry=-5)
    box("Belt",   "Leather", 0, 0.05, -1.32, 2.45, 1.55, 0.34)
    box("Buckle", "Metal",   0, -0.80, -1.32, 0.55, 0.15, 0.42)

    bpy.ops.object.select_all(action='DESELECT')
    for o in [o for o in bpy.data.objects if o.type == 'MESH']:
        o.select_set(True)
    body = bpy.data.objects["Chest"]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "CP_Observer"

    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.shade_flat()
    return body


def build_paper():
    # A SEPARATE OBJECT, because Roblox hinges it at runtime: raised hides the
    # face, lowered exposes the lens. Two panels in a shallow V -- a single slab
    # reads as a board, the fold reads as paper -- at no extra triangle cost.
    box("Paper_L", "NewsPaper", -0.78, -1.70, 0.72, 1.62, 0.07, 3.92, rz=8)
    box("Paper_R", "NewsPaper",  0.78, -1.70, 0.72, 1.62, 0.07, 3.92, rz=-8)
    box("Paper_Spine", "NewsInk", 0.0, -1.66, 0.72, 0.16, 0.10, 3.92)

    bpy.ops.object.select_all(action='DESELECT')
    for n in ("Paper_L", "Paper_R", "Paper_Spine"):
        bpy.data.objects[n].select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["Paper_L"]
    bpy.ops.object.join()
    paper = bpy.context.object
    paper.name = "Newspaper"

    # The origin must BE the hinge. Roblox rotates this about its own origin, so
    # an origin at the panel centre would swing the paper through his chest.
    bpy.context.scene.cursor.location = PAPER_HINGE
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.shade_flat()
    return paper


# ---------------------------------------------------------------- unwrap/paint

def unwrap(objects):
    # Multi-object edit mode packs islands from every mesh into ONE 0..1 space
    # without overlap, which is what lets a single 256 map serve the whole
    # character. Unwrapping separately would stack both at full size.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    # 89 degrees keeps every flat face its own island rather than stretching one
    # across a hard corner -- correct precisely because nothing here is smooth.
    bpy.ops.uv.smart_project(angle_limit=math.radians(89), island_margin=0.03)
    bpy.ops.object.mode_set(mode='OBJECT')


def paint(objects):
    buf = [None] * (SIZE * SIZE)

    def fill_tri(p0, p1, p2, colour_at):
        xs = (p0[0], p1[0], p2[0]); ys = (p0[1], p1[1], p2[1])
        x0, x1 = max(0, int(min(xs)) - 1), min(SIZE - 1, int(max(xs)) + 1)
        y0, y1 = max(0, int(min(ys)) - 1), min(SIZE - 1, int(max(ys)) + 1)
        d = ((p1[1] - p2[1]) * (p0[0] - p2[0]) + (p2[0] - p1[0]) * (p0[1] - p2[1]))
        if abs(d) < 1e-12:
            return
        for y in range(y0, y1 + 1):
            py = y + 0.5
            for x in range(x0, x1 + 1):
                px = x + 0.5
                a = ((p1[1] - p2[1]) * (px - p2[0]) + (p2[0] - p1[0]) * (py - p2[1])) / d
                b = ((p2[1] - p0[1]) * (px - p2[0]) + (p0[0] - p2[0]) * (py - p2[1])) / d
                # -0.06 slack closes the half-texel gaps between adjacent
                # islands that otherwise show as bright seams once mipmapped.
                if a >= -0.06 and b >= -0.06 and (1.0 - a - b) >= -0.06:
                    buf[y * SIZE + x] = colour_at(x, y)

    for ob in objects:
        me = ob.data
        uvs = me.uv_layers.active.data
        for poly in me.polygons:
            zone = me.materials[poly.material_index].name
            if zone not in PALETTE:
                raise KeyError(
                    "face has material %r, which is not a palette zone. The "
                    "single shipping material must be applied AFTER painting."
                    % zone)
            base = PALETTE[zone]
            # PS1 artists painted the light INTO the map because the hardware
            # gave them almost nothing at runtime. Same here: up-facing faces
            # lift, down-facing sink. It is the single biggest reason a flat-
            # coloured low-poly mesh stops looking like placeholder geometry.
            shade = 0.64 + 0.36 * (poly.normal.z * 0.5 + 0.5)
            rgb = tuple(min(255, int(round(c * shade))) for c in base)

            if zone == "NewsPaper":
                ink = tuple(min(255, int(round(c * shade)))
                            for c in PALETTE["NewsInk"])

                def colour_at(x, y, rgb=rgb, ink=ink):
                    # The one place the texture must carry what geometry cannot:
                    # a blank slab reads as a board, ruled columns read as a
                    # newspaper.
                    if (y % 22) >= 18:
                        return ink
                    if (y % 4) == 0 and (x % 9) < 6:
                        return tuple(int(c * 0.55) for c in rgb)
                    return rgb
            else:
                def colour_at(x, y, rgb=rgb):
                    return rgb

            pts = [(uvs[li].uv.x * SIZE, uvs[li].uv.y * SIZE)
                   for li in poly.loop_indices]
            for i in range(1, len(pts) - 1):
                fill_tri(pts[0], pts[i], pts[i + 1], colour_at)

    # Bleed island colours outward so mip generation and bilinear filtering
    # cannot pull the background in along a seam.
    for _ in range(4):
        nxt = buf[:]
        for y in range(SIZE):
            for x in range(SIZE):
                if buf[y * SIZE + x] is not None:
                    continue
                acc, n = [0, 0, 0], 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < SIZE and 0 <= xx < SIZE:
                            v = buf[yy * SIZE + xx]
                            if v is not None:
                                acc[0] += v[0]; acc[1] += v[1]; acc[2] += v[2]
                                n += 1
                if n:
                    nxt[y * SIZE + x] = (acc[0] // n, acc[1] // n, acc[2] // n)
        buf = nxt
    return buf


def save_image(buf):
    def s2l(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    img = bpy.data.images.new("CP_Observer_Diffuse", width=SIZE, height=SIZE,
                              alpha=False)
    flat = []
    for v in buf:
        r, g, b = v if v is not None else (10, 10, 10)
        flat.extend((s2l(r), s2l(g), s2l(b), 1.0))
    img.pixels = flat
    os.makedirs(OUT_DIR, exist_ok=True)
    img.filepath_raw = os.path.join(OUT_DIR, "CP_Observer_Diffuse.png")
    img.file_format = 'PNG'
    img.save()
    return img


def consolidate(objects, img):
    # LAST STEP, and only now. Roblox imports a MeshPart with a single
    # TextureID, so multiple slots would be collapsed by the importer or split
    # the mesh. Doing this before painting is what destroys the zone data.
    m = bpy.data.materials.new("CP_Observer_Mat")
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = 'Closest'   # hard texels; bilinear is not a PS1 look
    tex.location = (-400, 300)
    nt.links.new(tex.outputs["Color"],
                 nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    for ob in objects:
        ob.data.materials.clear()
        ob.data.materials.append(m)
        for p in ob.data.polygons:
            p.material_index = 0


def export(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(OUT_DIR, "CP_Observer.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        # 1 Blender unit == 1 stud. Roblox's importer has its own scale control,
        # so ship 1:1 and adjust once on import rather than bake in a guess.
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_NONE',
        # Blender Z-up/-Y-forward -> Roblox Y-up/-Z-forward. These two lines are
        # the whole conversion, and why the figure is built facing -Y.
        axis_forward='-Z',
        axis_up='Y',
        object_types={'MESH'},
        use_mesh_modifiers=True,
        # FACE, not OFF: the flat shading IS the look. Exporting with smoothing
        # off lets the importer re-average normals and quietly undo it.
        mesh_smooth_type='FACE',
        use_triangles=True,
        path_mode='COPY',
        embed_textures=True,
        bake_space_transform=False,
    )
    return path


def main():
    global MATS
    wipe()
    MATS = zone_materials()

    body = build_body()
    paper = build_paper()
    objs = [body, paper]

    unwrap(objs)
    img = save_image(paint(objs))
    consolidate(objs, img)
    fbx = export(objs)

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    assert tris <= TRI_BUDGET, "over budget: %d > %d" % (tris, TRI_BUDGET)

    top = max((paper.matrix_world @ v.co).z for v in paper.data.vertices)
    print("CP_Observer built")
    print("  tris        %d / %d" % (tris, TRI_BUDGET))
    print("  verts       %d" % sum(len(o.data.vertices) for o in objs))
    print("  materials   %d (one, applied after painting)"
          % len(body.data.materials))
    print("  paper top   z=%.2f vs lens z=2.06 -> hides the face: %s"
          % (top, top > 2.46))
    print("  fbx         %s (%d bytes)" % (fbx, os.path.getsize(fbx)))


main()
