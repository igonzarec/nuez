import bpy
import math
import os


# This scene is intentionally a rigid, modular rig: every handmade mesh is
# parented to one bone, so there is no automatic weighting to distort the
# low-poly pieces the artist modeled separately.

SOURCE_NAME = "nuez1.blend"
BLEND_NAME = "playertest2.blend"
GLB_RELATIVE = os.path.join("project", "assets", "playertest2", "playertest2.glb")


def remove_if_exists(name):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)


def ensure_collection(name):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    return collection


def make_bone(armature, name, head, tail, parent=None):
    bone = armature.data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    if parent:
        bone.parent = armature.data.edit_bones[parent]
        bone.use_connect = False
    return bone


def parent_to_bone(obj, armature, bone_name):
    # Keep each object's current world transform while attaching it rigidly.
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = 'BONE'
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = (armature.matrix_world @ armature.pose.bones[bone_name].matrix).inverted()
    obj.matrix_world = world


def key_rotation(pose_bone, frame, x=0.0, y=0.0, z=0.0):
    pose_bone.rotation_mode = 'XYZ'
    pose_bone.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
    pose_bone.keyframe_insert(data_path='rotation_euler', frame=frame)


def main():
    source = bpy.data.filepath
    root_dir = os.path.dirname(source)
    blend_path = os.path.join(root_dir, BLEND_NAME)
    glb_path = os.path.join(root_dir, GLB_RELATIVE)
    os.makedirs(os.path.dirname(glb_path), exist_ok=True)

    # Remove only objects created by an earlier run of this helper. The source
    # meshes stay completely untouched.
    remove_if_exists('NuezRig')
    for action in list(bpy.data.actions):
        if action.name in {'Run', 'Glide'}:
            bpy.data.actions.remove(action)

    rig_collection = ensure_collection('RIG_PLAYERTES2')
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    armature = bpy.context.object
    armature.name = 'NuezRig'
    armature.data.name = 'NuezRig'
    # Move the newly created object to our own collection.
    for c in list(armature.users_collection):
        c.objects.unlink(armature)
    rig_collection.objects.link(armature)
    armature.show_in_front = True

    # Blender creates one default bone. Replace it with the small hierarchy.
    default = armature.data.edit_bones[0]
    armature.data.edit_bones.remove(default)
    x = -1.273
    make_bone(armature, 'root', (x, 0, -0.72), (x, 0, -0.45))
    make_bone(armature, 'spine', (x, 0, -0.45), (x, 0, 0.13), 'root')
    make_bone(armature, 'head', (x, 0, 0.13), (x, 0, 0.76), 'spine')
    make_bone(armature, 'ear_left', (x - 0.13, 0, 0.70), (x - 0.34, 0, 1.03), 'head')
    make_bone(armature, 'ear_right', (x + 0.13, 0, 0.70), (x + 0.34, 0, 1.03), 'head')
    make_bone(armature, 'arm_left', (x - 0.22, 0, 0.18), (x - 0.38, 0, -0.23), 'spine')
    make_bone(armature, 'arm_right', (x + 0.22, 0, 0.18), (x + 0.38, 0, -0.23), 'spine')
    make_bone(armature, 'leg_left', (x - 0.16, 0, -0.35), (x - 0.19, 0, -0.73), 'root')
    make_bone(armature, 'leg_right', (x + 0.16, 0, -0.35), (x + 0.19, 0, -0.73), 'root')
    make_bone(armature, 'tail_base', (x, 0.05, -0.24), (x, 0.36, -0.06), 'root')
    make_bone(armature, 'tail_tip', (x, 0.36, -0.06), (x, 0.55, 0.08), 'tail_base')
    bpy.ops.object.mode_set(mode='OBJECT')

    # The tail was modeled by moving its mesh in Edit Mode, so its object
    # origin is far away even though its visible bounds are behind the body.
    # Rename it only in playertest2, leaving the user's source file intact.
    tail = bpy.data.objects.get('Icosphere.001')
    if tail:
        tail.name = 'nuez_cola'

    # Existing named pieces get a rigid parent. Nose and eyes follow the head.
    assignments = {
        'nuez_torso': 'spine',
        'nuez_cabeza': 'head',
        'nuez_ojo_izquierdo': 'head',
        'nuez_ojo_derecho': 'head',
        'Icosphere': 'head',
        'nuez_oreja_izquierda': 'ear_left',
        'nuez_oreja_derecha': 'ear_right',
        'nuez_brazo_izquierdo': 'arm_left',
        'nuez_brazo_derecho': 'arm_right',
        'nuez_pierna_izquierda': 'leg_left',
        'nuez_pierna_derecha': 'leg_right',
        'nuez_cola': 'tail_base',
    }
    for name, bone in assignments.items():
        obj = bpy.data.objects.get(name)
        if obj:
            parent_to_bone(obj, armature, bone)

    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    action = bpy.data.actions.new('Run')
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = 24
    armature.animation_data_create()
    armature.animation_data.action = action

    pb = armature.pose.bones
    # Frames 1 and 25 match, making the clip loop cleanly.
    for frame, phase in [(1, 1), (7, 0), (13, -1), (19, 0), (25, 1)]:
        # A low, bouncy body motion; rotations stay small to preserve the
        # sculpture-like low-poly silhouette.
        key_rotation(pb['root'], frame, x=3.0 if phase else -1.0)
        key_rotation(pb['spine'], frame, y=2.5 * phase, z=1.5 * phase)
        key_rotation(pb['head'], frame, y=-1.2 * phase, z=-0.8 * phase)
        key_rotation(pb['arm_left'], frame, x=-32.0 * phase, z=-8.0)
        key_rotation(pb['arm_right'], frame, x=32.0 * phase, z=8.0)
        key_rotation(pb['leg_left'], frame, x=27.0 * phase)
        key_rotation(pb['leg_right'], frame, x=-27.0 * phase)
        key_rotation(pb['tail_base'], frame, z=-10.0 * phase, x=2.0 * phase)
        key_rotation(pb['tail_tip'], frame, z=-4.0 * phase)
        key_rotation(pb['ear_left'], frame, x=-2.0 * phase)
        key_rotation(pb['ear_right'], frame, x=-2.0 * phase)
        root_bone = pb['root']
        root_bone.location = (0.0, 0.0, 0.018 if phase else 0.0)
        root_bone.keyframe_insert(data_path='location', frame=frame)

    # Blender 5.2 stores curves inside action layers; leave its default Bezier
    # interpolation intact rather than relying on Blender 4.x's action.fcurves.
    action['loop'] = True
    action['description'] = '24-frame in-place low-poly run cycle for playertest2.'

    # A second looping action for flight: arms and legs remain open, while the
    # small alternating motion reads as air passing over the squirrel.
    glide = bpy.data.actions.new('Glide')
    glide.use_frame_range = True
    glide.frame_start = 1
    glide.frame_end = 24
    armature.animation_data.action = glide
    for frame, flutter in [(1, 1.0), (7, -1.0), (13, 1.0), (19, -1.0), (25, 1.0)]:
        key_rotation(pb['root'], frame, x=-8.0)
        key_rotation(pb['spine'], frame, x=-7.0, y=flutter * 1.5)
        key_rotation(pb['head'], frame, x=5.0, y=flutter * 1.0)
        # Wide X silhouette: arms open high and legs open downwards.
        key_rotation(pb['arm_left'], frame, y=-82.0, x=flutter * 2.2)
        key_rotation(pb['arm_right'], frame, y=82.0, x=-flutter * 2.2)
        key_rotation(pb['leg_left'], frame, y=-42.0, x=flutter * 1.4)
        key_rotation(pb['leg_right'], frame, y=42.0, x=-flutter * 1.4)
        key_rotation(pb['tail_base'], frame, x=-9.0, z=flutter * 5.0)
        key_rotation(pb['tail_tip'], frame, z=flutter * 3.0)
        key_rotation(pb['ear_left'], frame, x=flutter * 1.2)
        key_rotation(pb['ear_right'], frame, x=-flutter * 1.2)
        pb['root'].location = (0.0, 0.0, flutter * 0.006)
        pb['root'].keyframe_insert(data_path='location', frame=frame)
    glide['loop'] = True
    glide['description'] = 'Open-limb gliding pose with a subtle wind flutter.'

    armature.animation_data.action = action
    bpy.ops.object.mode_set(mode='OBJECT')

    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 24
    scene.render.fps = 24
    scene.frame_set(1)

    # The handmade meshes were authored around X=-1.273 and their feet sit at
    # Z=-0.733. Put that point at this armature's object origin before export:
    # Godot can now turn the character around its feet instead of orbiting it.
    armature.location = (1.273, 0, 0.733)

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    # Export the visible rigged character and its Run action, not the reference
    # image Empty.
    bpy.ops.object.select_all(action='DESELECT')
    export_names = set(assignments.keys()) | {'NuezRig'}
    for name in export_names:
        obj = bpy.data.objects.get(name)
        if obj:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_force_sampling=True,
    )
    print('PLAYERTES2_BLEND=' + blend_path)
    print('PLAYERTES2_GLB=' + glb_path)


if __name__ == '__main__':
    main()
