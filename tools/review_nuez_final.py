import bpy
import json
import math
import sys
from pathlib import Path
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'revision_nuez'
scene=bpy.context.scene
rig=bpy.data.objects['Nuez_Rig']
parts=[o for o in bpy.data.collections['01 Nuez — piezas editables'].objects if o.type=='MESH']
seams=json.loads(rig['Nuez_seams'])
result={'seam_max_gap':0,'weight_error':0,'poses':[], 'contact_failures':[], 'max_edge_ratio':0, 'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts)}
for o in parts:
    for v in o.data.vertices:
        result['weight_error']=max(result['weight_error'],abs(1-sum(g.weight for g in v.groups)))
assert result['weight_error']<1e-5

def activate(name):
    a=bpy.data.actions[name]
    rig.animation_data.action=a
    if len(a.slots):rig.animation_data.action_slot=a.slots[0]

def tree(name,coords):
    o=bpy.data.objects[name]
    return BVHTree.FromPolygons(coords[name],[list(p.vertices) for p in o.data.polygons])

def intersects(an,bn,coords,trees):
    a,b=trees[an],trees[bn]
    if a.overlap(b):return True
    # One object may lie inside the other rather than crossing its surface.
    for point in coords[an]:
        hit,normal,index,distance=b.find_nearest(point)
        if hit is not None and (point-hit).dot(normal)<-1e-6:return True
    return False

attachments=[('Nuez_Brazo_'+s,['Nuez_Cuerpo','Nuez_Pecho']) for s in ('left','right')]
attachments += [('Nuez_Pierna_'+s,['Nuez_Cuerpo']) for s in ('left','right')]
attachments += [('Nuez_ColaEspiral',['Nuez_Cuerpo']),('Nuez_ColaBase',['Nuez_ColaEspiral']),('Nuez_Cabeza',['Nuez_Pecho'])]
rest_edges={o.name:[(o.matrix_world@o.data.vertices[e.vertices[0]].co-o.matrix_world@o.data.vertices[e.vertices[1]].co).length for e in o.data.edges] for o in parts}

for name,frames in [('Nuez_Prueba_Articulaciones',[1,11,21,31,41,51,61,71,81,91,101]),('Nuez_Correr',[1,4,7,10,13,16,19,22,25]),('Nuez_Salto',[1,6,12,22,32,40,48])]:
    activate(name)
    for frame in frames:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get()
        coords={o.name:[o.matrix_world@v.co for v in o.evaluated_get(dg).data.vertices] for o in parts}
        for values in coords.values():
            assert all(math.isfinite(c) for p in values for c in p)
        trees={o.name:tree(o.name,coords) for o in parts}
        for an,candidates in attachments:
            if not any(intersects(an,bn,coords,trees) for bn in candidates):
                result['contact_failures'].append((name,frame,an,candidates))
        for o in parts:
            for edge,base in zip(o.data.edges,rest_edges[o.name]):
                if base>1e-5:
                    ratio=(coords[o.name][edge.vertices[0]]-coords[o.name][edge.vertices[1]]).length/base
                    if ratio>result['max_edge_ratio']:
                        result['max_edge_ratio']=ratio
                        result['max_edge_at']=[o.name,name,frame,edge.index,base]
        gap=0
        for an,ai,bn,bi,n in seams:
            gap=max(gap,max((coords[an][ai+j]-coords[bn][bi+j]).length for j in range(n)))
        result['seam_max_gap']=max(result['seam_max_gap'],gap)
        assert gap<1e-5,(name,frame,gap)
        result['poses'].append({'action':name,'frame':frame,'gap':gap})

snap=json.loads(rig['Nuez_bone_snapshot'])
now=[[b.name,list(b.head_local),list(b.tail_local),b.parent.name if b.parent else None] for b in rig.data.bones]
assert snap==now,'Skeleton changed'
result['skeleton_unchanged']=True
assert not result['contact_failures'],result['contact_failures']
assert all(all(b.lock_scale) and (b.name=='root' or all(b.lock_location)) for b in rig.pose.bones)
for o in parts:
    for slot in o.material_slots:
        if slot.material and slot.material.use_nodes:
            for node in slot.material.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image:
                    assert node.image.packed_file is not None,node.image.name
result['textures_packed']=True
result['pose_translation_locks']=True
print('VALIDATION',json.dumps(result))
(QA/'validacion.json').write_text(json.dumps(result,indent=2),encoding='utf-8')

if '--renders' in sys.argv:
    shots=[('referencia','Nuez_Vista_Referencia','Nuez_Prueba_Articulaciones',1),
           ('frente','Nuez_Vista_Frontal','Nuez_Prueba_Articulaciones',1),
           ('perfil','Nuez_Vista_Perfil','Nuez_Prueba_Articulaciones',1),
           ('codos','Nuez_Vista_Referencia','Nuez_Prueba_Articulaciones',21),
           ('brazos_arriba','Nuez_Vista_Referencia','Nuez_Prueba_Articulaciones',41),
           ('rodillas','Nuez_Vista_Referencia','Nuez_Prueba_Articulaciones',61),
           ('cabeza_cola','Nuez_Vista_Referencia','Nuez_Prueba_Articulaciones',81),
           ('correr','Nuez_Vista_Referencia','Nuez_Correr',7),
           ('salto','Nuez_Vista_Referencia','Nuez_Salto',32)]
    if '--quick' in sys.argv:shots=shots[:1]
    scene.render.resolution_x=800;scene.render.resolution_y=800
    for label,cam,action,frame in shots:
        activate(action)
        scene.frame_set(frame)
        scene.camera=bpy.data.objects[cam]
        scene.render.filepath=str(QA/(label+'.png'))
        bpy.ops.render.render(write_still=True)
        print('RENDERED',label,flush=True)
