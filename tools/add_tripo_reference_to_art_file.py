"""Create an art-direction file with the original Nuez rig plus Tripo reference."""

import bpy
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_artesania_con_tripo.blend"
SOURCE = r"C:\Users\USER\Downloads\normal pose tripo.glb"


def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


# Measure the modular Nuez already present in the file. The 2D image reference
# is an Empty, so it does not affect these bounds.
original_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name.startswith("Nuez_")]
original_min, original_max = world_bounds(original_meshes)
target_height = original_max.z - original_min.z

before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=SOURCE)
imported = [obj for obj in bpy.context.scene.objects if obj not in before]
imported_meshes = [obj for obj in imported if obj.type == "MESH"]
assert imported_meshes, "Tripo GLB did not import a mesh"

ref_collection = bpy.data.collections.new("Referencia Tripo — alta densidad")
bpy.context.scene.collection.children.link(ref_collection)
for obj in imported:
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    ref_collection.objects.link(obj)

reference_min, reference_max = world_bounds(imported_meshes)
reference_height = reference_max.z - reference_min.z
scale = target_height / reference_height
for obj in imported:
    obj.scale *= scale
bpy.context.view_layer.update()

# Put the dense reference on the right, at Nuez's scale and with feet on ground.
reference_min, reference_max = world_bounds(imported_meshes)
offset = Vector((3.8 - reference_min.x, 0.0 - reference_min.y, 0.0 - reference_min.z))
for obj in imported:
    obj.location += offset
    obj["reference_only"] = True
    obj.hide_render = True
    obj.name = "Tripo_Referencia_" + obj.name

# Keep the working model and its rig clearly identifiable in the Outliner.
rig = bpy.data.objects.get("Nuez_Rig")
assert rig and rig.type == "ARMATURE", "The original Nuez rig is missing"
rig["keep_for_final_character"] = True

for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved art comparison file: {OUTPUT}")
print(f"Scaled Tripo by {scale:.6f}; Nuez height {target_height:.3f}")
