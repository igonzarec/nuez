import bpy
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_base.blend"


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
    return mat


FUR = material("Fur warm brown", (0.42, 0.16, 0.055))
FUR_LIGHT = material("Fur golden brown", (0.68, 0.29, 0.075))
BELLY = material("Belly cream", (0.92, 0.58, 0.27))
PINK = material("Inner ear pink", (0.95, 0.35, 0.30))
BLACK = material("Eyes and nose", (0.025, 0.012, 0.008))


def ico(name, location, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def cylinder_between(name, start, end, radius, mat):
    start, end = Vector(start), Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radius * 0.9, radius2=radius,
                                   depth=direction.length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    return obj


def assign_bone(obj, armature, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Nuez armature", "ARMATURE")
    modifier.object = armature


def add_bone(edit_bones, name, head, tail, parent=None):
    bone = edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    if parent:
        bone.parent = edit_bones[parent]
    return bone


# Start clean, but this script always creates a separate .blend file.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# Build a deliberately modular low-poly character. Separate meshes make the
# first Blender tweaks approachable: move a part without breaking the rest.
parts = {}
parts["root"] = ico("Nuez_Cuerpo", (0, 0, 1.25), (0.62, 0.48, 0.80), FUR, 2)
parts["spine"] = ico("Nuez_Pecho", (0, -0.02, 1.62), (0.57, 0.45, 0.55), FUR_LIGHT, 2)
parts["head"] = ico("Nuez_Cabeza", (0, -0.03, 2.42), (0.78, 0.62, 0.70), FUR_LIGHT, 2)
parts["belly"] = ico("Nuez_Panza", (0, -0.48, 1.27), (0.37, 0.08, 0.56), BELLY, 2)
parts["muzzle"] = ico("Nuez_Hocico", (0, -0.62, 2.25), (0.42, 0.12, 0.28), BELLY, 2)

for side, x in (("left", -1), ("right", 1)):
    parts[f"ear_{side}"] = ico(f"Nuez_Oreja_{side}", (x * 0.49, -0.02, 2.98), (0.27, 0.20, 0.29), FUR, 1)
    parts[f"ear_inner_{side}"] = ico(f"Nuez_InteriorOreja_{side}", (x * 0.49, -0.18, 2.98), (0.15, 0.05, 0.17), PINK, 1)
    parts[f"eye_{side}"] = ico(f"Nuez_Ojo_{side}", (x * 0.27, -0.60, 2.48), (0.09, 0.045, 0.13), BLACK, 2)

parts["nose"] = ico("Nuez_Nariz", (0, -0.74, 2.30), (0.09, 0.07, 0.06), BLACK, 1)

for side, x in (("left", -1), ("right", 1)):
    sx = x
    parts[f"arm_{side}"] = cylinder_between(f"Nuez_Brazo_{side}", (sx * 0.57, -0.02, 1.82), (sx * 0.67, -0.08, 1.34), 0.14, FUR)
    parts[f"forearm_{side}"] = cylinder_between(f"Nuez_Antebrazo_{side}", (sx * 0.67, -0.08, 1.34), (sx * 0.63, -0.16, 1.03), 0.12, FUR_LIGHT)
    parts[f"paw_{side}"] = ico(f"Nuez_Mano_{side}", (sx * 0.63, -0.17, 0.99), (0.13, 0.12, 0.10), FUR, 1)
    parts[f"hip_{side}"] = cylinder_between(f"Nuez_Pierna_{side}", (sx * 0.25, 0, 0.90), (sx * 0.25, -0.04, 0.38), 0.17, FUR)
    parts[f"knee_{side}"] = cylinder_between(f"Nuez_Pantorrilla_{side}", (sx * 0.25, -0.04, 0.38), (sx * 0.25, -0.12, 0.16), 0.14, FUR_LIGHT)
    parts[f"foot_{side}"] = ico(f"Nuez_Pie_{side}", (sx * 0.25, -0.22, 0.11), (0.19, 0.24, 0.11), FUR, 1)

# A chunky tail base plus an octagonal curl keep it unmistakably squirrel-like.
parts["tail"] = ico("Nuez_ColaBase", (0, 0.53, 1.46), (0.48, 0.30, 0.55), FUR, 2)
bpy.ops.mesh.primitive_torus_add(major_radius=0.40, minor_radius=0.11, major_segments=10, minor_segments=4,
                                 location=(0, 0.74, 1.63), rotation=(1.5708, 0, 0))
parts["tail_tip"] = bpy.context.object
parts["tail_tip"].name = "Nuez_ColaEspiral"
parts["tail_tip"].data.materials.append(FUR_LIGHT)

# Rig with the same names expected by the Godot prototype.
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
rig = bpy.context.object
rig.name = "Nuez_Rig"
rig.data.name = "Nuez_RigData"
rig.show_in_front = True
eb = rig.data.edit_bones
eb.remove(eb[0])
add_bone(eb, "root", (0, 0, 0), (0, 0, 0.75))
add_bone(eb, "spine", (0, 0, 0.70), (0, 0, 1.95), "root")
add_bone(eb, "head", (0, 0, 1.90), (0, 0, 2.85), "spine")
add_bone(eb, "arm_left", (-0.45, 0, 1.82), (-0.67, -0.08, 1.34), "spine")
add_bone(eb, "forearm_left", (-0.67, -0.08, 1.34), (-0.63, -0.16, 0.99), "arm_left")
add_bone(eb, "arm_right", (0.45, 0, 1.82), (0.67, -0.08, 1.34), "spine")
add_bone(eb, "forearm_right", (0.67, -0.08, 1.34), (0.63, -0.16, 0.99), "arm_right")
add_bone(eb, "hip_left", (-0.25, 0, 0.90), (-0.25, -0.04, 0.38), "root")
add_bone(eb, "knee_left", (-0.25, -0.04, 0.38), (-0.25, -0.12, 0.16), "hip_left")
add_bone(eb, "foot_left", (-0.25, -0.12, 0.16), (-0.25, -0.35, 0.11), "knee_left")
add_bone(eb, "hip_right", (0.25, 0, 0.90), (0.25, -0.04, 0.38), "root")
add_bone(eb, "knee_right", (0.25, -0.04, 0.38), (0.25, -0.12, 0.16), "hip_right")
add_bone(eb, "foot_right", (0.25, -0.12, 0.16), (0.25, -0.35, 0.11), "knee_right")
add_bone(eb, "tail", (0, 0.32, 1.25), (0, 0.78, 1.58), "root")
add_bone(eb, "tail_tip", (0, 0.78, 1.58), (0, 1.10, 1.72), "tail")
bpy.ops.object.mode_set(mode="OBJECT")

# Assign each modular surface to one named bone. This is intentionally simple
# and editable; Blender's Weight Paint can refine joins later.
for key, obj in parts.items():
    if key in {"root", "belly"}:
        bone = "root"
    elif key in {"spine", "muzzle", "nose"} or key.startswith("ear_"):
        bone = "spine"
    elif key == "head" or key.startswith("eye_") or key.startswith("ear_inner"):
        bone = "head"
    elif key == "tail":
        bone = "tail"
    elif key == "tail_tip":
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
    assign_bone(obj, rig, bone)

# Friendly scene organization for a first Blender edit session.
for obj in bpy.context.scene.objects:
    obj.select_set(False)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved editable Nuez base rig to {OUTPUT}")
