"""Refine the existing modular Nuez, retaining its objects and exact skeleton.

Main forms reuse the original vertices. Joint pieces gain support rings with
identical bind coordinates/weights at their seams. No automatic weighting.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'nuez_modular_final.blend'
QA = ROOT / 'revision_nuez'
QA.mkdir(exist_ok=True)
rig = bpy.data.objects['Nuez_Rig']
bone_snapshot = [(b.name, tuple(b.head_local), tuple(b.tail_local), b.parent.name if b.parent else None) for b in rig.data.bones]
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data_clear()
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)

def collection(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c

body_collection = collection('01 Nuez — piezas editables')
rig_collection = collection('02 Nuez — esqueleto')
refs = collection('03 Referencias — ocultas')
studio = collection('04 Estudio — cámaras y luces')

def relink(o, c):
    for old in list(o.users_collection):
        old.objects.unlink(o)
    c.objects.link(o)

for o in list(bpy.context.scene.objects):
    if o == rig:
        relink(o, rig_collection)
    elif o.type == 'MESH' and o.name.startswith('Nuez_'):
        relink(o, body_collection)
        o.hide_set(False)
        o.hide_viewport = o.hide_render = False
    else:
        relink(o, refs)
        o.hide_render = True
# The high-density Tripo comparison remains in the source .blend. The deliverable
# needs only the packed artwork, so remove that hidden comparison from this copy.
for o in list(refs.objects):
    if o.type=='MESH':
        mesh=o.data
        bpy.data.objects.remove(o,do_unlink=True)
        if mesh.users==0:bpy.data.meshes.remove(mesh)
refs.hide_viewport = True
refs.hide_render = True

def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055)**2.4

def rgb(hexcode):
    return tuple(linear(int(hexcode[i:i+2],16)/255) for i in (0,2,4))

def srgb(hexcode):
    return tuple(int(hexcode[i:i+2],16)/255 for i in (0,2,4))

def mat(name, color):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*rgb(color), 1)
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = m.diffuse_color
    p.inputs['Roughness'].default_value = .86
    p.inputs['Specular IOR Level'].default_value = .18
    return m

fur = mat('Nuez | pelaje naranja', 'B95F29')
headfur = mat('Nuez | cabeza', 'BF6C30')
cream = mat('Nuez | crema', 'E4A768')
dark = mat('Nuez | patas', '67432B')
pink = mat('Nuez | orejas', 'D9826A')
black = mat('Nuez | ojos y sonrisa', '29221A')
tailmat = mat('Nuez | cola', 'B46029')

def assign_mat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.material_index = 0
        p.use_smooth = False

def weights(o, ws):
    o.vertex_groups.clear()
    groups = {}
    for i, entry in enumerate(ws):
        total = sum(entry.values())
        for name, value in entry.items():
            if value > 1e-8:
                if name not in groups:
                    groups[name] = o.vertex_groups.new(name=name)
                groups[name].add([i], value/total, 'REPLACE')
    mod = next((m for m in o.modifiers if m.type == 'ARMATURE'), None)
    if not mod:
        mod = o.modifiers.new('Nuez armature', 'ARMATURE')
    mod.object = rig
    mod.use_deform_preserve_volume = False  # Standard linear skinning, portable.
    mod.show_viewport = mod.show_render = True

def rigid(o, name):
    weights(o, [{name:1} for v in o.data.vertices])

def smooth(a, b, x):
    t = max(0, min(1, (x-a)/(b-a)))
    return t*t*(3-2*t)

def world_vertices(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]

def set_world(o, points):
    inv = o.matrix_world.inverted()
    assert len(points) == len(o.data.vertices)
    for v, p in zip(o.data.vertices, points):
        v.co = inv @ Vector(p)
    o.data.update()

def normalized_vertices(o):
    pts = world_vertices(o)
    lo = Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    center = (lo+hi)/2
    radius = (hi-lo)/2
    return [Vector(tuple((p[i]-center[i])/max(radius[i],.001) for i in range(3))) for p in pts]

def ellipsoid(o, center, radius):
    pts = normalized_vertices(o)
    set_world(o, [Vector(center) + Vector(tuple(v[i]*radius[i] for i in range(3))) for v in pts])

# Head silhouette: the original 42 vertices/80 faces, edited rather than replaced.
head = bpy.data.objects['Nuez_Cabeza']
hp = normalized_vertices(head)
new = []
for p in hp:
    x,y,z = p
    width = .78*(1.0 - .11*max(z,0) + .035*max(-z,0))
    zz=2.435+z*.665
    if zz>2.97:zz=2.97+(zz-2.97)*.30
    new.append((x*width, -.035 + y*.635 - .035*max(-z,0)*max(-y,0), zz))
set_world(head,new)
assign_mat(head,headfur)
rigid(head,'head')

# Existing torso becomes one visible pear-shaped outer shell. The chest remains
# as the neck transition inside that shell, not a stacked angular breastplate.
body = bpy.data.objects['Nuez_Cuerpo']
bp = normalized_vertices(body)
new = []
for x,y,z in bp:
    width = .585*(1-.20*max(z,0))
    new.append((x*width, y*.425-.018, 1.295+z*.77))
set_world(body,new)
assign_mat(body,fur)
def torso_weights(p):
    t = smooth(.83,1.74,p.z)
    return {'root':1-t,'spine':t}
weights(body,[torso_weights(p) for p in world_vertices(body)])
chest = bpy.data.objects['Nuez_Pecho']
ellipsoid(chest,(0,-.005,1.79),(.295,.285,.35))
assign_mat(chest,fur)
rigid(chest,'spine')

# Embedded old muzzle/belly retain their editable objects but no longer form
# protruding separate pads. The visible markings will be packed color textures.
for name, center, radius, bone, material in (
    ('Nuez_Hocico',(0,-.12,2.25),(.26,.13,.18),'head',headfur),
    ('Nuez_Panza',(0,-.10,1.27),(.30,.12,.40),'root',fur),
):
    o=bpy.data.objects[name]
    ellipsoid(o,center,radius)
    assign_mat(o,material)
    rigid(o,bone)
    o['nota']='Pieza original conservada dentro de la superficie exterior.'

# Packed albedo maps preserve the topology while giving the face its broad cream
# eye patches and belly its continuous marking. They export as regular textures.
def inside(x,z,poly):
    hit=False
    j=len(poly)-1
    for i in range(len(poly)):
        a,b=poly[i],poly[j]
        if (a[1]>z)!=(b[1]>z) and x < (b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:
            hit=not hit
        j=i
    return hit

def texture_material(o, m, name, axes, bounds, color_fn):
    size=512
    image=bpy.data.images.new(name,width=size,height=size,alpha=False)
    pixels=[]
    a0,a1,b0,b1=bounds
    for j in range(size):
        b=b0+(b1-b0)*j/(size-1)
        for i in range(size):
            a=a0+(a1-a0)*i/(size-1)
            c=color_fn(a,b)
            pixels.extend((*c,1))
    image.pixels.foreach_set(pixels)
    image.filepath_raw=str(QA/(name+'.png'))
    image.file_format='PNG'
    image.save()
    image.pack()
    newmat=m.copy()
    newmat.name=name
    nodes=newmat.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=image
    tex.interpolation='Linear'
    uvnode=nodes.new('ShaderNodeUVMap')
    uvnode.uv_map='NuezColor'
    newmat.node_tree.links.new(uvnode.outputs['UV'],tex.inputs['Vector'])
    newmat.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    o.data.materials.append(newmat)
    idx=len(o.data.materials)-1
    uv=o.data.uv_layers.get('NuezColor') or o.data.uv_layers.new(name='NuezColor')
    pts=world_vertices(o)
    for poly in o.data.polygons:
        front=sum(pts[v].y for v in poly.vertices)/len(poly.vertices)<-.04
        if axes==(1,2): front=True
        poly.material_index=idx if front else 0
        for li in poly.loop_indices:
            p=pts[o.data.loops[li].vertex_index]
            uv.data[li].uv=((p[axes[0]]-a0)/(a1-a0),(p[axes[1]]-b0)/(b1-b0))

patch=[(.065,2.30),(.115,2.66),(.235,2.78),(.43,2.765),(.59,2.62),(.66,2.40),(.65,2.15),(.39,1.91),(0,1.88)]
def facecolor(x,z):
    on=inside(abs(x),z,patch) or (z<2.295 and abs(x)<.60 and z>1.83)
    return srgb('E8AC6B' if on else 'BF6C30')
texture_material(head,headfur,'Nuez_cara_color',(0,2),(-.9,.9,1.65,3.18),facecolor)
def bellycolor(x,z):
    t=(z-1.22)/.73
    width=.33*max(0,1-t*t)**.55
    return srgb('E3A05F' if .60<z<1.97 and abs(x)<width else 'B95F29')
texture_material(body,fur,'Nuez_cuerpo_color',(0,2),(-.7,.7,.45,2.15),bellycolor)

# Ray-project eyes/mouth onto the existing faceted head, avoiding floating decals.
def bvh(o):
    return BVHTree.FromPolygons(world_vertices(o),[list(p.vertices) for p in o.data.polygons])
headtree=bvh(head)
def face_y(x,z):
    hit=headtree.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))
    assert hit[0] is not None,(x,z)
    return hit[0].y

for side,sgn in [('left',-1),('right',1)]:
    eye=bpy.data.objects['Nuez_Ojo_'+side]
    ep=normalized_vertices(eye)
    cx,cz=sgn*.305,2.53
    pts=[]
    for p in ep:
        x=cx+p.x*.069
        z=cz+p.z*.115
        pts.append((x,face_y(x,z)-.015+p.y*.020,z))
    set_world(eye,pts)
    assign_mat(eye,black)
    rigid(eye,'head')
    # Existing icosahedron ears rounded in their X/Z outline. Bone attachment
    # corrected from spine to head, without editing the skeleton itself.
    ear=bpy.data.objects['Nuez_Oreja_'+side]
    ep=normalized_vertices(ear)
    pts=[]
    for p in ep:
        r=math.hypot(p.x,p.z)
        x=p.x/max(r,.001)*.225 if r>.05 else 0
        z=p.z/max(r,.001)*.242 if r>.05 else 0
        pts.append((sgn*.505+x,-.002+p.y*.125,3.065+z))
    set_world(ear,pts)
    assign_mat(ear,fur)
    rigid(ear,'head')
    inner=bpy.data.objects['Nuez_InteriorOreja_'+side]
    ep=normalized_vertices(inner)
    pts=[]
    for p in ep:
        r=math.hypot(p.x,p.z)
        pts.append((sgn*.505+p.x/max(r,.001)*.155,-.112+p.y*.024,3.065+p.z/max(r,.001)*.17))
    set_world(inner,pts)
    assign_mat(inner,pink)
    rigid(inner,'head')

nose=bpy.data.objects['Nuez_Nariz']
np=normalized_vertices(nose)
pts=[]
for p in np:
    z=2.345+p.z*.075
    x=p.x*(.095+.068*p.z)
    pts.append((x,face_y(x,z)-.025+p.y*.037,z))
set_world(nose,pts)
assign_mat(nose,black)
rigid(nose,'head')

def replace_mesh(o, vertices, faces, ws, material):
    # Same object, same modifier/rig link. Extra loops only where articulation
    # needs them; original object names remain available for manual editing.
    mesh=bpy.data.meshes.new(o.name+'_articulado')
    inv=o.matrix_world.inverted()
    mesh.from_pydata([inv@Vector(v) for v in vertices],[],faces)
    mesh.update()
    o.data=mesh
    assign_mat(o,material)
    weights(o,ws)
    return o

def new_mesh(name,vertices,faces,ws,material):
    o=bpy.data.objects.new(name,bpy.data.meshes.new(name))
    body_collection.objects.link(o)
    return replace_mesh(o,vertices,faces,ws,material)

# A small bevel around the original ears replaces their pointed pentagonal
# outline with the rounded ten-sided silhouette in the art reference.
for side,sgn in [('left',-1),('right',1)]:
    for prefix,profiles,material in [
        ('Nuez_Oreja_',[(.185,-.112),(.218,-.072),(.218,.025),(.183,.088)],fur),
        ('Nuez_InteriorOreja_',[(.141,-.121),(.157,-.108)],pink),
    ]:
        verts=[];faces=[];n=10
        for radius,y in profiles:
            for j in range(n):
                angle=math.tau*j/n
                x=radius*math.cos(angle)
                z=radius*math.sin(angle)*1.08
                verts.append((sgn*.505+x,y,3.045+z))
        for i in range(len(profiles)-1):
            for j in range(n):
                faces.append((i*n+j,(i+1)*n+j,(i+1)*n+(j+1)%n,i*n+(j+1)%n))
        faces.extend([tuple(range(n)),tuple((len(profiles)-1)*n+j for j in reversed(range(n)))])
        replace_mesh(bpy.data.objects[prefix+side],verts,faces,[{'head':1} for _ in verts],material)

# Small polygonal smile follows the front facets. It is a rigid head detail.
def tube(points,radius,sides=6):
    points=[Vector(p) for p in points]
    vertices=[]
    faces=[]
    for i,p in enumerate(points):
        direction=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        u=Vector((0,-1,0))
        v=direction.cross(u).normalized()
        for j in range(sides):
            a=2*math.pi*j/sides
            vertices.append(p+radius*(u*math.cos(a)+v*math.sin(a)))
    for i in range(len(points)-1):
        for j in range(sides):
            faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
    return vertices,faces
for name,path in [('Centro',[(0,2.285),(0,2.205)]),('Sonrisa',[(-.22,2.225),(-.175,2.17),(-.09,2.178),(0,2.205),(.09,2.178),(.175,2.17),(.22,2.225)])]:
    points=[(x,face_y(x,z)-.016,z) for x,z in path]
    vs,fs=tube(points,.014)
    new_mesh('Nuez_Boca_'+name,vs,fs,[{'head':1} for _ in vs],black)

# Joint ring cross sections are shared numerically by adjacent objects. This
# gives separate editable parts a continuous surface under linear skinning.
seams=[]
def rings_part(name,rings,ws,sides,material,cap_start=False,cap_end=False):
    verts=[p for ring in rings for p in ring]
    weights_list=[w for w in ws for j in range(sides)]
    faces=[]
    for i in range(len(rings)-1):
        for j in range(sides):
            faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    if cap_start: faces.append(tuple(reversed(range(sides))))
    if cap_end: faces.append(tuple((len(rings)-1)*sides+j for j in range(sides)))
    o=bpy.data.objects[name]
    replace_mesh(o,verts,faces,weights_list,material)
    return o

def path_ring(center,direction,radius,sides=8,depth=1):
    d=Vector(direction).normalized()
    u=d.cross(Vector((0,1,0)))
    if u.length<.001:u=Vector((1,0,0))
    u.normalize()
    v=d.cross(u).normalized()
    return [Vector(center)+radius*(u*math.cos(2*math.pi*j/sides)+v*math.sin(2*math.pi*j/sides)*depth) for j in range(sides)]

for side,sgn in [('left',-1),('right',1)]:
    arm='arm_'+side; fore='forearm_'+side
    h=rig.data.bones[arm].head_local.copy()
    e=rig.data.bones[fore].head_local.copy()
    w=rig.data.bones[fore].tail_local.copy()
    d1=(e-h).normalized(); d2=(w-e).normalized(); joint=(d1+d2).normalized()
    # Start inside the shoulder. Keep a full round upper sleeve in spread poses.
    centers=[h-d1*.09,h-d1*.02,h+d1*.11,h.lerp(e,.52),e-d1*.085,e]
    radii=[.065,.162,.163,.145,.135,.131]
    rs=[path_ring(c,joint if i==5 else d1,r) for i,(c,r) in enumerate(zip(centers,radii))]
    ws=[{arm:1},{arm:1},{arm:1},{arm:1},{arm:.85,fore:.15},{arm:.5,fore:.5}]
    upper=rings_part('Nuez_Brazo_'+side,rs,ws,8,fur,True)
    # Seam duplicated intentionally: same positions and weights means zero gap.
    lower_rs=[rs[-1],path_ring(e+d2*.085,d2,.127),path_ring(e.lerp(w,.63),d2,.118),path_ring(w,d2,.107)]
    lower_ws=[ws[-1],{arm:.15,fore:.85},{fore:1},{fore:1}]
    lower=rings_part('Nuez_Antebrazo_'+side,lower_rs,lower_ws,8,fur)
    seams.append((upper.name,len(rs)*8-8,lower.name,0,8))
    paw_rs=[lower_rs[-1],path_ring(w+d2*.08,d2,.105),path_ring(w+d2*.15,d2,.073),path_ring(w+d2*.18,d2,.015)]
    paw=rings_part('Nuez_Mano_'+side,paw_rs,[{fore:1}]*4,8,dark,False,True)
    seams.append((lower.name,len(lower_rs)*8-8,paw.name,0,8))
    # Legs use the same shared-ring construction through the knee and ankle.
    hip='hip_'+side; knee='knee_'+side; foot='foot_'+side
    h=rig.data.bones[hip].head_local.copy()
    k=rig.data.bones[knee].head_local.copy()
    a=rig.data.bones[foot].head_local.copy()
    d1=(k-h).normalized(); d2=(a-k).normalized(); joint=(d1+d2).normalized()
    cs=[h-d1*.11,h,h+d1*.16,k-d1*.085,k]
    rs=[path_ring(c,joint if i==4 else d1,r,8,1.07) for i,(c,r) in enumerate(zip(cs,[.15,.205,.198,.173,.162]))]
    ws=[{'root':1},{'root':.45,hip:.55},{hip:1},{hip:.85,knee:.15},{hip:.5,knee:.5}]
    upper=rings_part('Nuez_Pierna_'+side,rs,ws,8,fur,True)
    lower_rs=[rs[-1],path_ring(k+d2*.065,d2,.155,8,1.07),path_ring(a,d2,.145,8,1.07)]
    lower_ws=[ws[-1],{hip:.15,knee:.85},{knee:.5,foot:.5}]
    lower=rings_part('Nuez_Pantorrilla_'+side,lower_rs,lower_ws,8,fur)
    seams.append((upper.name,len(rs)*8-8,lower.name,0,8))
    # Toe path turns forward with its upper ring locked to the ankle seam.
    bottom=Vector((sgn*.25,-.225,.095))
    toe=Vector((sgn*.25,-.35,.09))
    foot_rs=[lower_rs[-1],path_ring(bottom,Vector((0,-.4,-1)),.145,8,.60),path_ring(toe,Vector((0,-1,0)),.10,8,.65)]
    end=rings_part('Nuez_Pie_'+side,foot_rs,[lower_ws[-1],{foot:1},{foot:1}],8,dark,False,True)
    seams.append((lower.name,len(lower_rs)*8-8,end.name,0,8))

# Large curled tail reshapes the original ico; the original torus becomes its
# short curved connector. The curl is an albedo marking on both side surfaces.
tail=bpy.data.objects['Nuez_ColaBase']
tp=normalized_vertices(tail)
pts=[]
for x,y,z in tp:
    pts.append((x*.37*(.94+.06*z),1.37+y*.70-.23*max(-z,0)**2,1.50+z*.68))
set_world(tail,pts)
assign_mat(tail,tailmat)
def tailweights(p):
    t=smooth(.56,1.03,p.y)
    return {'tail':1-t,'tail_tip':t}
weights(tail,[tailweights(p) for p in world_vertices(tail)])
spiral=[]
for j in range(200):
    t=j/199
    theta=-1.8+t*math.pi*2.05
    r=.52*(1-t)+.065*t
    spiral.append((1.40+r*math.cos(theta),1.52+r*math.sin(theta)))
def tailcolor(y,z):
    dist=min((y-a)**2+(z-b)**2 for a,b in spiral)
    if dist<.036**2:return srgb('D49A52')
    if dist<.069**2:return srgb('87441F')
    return srgb('B46029')
texture_material(tail,tailmat,'Nuez_cola_color',(1,2),(.15,2.15,.65,2.35),tailcolor)
connector=bpy.data.objects['Nuez_ColaEspiral']
centers=[(0,.25,1.06),(0,.40,.94),(0,.65,.92),(0,.88,1.00),(0,1.07,1.14)]
points=[Vector(p) for p in centers]
rs=[]
for i,p in enumerate(points):
    d=points[min(i+1,len(points)-1)]-points[max(i-1,0)]
    # Tail cross section normal uses X as a stable depth axis.
    d.normalize(); u=Vector((1,0,0)); v=d.cross(u).normalized()
    r=[.12,.15,.18,.22,.25][i]
    rs.append([p+r*(u*math.cos(j*math.pi/4)+v*math.sin(j*math.pi/4)) for j in range(8)])
ws=[]
for p in points:
    t=smooth(.24,.48,p.y)
    tip=smooth(.56,1.03,p.y)
    ws.append({'root':1-t,'tail':t*(1-tip),'tail_tip':t*tip})
rings_part(connector.name,rs,ws,8,fur,True,True)

# Keep an explicit machine-readable seam specification for posed validation.
rig['Nuez_seams']=json.dumps(seams)
rig['Nuez_estructura']='15 huesos originales; piezas modulares; pesos manuales en las uniones.'
rig['Nuez_pruebas']='Acciones: Nuez_Correr, Nuez_Salto, Nuez_Prueba_Articulaciones.'
for pb in rig.pose.bones:
    pb.lock_location=(pb.name!='root',)*3
    pb.lock_scale=(True,True,True)
    pb['Uso']='Girar con R. La traslación está bloqueada para proteger la articulación.' if pb.name!='root' else 'Control general. G mueve todo el personaje.'
assert bone_snapshot == [(b.name, tuple(b.head_local), tuple(b.tail_local), b.parent.name if b.parent else None) for b in rig.data.bones]

# Deterministic pose examples provide something concrete to inspect in Blender.
def reset_pose():
    for pb in rig.pose.bones:
        pb.rotation_mode='QUATERNION'
        pb.rotation_quaternion=Quaternion()
        pb.location=(0,0,0)
        pb.scale=(1,1,1)

def rotate(name,axis,deg):
    pb=rig.pose.bones[name]
    q=rig.data.bones[name].matrix_local.to_quaternion()
    pb.rotation_quaternion=q.inverted() @ Quaternion(Vector(axis),math.radians(deg)) @ q

def key_pose(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
        pb.keyframe_insert('location',frame=frame,group=pb.name)

def action(name):
    a=bpy.data.actions.new(name)
    a.use_fake_user=True
    rig.animation_data_create()
    rig.animation_data.action=a
    return a

run=action('Nuez_Correr')
for frame in range(1,26,3):
    reset_pose()
    p=(frame-1)/24*math.tau
    for side,offset in [('left',0),('right',math.pi)]:
        s=math.sin(p+offset)
        rotate('arm_'+side,(1,0,0),-s*30)
        rotate('forearm_'+side,(1,0,0),-18-max(0,s)*20)
        rotate('hip_'+side,(1,0,0),s*26)
        rotate('knee_'+side,(1,0,0),max(0,-s)*38)
        rotate('foot_'+side,(1,0,0),-max(0,-s)*14)
    rotate('spine',(0,0,1),math.sin(p)*3)
    rotate('head',(0,0,1),-math.sin(p)*2)
    rotate('tail',(1,0,0),math.sin(p-.5)*5)
    rotate('tail_tip',(1,0,0),math.sin(p-.9)*7)
    rig.pose.bones['root'].location.z=abs(math.cos(p))*.035
    key_pose(frame)

jump=action('Nuez_Salto')
for frame,spread,elbow,knees,lift in [(1,0,0,0,0),(6,12,-25,28,-.05),(12,35,-28,35,.15),(22,85,-12,20,.18),(32,105,-20,12,.08),(40,5,-25,32,-.06),(48,0,0,0,0)]:
    reset_pose()
    for side,sgn in [('left',1),('right',-1)]:
        rotate('arm_'+side,(0,1,0),sgn*spread)
        rotate('forearm_'+side,(1,0,0),elbow)
        rotate('knee_'+side,(1,0,0),knees)
    rotate('tail',(1,0,0),-10 if frame<20 else 12)
    rig.pose.bones['root'].location.z=lift
    key_pose(frame)

test=action('Nuez_Prueba_Articulaciones')
poses=[('Reposo',{}),('Codos',{'forearm_left':((1,0,0),-100),'forearm_right':((1,0,0),-100)}),('Brazos_arriba',{'arm_left':((0,1,0),110),'arm_right':((0,1,0),-110)}),('Rodillas',{'hip_left':((1,0,0),-35),'hip_right':((1,0,0),-35),'knee_left':((1,0,0),90),'knee_right':((1,0,0),90)}),('Cabeza_y_cola',{'head':((0,0,1),35),'tail':((1,0,0),20),'tail_tip':((0,0,1),25)}),('Reposo',{})]
scene=bpy.context.scene
scene.timeline_markers.clear()
for i,(label,pose) in enumerate(poses):
    frame=1+i*20
    reset_pose()
    for name,(axis,deg) in pose.items():rotate(name,axis,deg)
    key_pose(frame)
    scene.timeline_markers.new(label,frame=frame)
rig.animation_data.action=test
scene.frame_start=1
scene.frame_end=101
scene.render.fps=24
scene.frame_set(1)
reset_pose()

# Warm but neutral, reproducible review lighting; orthographic camera comparable
# to the reference. The reference is packed in the file for side-by-side work.
reference=bpy.data.images.load(str(ROOT/'Nuez.png'),check_existing=True)
reference.pack()
for o in refs.objects:
    if o.type=='EMPTY' and o.name.startswith('Referencia'):
        o.data=reference
def look_at(o,target):
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def camera(name,location,target=(0,.22,1.64)):
    data=bpy.data.cameras.new(name)
    o=bpy.data.objects.new(name,data); studio.objects.link(o)
    o.location=location
    look_at(o,target)
    data.type='ORTHO';data.ortho_scale=4.05
    return o
cam=camera('Nuez_Vista_Referencia',(-5.8,-7.8,3.65))
camera('Nuez_Vista_Frontal',(0,-8,2.5),(0,.15,1.64))
camera('Nuez_Vista_Perfil',(-8,0,2.5),(0,.45,1.64))
scene.camera=cam
for name,loc,power,size in [('Principal',(-3,-4,6),450,4),('Relleno',(4,-2,4),220,5),('Contorno',(1,4,5),350,3)]:
    data=bpy.data.lights.new('Nuez_'+name,'AREA')
    o=bpy.data.objects.new('Nuez_'+name,data);studio.objects.link(o)
    o.location=loc;look_at(o,(0,0,1.5));data.energy=power;data.shape='DISK';data.size=size
world=bpy.data.worlds.new('Nuez_Estudio')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.world=world
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
rig.show_in_front=True
for o in bpy.context.selected_objects:o.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
# Open in a clean material view, close enough to see the real colors and face.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type='MATERIAL'
            space.overlay.show_floor=False
            space.overlay.show_axis_x=False;space.overlay.show_axis_y=False
            space.region_3d.view_distance=6.6
            space.region_3d.view_location=Vector((0,.18,1.6))
            space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            space.region_3d.view_perspective='ORTHO'
studio.hide_viewport=True
rig['Nuez_bone_snapshot']=json.dumps(bone_snapshot)
notes=bpy.data.texts.get('LEEME — Nuez') or bpy.data.texts.new('LEEME — Nuez')
notes.clear()
notes.write('''NUEZ MODULAR — REVISIÓN EN BLENDER

Espacio reproduce la prueba de articulaciones ya seleccionada.
Fotogramas: 1 reposo, 21 codos, 41 brazos arriba, 61 rodillas, 81 cabeza/cola, 101 reposo.
También hay acciones Nuez_Correr y Nuez_Salto en el Editor de acciones.

Para posar manualmente: detén la reproducción, ve al fotograma 1, selecciona
Nuez_Rig y cambia a Pose Mode. Selecciona un hueso y usa R para girarlo.
Las traslaciones/escalas individuales están bloqueadas deliberadamente:
G sirve sólo en root para desplazar todo el personaje. Alt+R limpia la rotación.
Al cambiar de fotograma, la acción de prueba vuelve a imponer su pose.
Para una animación propia, crea una acción nueva en el Editor de acciones.

01: piezas originales editables más dos trazos de la boca.
02: el esqueleto original de 15 huesos, sin cambios en sus posiciones/jerarquía.
03: referencias ocultas; Nuez.png y las texturas están empaquetadas.
04: estudio de presentación, oculto en la vista de trabajo.

Los anillos coincidentes de codo, muñeca, rodilla y tobillo tienen los mismos
pesos. Así las piezas siguen separadas para editarse, pero sus superficies
no se abren en las uniones. Se añadieron anillos de apoyo en estas zonas.
Hombros, caderas, cuello y raíz de cola utilizan volúmenes que se solapan.
Los pesos están asignados explícitamente, sin cálculo automático.

Las acciones son demostraciones de deformación, no animaciones finales del juego.
Este archivo está dedicado a Blender; no se ha modificado el proyecto Godot.
''')
bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('SAVED',OUT)
print('Meshes',len(body_collection.objects),'Triangles',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in body_collection.objects if o.type=='MESH'))
