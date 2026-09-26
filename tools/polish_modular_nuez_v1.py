"""Conservative visual pass for the reliable modular Nuez rig.

This intentionally edits only coordinates of already-existing mesh vertices.
It does not add/delete meshes, touch armature bones, modify vertex groups, or
change parenting.  Each limb therefore keeps the rigid, reliable binding that
the original prototype used.
"""

import bpy


SOURCE = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_revision_angular.blend"
OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_modular_pulido_v1.blend"


def bounds(mesh):
    points = [vertex.co for vertex in mesh.vertices]
    return (
        min(point.x for point in points), max(point.x for point in points),
        min(point.y for point in points), max(point.y for point in points),
        min(point.z for point in points), max(point.z for point in points),
    )


def reshape_head(obj):
    """Slightly narrower forehead and fuller lower cheeks, without new topology."""
    _, _, _, _, low_z, high_z = bounds(obj.data)
    height = max(high_z - low_z, 0.001)
    for vertex in obj.data.vertices:
        t = (vertex.co.z - low_z) / height  # 0 chin, 1 crown
        # Wide friendly cheeks below the eye line; modestly narrow at crown.
        width = 1.055 - 0.115 * t
        vertex.co.x *= width
        # Keep the snout/front pleasantly broad but reduce the oversized crown.
        if t > 0.66:
            vertex.co.z = low_z + (vertex.co.z - low_z) * 0.955
    obj.data.update()


def reshape_body(obj):
    """Give the body a quiet pear silhouette: narrow shoulders, soft belly."""
    _, _, _, _, low_z, high_z = bounds(obj.data)
    height = max(high_z - low_z, 0.001)
    for vertex in obj.data.vertices:
        t = (vertex.co.z - low_z) / height
        # Lower third retains warmth/roundness; shoulder line becomes gentler.
        width = 1.035 - 0.13 * t
        vertex.co.x *= width
        vertex.co.y *= 1.025
    obj.data.update()


def scale_vertices(obj, x=1.0, y=1.0, z=1.0):
    for vertex in obj.data.vertices:
        vertex.co.x *= x
        vertex.co.y *= y
        vertex.co.z *= z
    obj.data.update()


# The supplied file is opened by Blender before this script runs.  Keep this
# assertion so the operation fails safely if a future source is wrong.
rig = bpy.data.objects.get("Nuez_Rig")
assert rig and rig.type == 'ARMATURE', "Expected the original modular Nuez rig"
original_bones = {bone.name for bone in rig.data.bones}

head = bpy.data.objects["Nuez_Cabeza"]
body = bpy.data.objects["Nuez_Cuerpo"]
reshape_head(head)
reshape_body(body)

# Existing low-poly pieces are kept intact: only their present vertices change.
for name in ("Nuez_Oreja_left", "Nuez_Oreja_right"):
    scale_vertices(bpy.data.objects[name], x=0.90, y=1.00, z=0.90)
for name in ("Nuez_InteriorOreja_left", "Nuez_InteriorOreja_right"):
    scale_vertices(bpy.data.objects[name], x=0.90, y=1.00, z=0.90)
scale_vertices(bpy.data.objects["Nuez_ColaBase"], x=1.11, y=1.04, z=1.08)
scale_vertices(bpy.data.objects["Nuez_ColaEspiral"], x=1.08, y=1.00, z=1.08)

# Sanity checks: topology and original rigid groups must be untouched.
assert {bone.name for bone in rig.data.bones} == original_bones
for obj in (item for item in bpy.data.objects if item.type == 'MESH' and item.name.startswith('Nuez_')):
    modifier = obj.modifiers.get("Nuez armature")
    assert modifier and modifier.object == rig, f"{obj.name} lost its armature binding"
    assert len(obj.vertex_groups) >= 1, f"{obj.name} lost its rigid weight group"

rig["modeling_note"] = "V1 visual polish changes existing vertices only; original modular rig and rigid weights preserved."
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved modular visual polish: {OUTPUT}")
