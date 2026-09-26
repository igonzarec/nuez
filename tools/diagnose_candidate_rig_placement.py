import bpy
from mathutils import Vector


candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
rig = bpy.data.objects.get("Nuez_Rig")
assert candidate and rig, "Missing candidate or rig"

points = [candidate.matrix_world @ Vector(corner) for corner in candidate.bound_box]
low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
print(f"CANDIDATE BOUNDS: min={tuple(round(v, 3) for v in low)}, max={tuple(round(v, 3) for v in high)}")
for bone in rig.data.bones:
    head = rig.matrix_world @ bone.head_local
    tail = rig.matrix_world @ bone.tail_local
    print(f"{bone.name}: head={tuple(round(v, 3) for v in head)} tail={tuple(round(v, 3) for v in tail)}")
