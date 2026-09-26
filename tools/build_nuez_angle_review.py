"""Build a comparison workspace without altering Nuez's model-space axes."""

import bpy
from math import radians
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_revision_angular.blend"


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_camera(collection, name, location, target):
    bpy.ops.object.camera_add(location=location)
    camera = bpy.context.object
    camera.name = name
    camera.data.lens = 58
    look_at(camera, target)
    for old in list(camera.users_collection):
        old.objects.unlink(camera)
    collection.objects.link(camera)
    return camera


rig = bpy.data.objects.get("Nuez_Rig")
assert rig and rig.type == "ARMATURE", "Missing Nuez_Rig"
tripo = next((obj for obj in bpy.context.scene.objects if obj.name.startswith("Tripo_Referencia_") and obj.type == "MESH"), None)
assert tripo, "Missing imported Tripo reference"

# Tripo's nose points along +X while Nuez's rest-facing axis is -Y. Rotate
# only the reference around its own origin; Nuez's rig and object axes remain
# untouched for future animation and Godot export.
bpy.ops.object.empty_add(type="PLAIN_AXES", location=tripo.location)
alignment = bpy.context.object
alignment.name = "Tripo_Orientacion_Front"
alignment.empty_display_size = 0.35
tripo_world = tripo.matrix_world.copy()
tripo.parent = alignment
tripo.matrix_parent_inverse = alignment.matrix_world.inverted()
tripo.matrix_world = tripo_world
alignment.rotation_euler.z = radians(-90)
alignment["reference_rotation_only"] = "Tripo +X mapped to Nuez -Y for front comparison"

# Persistent review cameras: front establishes proportions; profile catches
# hidden depth mistakes; three-quarter validates the intended game-facing view.
review = bpy.data.collections.get("Camaras de revision")
if review is None:
    review = bpy.data.collections.new("Camaras de revision")
    bpy.context.scene.collection.children.link(review)
target = (0.0, 0.0, 1.48)
front = add_camera(review, "Camara_Revision_Frontal", (0.0, -8.4, 2.0), target)
add_camera(review, "Camara_Revision_Perfil", (8.4, 0.0, 2.0), target)
three_quarter = add_camera(review, "Camara_Revision_TresCuartos", (-5.8, -6.6, 2.65), target)
bpy.context.scene.camera = three_quarter

# Make the high-density reference unselectable by accident in the viewport.
tripo.hide_select = True
for obj in bpy.context.selected_objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved angle-review workspace: {OUTPUT}")
