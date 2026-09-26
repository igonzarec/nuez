import bpy
from pathlib import Path

root=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
rig=bpy.data.objects['Nuez_Rig']
action=bpy.data.actions['Nuez_Prueba_Articulaciones']
rig.animation_data.action=action
if len(action.slots):rig.animation_data.action_slot=action.slots[0]
scene.camera=bpy.data.objects['Nuez_Vista_Referencia']
scene.render.resolution_x=640
scene.render.resolution_y=640
scene.render.resolution_percentage=100
scene.render.film_transparent=False
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.065,.055,1)
scene.frame_start=1
scene.frame_end=101
scene.render.fps=24
scene.render.filepath=str(root/'revision_nuez'/'prueba_articulaciones.mp4')
formats=[i.identifier for i in scene.render.image_settings.bl_rna.properties['file_format'].enum_items]
print('FORMATS',formats)
if 'FFMPEG' in formats:
    if hasattr(scene.render.image_settings,'media_type'):
        scene.render.image_settings.media_type='VIDEO'
    scene.render.image_settings.file_format='FFMPEG'
    scene.render.ffmpeg.format='MPEG4'
    scene.render.ffmpeg.codec='H264'
    scene.render.ffmpeg.constant_rate_factor='MEDIUM'
    bpy.ops.render.render(animation=True)
else:
    print('FFMPEG not exposed by this build; use the saved Blender action.')
