import bpy
from math import radians


rig = bpy.data.objects.get('Nuez_Rig')
assert rig and rig.type == 'ARMATURE', 'Missing original Nuez_Rig'
parts = [obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.name.startswith('Nuez_')]
assert parts, 'Missing modular Nuez parts'

depsgraph = bpy.context.evaluated_depsgraph_get()


def vertices(obj):
    evaluated = obj.evaluated_get(depsgraph)
    return [vertex.co.copy() for vertex in evaluated.data.vertices]


rest = {obj.name: vertices(obj) for obj in parts}
bone = rig.pose.bones['forearm_left']
bone.rotation_mode = 'XYZ'
bone.rotation_euler.y = radians(25)
bpy.context.view_layer.update()
moving = [
    obj.name for obj in parts
    if max((after - before).length for before, after in zip(rest[obj.name], vertices(obj))) > 0.005
]
bone.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()

allowed = {'Nuez_Antebrazo_left', 'Nuez_Mano_left'}
assert set(moving).issubset(allowed), f'Unexpected pieces moved with forearm: {set(moving) - allowed}'
assert set(moving) == allowed, f'Expected forearm and hand to move, got {moving}'
print('MODULAR RIG PASS: forearm pose moves only ' + ', '.join(moving))
