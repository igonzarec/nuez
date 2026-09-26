"""Reposition the compact Nuez rig inside the Tripo-based candidate mesh."""

import bpy


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_candidato_tripo_rig_v3.blend"


rig = bpy.data.objects.get("Nuez_Rig")
candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
assert rig and candidate, "Missing rig or candidate"

bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bones = rig.data.edit_bones


def place(name, head, tail):
    bones[name].head = head
    bones[name].tail = tail


# Tripo faces -Y. The body mass is centered around Y=-0.8, so the old rig at
# Y=0 sat behind the torso. These placements follow the measured body volume.
place("root", (0.0, -0.80, 0.06), (0.0, -0.80, 0.75))
place("spine", (0.0, -0.80, 0.70), (0.0, -0.80, 1.84))
place("head", (0.0, -0.84, 1.82), (0.0, -0.84, 2.82))

place("arm_left", (-0.43, -0.77, 1.72), (-0.62, -0.84, 1.31))
place("forearm_left", (-0.62, -0.84, 1.31), (-0.58, -0.91, 1.03))
place("arm_right", (0.43, -0.77, 1.72), (0.62, -0.84, 1.31))
place("forearm_right", (0.62, -0.84, 1.31), (0.58, -0.91, 1.03))

place("hip_left", (-0.23, -0.78, 0.84), (-0.23, -0.81, 0.39))
place("knee_left", (-0.23, -0.81, 0.39), (-0.23, -0.88, 0.16))
place("foot_left", (-0.23, -0.88, 0.16), (-0.23, -1.03, 0.11))
place("hip_right", (0.23, -0.78, 0.84), (0.23, -0.81, 0.39))
place("knee_right", (0.23, -0.81, 0.39), (0.23, -0.88, 0.16))
place("foot_right", (0.23, -0.88, 0.16), (0.23, -1.03, 0.11))

# The tail starts at the rear of the pelvis and tracks through the large curl.
place("tail", (0.0, -0.28, 1.18), (0.0, 0.60, 1.44))
place("tail_tip", (0.0, 0.60, 1.44), (0.0, 1.35, 1.68))

bpy.ops.object.mode_set(mode="OBJECT")
rig.show_in_front = False
rig["rig_placement"] = "Repositioned to Tripo body center Y=-0.8; tail follows rear curl"

# Cameras are useful in this art file but their wireframes distract from rig
# review, so keep them available in the Outliner while hidden in the viewport.
for obj in bpy.context.scene.objects:
    if obj.type == "CAMERA":
        obj.hide_viewport = True

bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved anatomically repositioned rig: {OUTPUT}")
