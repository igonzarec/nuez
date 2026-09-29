import bpy
from math import radians


rig = bpy.data.objects['Nuez_Rig']
print('rig pose_position:', rig.data.pose_position)
for name in ('Nuez_Antebrazo_left', 'Nuez_Mano_left', 'Nuez_Cuerpo'):
    obj = bpy.data.objects[name]
    modifier = obj.modifiers.get('Nuez armature')
    print(name, 'groups=', [g.name for g in obj.vertex_groups], 'modifier=', modifier.type if modifier else None,
          'show_viewport=', modifier.show_viewport if modifier else None,
          'preserve_volume=', getattr(modifier, 'use_deform_preserve_volume', None))

depsgraph = bpy.context.evaluated_depsgraph_get()
obj = bpy.data.objects['Nuez_Antebrazo_left']
bone = rig.pose.bones['forearm_left']
bone.rotation_mode = 'XYZ'
before = obj.evaluated_get(depsgraph).data.vertices[0].co.copy()
bone.rotation_euler.y = radians(25)
bpy.context.view_layer.update()
depsgraph.update()
after = obj.evaluated_get(depsgraph).data.vertices[0].co.copy()
print('first vertex local before=', tuple(round(v, 5) for v in before), 'after=', tuple(round(v, 5) for v in after), 'delta=', round((after-before).length, 5))
bone.rotation_euler = (0, 0, 0)
