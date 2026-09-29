import bpy
from mathutils import Vector
for o in bpy.data.objects:
    if o.name.startswith('Nuez_') and o.type == 'MESH':
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = tuple(round(min(p[i] for p in pts), 3) for i in range(3))
        hi = tuple(round(max(p[i] for p in pts), 3) for i in range(3))
        print(o.name, len(pts), len(o.data.polygons), lo, hi, [(g.name) for g in o.vertex_groups])
rig = bpy.data.objects['Nuez_Rig']
for b in rig.data.bones:
    print('BONE', b.name, tuple(b.head_local), tuple(b.tail_local), b.parent.name if b.parent else None)
print('POSE', [(p.name, tuple(p.rotation_euler)) for p in rig.pose.bones])
