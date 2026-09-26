import bpy


reference = bpy.data.objects.get("Referencia_Nuez")
assert reference is not None and reference.type == "EMPTY", "Referencia_Nuez is missing from nuez_base.blend"

output = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_artesania.blend"
bpy.ops.wm.save_as_mainfile(filepath=output)
print(f"Created art-direction working copy: {output}")
