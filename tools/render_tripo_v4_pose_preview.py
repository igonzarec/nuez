import bpy
from math import radians
from mathutils import Vector


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_candidato_tripo_rig_v4_pose_preview.png"
scene.world.color = (0.055, 0.055, 0.07)

candidate = bpy.data.objects["Nuez_Candidato_Tripo_12k"]
rig = bpy.data.objects["Nuez_Rig"]
for obj in scene.objects:
    if obj.type == 'MESH':
        obj.hide_render = obj != candidate
candidate.hide_render = False
rig.hide_render = True

# A restrained exploration/jump test pose: only limbs and tail should move.
for name, axis, degrees in (
    ("arm_left", 'Y', 30), ("forearm_left", 'Y', -18),
    ("arm_right", 'Y', -30), ("forearm_right", 'Y', 18),
    ("tail", 'X', -16), ("tail_tip", 'X', -12),
):
    bone = rig.pose.bones[name]
    bone.rotation_mode = 'XYZ'
    setattr(bone.rotation_euler, axis.lower(), radians(degrees))

bpy.ops.object.light_add(type='AREA', location=(-3.5, -4.5, 6.0))
key = bpy.context.object
key.data.energy = 850
key.data.shape = 'DISK'
key.data.size = 4.0
look_at(key, (0, -0.7, 1.6))
bpy.ops.object.light_add(type='AREA', location=(4.0, -2.0, 3.2))
fill = bpy.context.object
fill.data.energy = 450
fill.data.size = 3.0
look_at(fill, (0, -0.7, 1.6))

bpy.ops.object.camera_add(location=(4.15, -7.0, 3.0))
camera = bpy.context.object
camera.data.lens = 58
look_at(camera, (0, -0.78, 1.5))
scene.camera = camera

bpy.context.view_layer.update()
bpy.ops.render.render(write_still=True)
print(scene.render.filepath)
