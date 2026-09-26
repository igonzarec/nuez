import bpy

required = {
    "root", "spine", "head", "arm_left", "forearm_left", "arm_right", "forearm_right",
    "hip_left", "knee_left", "foot_left", "hip_right", "knee_right", "foot_right", "tail", "tail_tip",
}
rig = bpy.data.objects.get("Nuez_Rig")
assert rig and rig.type == "ARMATURE", "Missing Nuez_Rig armature"
bones = {bone.name for bone in rig.data.bones}
assert required == bones, f"Rig mismatch: {required ^ bones}"
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
assert len(meshes) >= 18, f"Expected modular model parts, got {len(meshes)}"
for obj in meshes:
    assert obj.modifiers.get("Nuez armature"), f"{obj.name} is not rigged"
print(f"NUEZ BASE PASS: {len(meshes)} editable mesh parts, {len(bones)} rig bones")
