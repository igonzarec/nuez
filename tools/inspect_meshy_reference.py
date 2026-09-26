import bpy


sources = {
    "Tripo": r"C:\Users\USER\Downloads\normal pose tripo.glb",
    "Meshy": r"C:\Users\USER\Downloads\normal pose meshy.glb",
}

for label, source in sources.items():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=source)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    materials = {slot.material.name for obj in meshes for slot in obj.material_slots if slot.material}
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    bone_count = sum(len(armature.data.bones) for armature in armatures)
    print(f"{label}: {len(meshes)} mesh objects, {triangles} triangles, {len(materials)} materials, {len(armatures)} armatures, {bone_count} bones")
    for obj in meshes:
        print(f"  {obj.name}: {sum(len(poly.vertices) - 2 for poly in obj.data.polygons)} triangles")
