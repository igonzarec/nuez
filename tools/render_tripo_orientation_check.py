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
scene.render.filepath = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\tripo_orientation_check.png"
scene.world.color = (0.035, 0.045, 0.065)

tripo = next(obj for obj in scene.objects if obj.name.startswith("Tripo_Referencia_") and obj.type == "MESH")
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = obj != tripo
tripo.hide_render = False

bpy.ops.object.camera_add(location=(3.8, -7.5, 2.5))
camera = bpy.context.object
look_at(camera, (3.8, 0.0, 1.5))
scene.camera = camera

for location, energy, size in (((1.5, -4.0, 5.5), 1100, 4.0), ((6.0, -2.0, 3.0), 500, 3.0)):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy, light.data.shape, light.data.size = energy, "DISK", size
    look_at(light, (3.8, 0.0, 1.5))

bpy.ops.render.render(write_still=True)
print(scene.render.filepath)
