import bpy
from mathutils import Vector


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_modular_pulido_v1_preview.png"
scene.world.color = (0.045, 0.045, 0.055)

# The review scene has comparison meshes. Render only the reliable modular Nuez.
for obj in scene.objects:
    if obj.type == 'MESH':
        obj.hide_render = not obj.name.startswith('Nuez_')
rig = bpy.data.objects.get('Nuez_Rig')
if rig:
    rig.hide_render = True

bpy.ops.object.light_add(type='AREA', location=(-3.7, -4.8, 5.8))
key = bpy.context.object
key.data.energy = 800
key.data.size = 4.0
look_at(key, (0, -0.1, 1.55))
bpy.ops.object.light_add(type='AREA', location=(3.8, -2.3, 3.7))
fill = bpy.context.object
fill.data.energy = 360
fill.data.size = 3.0
look_at(fill, (0, -0.1, 1.55))

bpy.ops.object.camera_add(location=(3.9, -7.1, 2.85))
camera = bpy.context.object
camera.data.lens = 58
look_at(camera, (0, -0.05, 1.55))
scene.camera = camera

bpy.ops.render.render(write_still=True)
print(scene.render.filepath)
