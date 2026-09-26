import bpy
from math import radians


candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
rig = bpy.data.objects.get("Nuez_Rig")
assert candidate and rig, "Candidate or rig missing"
modifier = next((item for item in candidate.modifiers if item.type == "ARMATURE" and item.object == rig), None)
assert modifier, "Candidate does not have the Nuez armature modifier"
required = {"root", "spine", "head", "arm_left", "forearm_left", "arm_right", "forearm_right", "tail", "tail_tip"}
groups = {group.name for group in candidate.vertex_groups}
assert required.issubset(groups), f"Missing expected weight groups: {required - groups}"

depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated = candidate.evaluated_get(depsgraph)
rest = [vertex.co.copy() for vertex in evaluated.data.vertices]
bone = rig.pose.bones["arm_left"]
bone.rotation_mode = "XYZ"
bone.rotation_euler.y = radians(22)
bpy.context.view_layer.update()
evaluated = candidate.evaluated_get(depsgraph)
posed = [vertex.co.copy() for vertex in evaluated.data.vertices]
movement = max((a - b).length for a, b in zip(rest, posed))
bone.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
assert movement > 0.02, f"Arm pose did not deform the mesh enough: {movement}"
triangles = sum(len(face.vertices) - 2 for face in candidate.data.polygons)
print(f"TRIPO CANDIDATE PASS: {triangles} triangles, {len(groups)} weight groups, arm deformation {movement:.3f}")
