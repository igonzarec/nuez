import bpy

candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
rig = bpy.data.objects.get("Nuez_Rig")
print(f"Candidate parent: {candidate.parent.name if candidate.parent else 'None'}")
print("Modifiers:", [(modifier.name, modifier.type, modifier.object.name if getattr(modifier, 'object', None) else None) for modifier in candidate.modifiers])
print("Groups:", [group.name for group in candidate.vertex_groups])
print(f"Rig mode: {rig.mode}; hidden: {rig.hide_viewport}")
