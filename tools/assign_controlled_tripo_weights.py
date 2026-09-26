"""Replace unreliable auto weights with simple, controllable anatomical regions."""

import bpy
from mathutils import Vector


OUTPUT = r"C:\Users\USER\Documents\Game Development\games\explorer squirrel\nuez_candidato_tripo_rig_v4_pesos.blend"


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def blend(first, second, amount):
    amount = clamp(amount)
    return [(first, 1.0 - amount), (second, amount)]


candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
rig = bpy.data.objects.get("Nuez_Rig")
assert candidate and rig, "Missing candidate or rig"
bone_names = [bone.name for bone in rig.data.bones]

# Build fresh groups. A low-poly character benefits from deliberate, readable
# skinning much more than from noisy automatic weights on a decimated surface.
candidate.vertex_groups.clear()
groups = {name: candidate.vertex_groups.new(name=name) for name in bone_names}

for vertex in candidate.data.vertices:
    point = candidate.matrix_world @ vertex.co
    x, y, z = point.x, point.y, point.z
    side = "left" if x < 0.0 else "right"
    absolute_x = abs(x)

    # The tail occupies the positive-Y rear volume. Its two bones blend over
    # the curl, rather than influencing belly or legs.
    if y > 0.27 and z > 0.62:
        entries = blend("tail", "tail_tip", (y - 0.42) / 0.88)

    # Head, with a short neck blend that preserves a gentle tilt.
    elif z > 1.86 and y < 0.12:
        entries = blend("spine", "head", (z - 1.82) / 0.18) if z < 2.02 else [("head", 1.0)]

    # Arms: only the outer, front-side volume may follow arm bones. The inner
    # shoulder blends back to spine, preventing the whole torso from moving.
    elif 0.96 < z < 1.92 and y < -0.32 and absolute_x > 0.40:
        shoulder = clamp((absolute_x - 0.43) / 0.18)
        if z >= 1.35:
            limb = blend("spine", f"arm_{side}", shoulder)
        elif z >= 1.13:
            limb = blend(f"arm_{side}", f"forearm_{side}", (1.35 - z) / 0.22)
        else:
            limb = [(f"forearm_{side}", 1.0)]
        entries = limb

    # Legs and feet stay in the front/lower body; rear points were handled as
    # tail first. Hips blend to root, then knee and foot take over downward.
    elif z < 0.98 and y < -0.30 and absolute_x > 0.10:
        if z >= 0.58:
            entries = blend("root", f"hip_{side}", (absolute_x - 0.12) / 0.23)
        elif z >= 0.27:
            entries = blend(f"hip_{side}", f"knee_{side}", (0.58 - z) / 0.31)
        elif z >= 0.12:
            entries = blend(f"knee_{side}", f"foot_{side}", (0.27 - z) / 0.15)
        else:
            entries = [(f"foot_{side}", 1.0)]

    # Remaining torso: pelvis is root, upper chest follows spine.
    else:
        entries = blend("root", "spine", (z - 0.92) / 0.55)

    total = sum(weight for _, weight in entries)
    for name, weight in entries:
        if weight > 0.0001:
            groups[name].add([vertex.index], weight / total, "REPLACE")

candidate["weighting"] = "Controlled anatomical regions v1"
candidate["weighting_notes"] = "Hand-tune shoulder, hip and tail transition after pose review"
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)
print(f"Saved controlled-weight candidate: {OUTPUT}")
