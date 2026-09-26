import bpy
from math import radians
from mathutils import Vector


candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
rig = bpy.data.objects.get("Nuez_Rig")
assert candidate and rig, "Missing candidate or rig"
depsgraph = bpy.context.evaluated_depsgraph_get()


def evaluated_positions():
    evaluated = candidate.evaluated_get(depsgraph)
    return [candidate.matrix_world @ vertex.co.copy() for vertex in evaluated.data.vertices]


for bone_name, axis in (("arm_left", "Y"), ("head", "X"), ("tail", "X")):
    rest = evaluated_positions()
    bone = rig.pose.bones[bone_name]
    bone.rotation_mode = "XYZ"
    if axis == "X":
        bone.rotation_euler.x = radians(20)
    else:
        bone.rotation_euler.y = radians(20)
    bpy.context.view_layer.update()
    posed = evaluated_positions()
    moved = [point for before, point in zip(rest, posed) if (point - before).length > 0.01]
    bone.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    low = Vector((min(p.x for p in moved), min(p.y for p in moved), min(p.z for p in moved)))
    high = Vector((max(p.x for p in moved), max(p.y for p in moved), max(p.z for p in moved)))
    print(f"{bone_name}: {len(moved)}/{len(rest)} vertices moved; bounds {tuple(round(v, 3) for v in low)} to {tuple(round(v, 3) for v in high)}")
