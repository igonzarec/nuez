import bpy, os, sys, argparse
parser = argparse.ArgumentParser()
parser.add_argument('--ratio', type=float, default=0.35)
parser.add_argument('--minimum-triangles', type=int, default=40)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
out = os.path.join(root, 'tmp', 'tree_lods')
os.makedirs(out, exist_ok=True)
for n in range(1, 6):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=os.path.join(root, 'project', 'resources', 'nature', 'GLB', f'PineTree_{n}.glb'))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in meshes:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=0.00001)
        bpy.ops.mesh.separate(type='LOOSE')
        bpy.ops.object.mode_set(mode='OBJECT')
    parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    before = after = 0
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        obj.data.calc_loop_triangles()
        count = len(obj.data.loop_triangles)
        before += count
        if count > args.minimum_triangles:
            modifier = obj.modifiers.new('Far LOD', 'DECIMATE')
            modifier.ratio = min(1.0, max(0.05, args.ratio, args.minimum_triangles/count))
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        for polygon in obj.data.polygons: polygon.use_smooth = False
        obj.data.calc_loop_triangles()
        after += len(obj.data.loop_triangles)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = f'PineTree_{n}_Far'
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, f'PineTree_{n}_far.glb'), export_format='GLB', use_selection=True, export_materials='EXPORT')
    print(f'LOD BUILT PineTree_{n}: {before} -> {after} triangles, {len(parts)} components', flush=True)
