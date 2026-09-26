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
scene.render.filepath = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_candidato_tripo_rig_v2_preview.png"
scene.world.color = (0.035, 0.045, 0.065)

candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
assert candidate, "Candidate missing"
for obj in scene.objects:
    if obj.type == "MESH":
        obj.hide_render = obj != candidate
candidate.hide_render = False

bpy.ops.object.camera_add(location=(-3.9, -7.0, 2.8))
camera = bpy.context.object
look_at(camera, (0.0, 0.0, 1.5))
scene.camera = camera

for location, energy, size, color in (
    ((-3.5, -4.0, 5.4), 950, 4.0, (1.0, 0.72, 0.48)),
    ((3.2, -2.0, 3.2), 460, 3.0, (0.55, 0.72, 1.0)),
    ((0.0, 3.0, 3.0), 300, 3.0, (1.0, 0.38, 0.16)),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.data.energy, light.data.shape, light.data.size = energy, "DISK", size
    light.data.color = color
    look_at(light, (0.0, 0.0, 1.45))

bpy.ops.render.render(write_still=True)
print(scene.render.filepath)
