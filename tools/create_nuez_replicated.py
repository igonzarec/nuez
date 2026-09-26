"""Build an editable, low-poly Nuez inspired by the approved reference.

This deliberately writes a new .blend file.  nuez_base.blend is never modified.
The model remains modular so it is approachable in Blender, while the rig keeps
the bone names used by the Godot prototype.
"""

import bpy
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_replicado_v2.blend"


def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = 0.9
    return mat


FUR = make_material("Nuez fur", (0.48, 0.19, 0.055))
FUR_LIT = make_material("Nuez sunlit fur", (0.68, 0.30, 0.08))
FUR_DARK = make_material("Nuez paws and tail shade", (0.24, 0.075, 0.025))
CREAM = make_material("Nuez muzzle and belly", (0.91, 0.60, 0.31))
PINK = make_material("Nuez inner ears", (0.93, 0.36, 0.34))
BLACK = make_material("Nuez face", (0.018, 0.011, 0.008))


def link_to(collection, obj):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)


def ico(collection, name, location, scale, material, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    link_to(collection, obj)
    return obj


def cone_between(collection, name, start, end, radius_a, radius_b, material):
    start, end = Vector(start), Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(
        vertices=8,
        radius1=radius_b,
        radius2=radius_a,
        depth=direction.length,
        location=(start + end) / 2,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.data.materials.append(material)
    link_to(collection, obj)
    return obj


def bind(obj, rig, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Nuez armature", "ARMATURE")
    modifier.object = rig


def add_bone(edit_bones, name, head, tail, parent=None):
    bone = edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = edit_bones[parent]
    return bone


# Start from an empty scene. This script is run only in a background Blender
# process and saves to OUTPUT, so the user's open base file stays untouched.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

meshes = bpy.data.collections.new("Nuez — editable meshes")
bpy.context.scene.collection.children.link(meshes)
parts = {}

# A compact pear body with a much clearer head-to-body silhouette.
parts["root"] = ico(meshes, "Nuez_Cuerpo", (0, 0.02, 1.18), (0.59, 0.45, 0.76), FUR, 2)
parts["spine"] = ico(meshes, "Nuez_Pecho", (0, -0.03, 1.55), (0.54, 0.43, 0.48), FUR_LIT, 1)
parts["head"] = ico(meshes, "Nuez_Cabeza", (0, -0.03, 2.35), (0.75, 0.59, 0.66), FUR_LIT, 2)
parts["belly"] = ico(meshes, "Nuez_Panza", (0, -0.455, 1.22), (0.31, 0.070, 0.50), CREAM, 2)

# Two cheeks and a small chin produce the soft, continuous muzzle from the
# reference instead of a single block across the face.
parts["muzzle_left"] = ico(meshes, "Nuez_Mejilla_left", (-0.19, -0.58, 2.18), (0.29, 0.12, 0.22), CREAM, 1)
parts["muzzle_right"] = ico(meshes, "Nuez_Mejilla_right", (0.19, -0.58, 2.18), (0.29, 0.12, 0.22), CREAM, 1)
parts["muzzle"] = ico(meshes, "Nuez_Menton", (0, -0.57, 2.04), (0.20, 0.11, 0.14), CREAM, 1)

for side, x in (("left", -1), ("right", 1)):
    # Rounded ears sit closer to the head, with visible low-poly pink insets.
    parts[f"ear_{side}"] = ico(meshes, f"Nuez_Oreja_{side}", (x * 0.46, -0.03, 2.86), (0.22, 0.17, 0.25), FUR, 1)
    parts[f"ear_inner_{side}"] = ico(meshes, f"Nuez_InteriorOreja_{side}", (x * 0.46, -0.175, 2.86), (0.125, 0.03, 0.145), PINK, 1)
    parts[f"eye_{side}"] = ico(meshes, f"Nuez_Ojo_{side}", (x * 0.245, -0.575, 2.40), (0.072, 0.032, 0.112), BLACK, 1)

parts["nose"] = ico(meshes, "Nuez_Nariz", (0, -0.708, 2.21), (0.085, 0.052, 0.052), BLACK, 1)
# A low-poly three-stroke smile, kept as separate tiny dark segments so it is
# editable and never distorts the muzzle while it is animated.
parts["mouth_center"] = cone_between(meshes, "Nuez_Sonrisa_Centro", (0, -0.695, 2.155), (0, -0.700, 2.095), 0.018, 0.018, BLACK)
parts["mouth_left"] = cone_between(meshes, "Nuez_Sonrisa_left", (0, -0.700, 2.095), (-0.12, -0.685, 2.07), 0.016, 0.016, BLACK)
parts["mouth_right"] = cone_between(meshes, "Nuez_Sonrisa_right", (0, -0.700, 2.095), (0.12, -0.685, 2.07), 0.016, 0.016, BLACK)

# Arms are intentionally short, tapered cylinders with a small round paw.
# Their shoulder starts at the torso surface, avoiding an armpit spike.
for side, x in (("left", -1), ("right", 1)):
    parts[f"arm_{side}"] = cone_between(
        meshes, f"Nuez_Brazo_{side}", (x * 0.51, -0.015, 1.72), (x * 0.63, -0.10, 1.31), 0.135, 0.115, FUR
    )
    parts[f"forearm_{side}"] = cone_between(
        meshes, f"Nuez_Antebrazo_{side}", (x * 0.63, -0.10, 1.31), (x * 0.59, -0.17, 1.05), 0.105, 0.082, FUR_LIT
    )
    parts[f"paw_{side}"] = ico(meshes, f"Nuez_Mano_{side}", (x * 0.59, -0.18, 1.00), (0.105, 0.10, 0.095), FUR_DARK, 1)
    parts[f"hip_{side}"] = cone_between(
        meshes, f"Nuez_Pierna_{side}", (x * 0.22, 0, 0.84), (x * 0.22, -0.03, 0.38), 0.16, 0.135, FUR
    )
    parts[f"knee_{side}"] = cone_between(
        meshes, f"Nuez_Pantorrilla_{side}", (x * 0.22, -0.03, 0.38), (x * 0.22, -0.13, 0.16), 0.125, 0.105, FUR_LIT
    )
    parts[f"foot_{side}"] = ico(meshes, f"Nuez_Pie_{side}", (x * 0.22, -0.24, 0.105), (0.18, 0.23, 0.10), FUR_DARK, 1)

# A large, layered tail makes the silhouette read from a distance. The cream
# spiral inset is a simple low-poly disk rather than a dense painted texture.
parts["tail"] = ico(meshes, "Nuez_ColaBase", (-0.30, 0.38, 1.43), (0.52, 0.30, 0.64), FUR, 2)
parts["tail_tip"] = ico(meshes, "Nuez_ColaGrande", (-0.56, 0.56, 1.67), (0.68, 0.25, 0.74), FUR_LIT, 2)
parts["tail_spiral"] = ico(meshes, "Nuez_EspiralCola", (-0.65, 0.83, 1.70), (0.35, 0.035, 0.38), CREAM, 1)
parts["tail_spiral_inner"] = ico(meshes, "Nuez_EspiralColaCentro", (-0.57, 0.865, 1.68), (0.135, 0.025, 0.145), FUR_DARK, 1)

# Godot-compatible rig.  The familiar names preserve the existing animation
# vocabulary even though this is a separate prototype model.
rig_collection = bpy.data.collections.new("Nuez — rig")
bpy.context.scene.collection.children.link(rig_collection)
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
rig = bpy.context.object
rig.name, rig.data.name = "Nuez_Rig", "Nuez_RigData"
rig.show_in_front = True
link_to(rig_collection, rig)
eb = rig.data.edit_bones
eb.remove(eb[0])
add_bone(eb, "root", (0, 0, 0), (0, 0, 0.69))
add_bone(eb, "spine", (0, 0, 0.67), (0, 0, 1.86), "root")
add_bone(eb, "head", (0, 0, 1.84), (0, 0, 2.79), "spine")
add_bone(eb, "arm_left", (-0.43, 0, 1.72), (-0.63, -0.10, 1.31), "spine")
add_bone(eb, "forearm_left", (-0.63, -0.10, 1.31), (-0.59, -0.17, 1.00), "arm_left")
add_bone(eb, "arm_right", (0.43, 0, 1.72), (0.63, -0.10, 1.31), "spine")
add_bone(eb, "forearm_right", (0.63, -0.10, 1.31), (0.59, -0.17, 1.00), "arm_right")
add_bone(eb, "hip_left", (-0.22, 0, 0.84), (-0.22, -0.03, 0.38), "root")
add_bone(eb, "knee_left", (-0.22, -0.03, 0.38), (-0.22, -0.13, 0.16), "hip_left")
add_bone(eb, "foot_left", (-0.22, -0.13, 0.16), (-0.22, -0.35, 0.10), "knee_left")
add_bone(eb, "hip_right", (0.22, 0, 0.84), (0.22, -0.03, 0.38), "root")
add_bone(eb, "knee_right", (0.22, -0.03, 0.38), (0.22, -0.13, 0.16), "hip_right")
add_bone(eb, "foot_right", (0.22, -0.13, 0.16), (0.22, -0.35, 0.10), "knee_right")
add_bone(eb, "tail", (0, 0.27, 1.18), (0, 0.61, 1.53), "root")
add_bone(eb, "tail_tip", (0, 0.61, 1.53), (0, 0.93, 1.73), "tail")
bpy.ops.object.mode_set(mode="OBJECT")

for key, obj in parts.items():
    if key in {"root", "belly"}:
        bone = "root"
    elif key in {"spine"}:
        bone = "spine"
    elif key in {"head", "muzzle", "muzzle_left", "muzzle_right", "nose", "mouth_center", "mouth_left", "mouth_right"} or key.startswith("ear_") or key.startswith("eye_"):
        bone = "head"
    elif key == "tail":
        bone = "tail"
    elif key.startswith("tail_"):
        bone = "tail_tip"
    elif key.startswith("arm_left"):
        bone = "arm_left"
    elif key.startswith("forearm_left") or key.startswith("paw_left"):
        bone = "forearm_left"
    elif key.startswith("arm_right"):
        bone = "arm_right"
    elif key.startswith("forearm_right") or key.startswith("paw_right"):
        bone = "forearm_right"
    elif key.startswith("hip_left"):
        bone = "hip_left"
    elif key.startswith("knee_left"):
        bone = "knee_left"
    elif key.startswith("foot_left"):
        bone = "foot_left"
    elif key.startswith("hip_right"):
        bone = "hip_right"
    elif key.startswith("knee_right"):
        bone = "knee_right"
    else:
        bone = "foot_right"
    bind(obj, rig, bone)

# Leave the new file clean, readable, and ready for a beginner to inspect.
for obj in bpy.context.scene.objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved Nuez reference-inspired rig to {OUTPUT}")
