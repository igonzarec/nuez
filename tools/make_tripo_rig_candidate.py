"""Create a reversible low-poly Tripo candidate on Nuez's existing rig."""

import bpy
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_candidato_tripo_rig_v2.blend"
TARGET_TRIANGLES = 12000


def bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
        Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))),
    )


rig = bpy.data.objects.get("Nuez_Rig")
assert rig and rig.type == "ARMATURE", "Nuez_Rig is missing"
tripo = next((obj for obj in bpy.context.scene.objects if obj.name.startswith("Tripo_Referencia_") and obj.type == "MESH"), None)
assert tripo, "Tripo reference is missing"

# Preserve the old modular model as an in-file backup.  It is hidden, not
# deleted; users can restore it from the Outliner at any time.
for obj in bpy.context.scene.objects:
    if obj.type == "MESH" and obj.name.startswith("Nuez_"):
        obj.hide_viewport = True
        obj.hide_render = True

collection = bpy.data.collections.get("Candidato Tripo — rig limpio")
if collection is None:
    collection = bpy.data.collections.new("Candidato Tripo — rig limpio")
    bpy.context.scene.collection.children.link(collection)

# Make an independent mesh copy in Nuez's model space.  The reference itself
# remains high-density at the right side of the art workspace.
candidate = tripo.copy()
candidate.data = tripo.data.copy()
candidate.name = "Nuez_Candidato_Tripo_12k"
candidate.parent = None
candidate.matrix_world = tripo.matrix_world.copy()
candidate.hide_select = False
candidate.hide_viewport = False
collection.objects.link(candidate)

bpy.ops.object.select_all(action="DESELECT")
candidate.select_set(True)
bpy.context.view_layer.objects.active = candidate
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

low, high = bounds(candidate)
candidate.location += Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z))
bpy.context.view_layer.update()

initial_triangles = sum(len(face.vertices) - 2 for face in candidate.data.polygons)
decimate = candidate.modifiers.new("Low-poly silhouette", "DECIMATE")
decimate.decimate_type = "COLLAPSE"
decimate.ratio = min(1.0, TARGET_TRIANGLES / max(initial_triangles, 1))
bpy.context.view_layer.objects.active = candidate
bpy.ops.object.modifier_apply(modifier=decimate.name)
for polygon in candidate.data.polygons:
    polygon.use_smooth = False

# The current compact, symmetric rig is deliberately kept. Automatic weights
# are only a first functional pass; later adjustments can refine shoulders,
# hips and the large tail in Weight Paint.
bpy.ops.object.select_all(action="DESELECT")
candidate.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
result = bpy.ops.object.parent_set(type="ARMATURE_AUTO")
assert "FINISHED" in result and candidate.parent == rig, "Automatic armature binding did not complete"

triangles = sum(len(face.vertices) - 2 for face in candidate.data.polygons)
candidate["source"] = "Tripo high-density reference"
candidate["triangle_target"] = TARGET_TRIANGLES
candidate["triangle_count"] = triangles
candidate["needs_weight_polish"] = True
candidate.hide_viewport = False
candidate.hide_render = False

for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved {OUTPUT}; decimated {initial_triangles} -> {triangles} triangles")
