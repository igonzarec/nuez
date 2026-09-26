import bpy
from mathutils import Vector


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_replicado_v2_preview.png"
scene.world.color = (0.045, 0.055, 0.075)

bpy.ops.object.camera_add(location=(3.9, -7.2, 3.1))
camera = bpy.context.object
look_at(camera, (0, 0.08, 1.55))
scene.camera = camera

for location, energy, size, color in (
    ((-3.5, -4.0, 5.5), 850, 4.0, (1.0, 0.72, 0.48)),
    ((3.0, -1.0, 4.0), 520, 3.0, (0.55, 0.72, 1.0)),
    ((0, 3.5, 3.0), 350, 3.0, (1.0, 0.42, 0.20)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color
    look_at(light, (0, 0.05, 1.45))

bpy.ops.render.render(write_still=True)
print(scene.render.filepath)
