import bpy
from mathutils import Vector


candidate = bpy.data.objects.get("Nuez_Candidato_Tripo_12k")
assert candidate, "Candidate missing"
vertices = [candidate.matrix_world @ vertex.co for vertex in candidate.data.vertices]
for label, lower, upper in (
    ("feet", 0.00, 0.35),
    ("legs", 0.35, 0.90),
    ("belly", 0.90, 1.50),
    ("chest", 1.50, 1.95),
    ("head", 1.95, 2.70),
    ("ears", 2.70, 3.30),
):
    points = [point for point in vertices if lower <= point.z <= upper]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    print(f"{label}: min={tuple(round(v, 3) for v in low)} max={tuple(round(v, 3) for v in high)}")

# The positive-Y extension beyond the torso is the tail. This is useful for
# putting the two existing tail bones inside its base and curl.
tail = [point for point in vertices if point.y > 0.5 and 0.8 <= point.z <= 2.6]
low = Vector((min(p.x for p in tail), min(p.y for p in tail), min(p.z for p in tail)))
high = Vector((max(p.x for p in tail), max(p.y for p in tail), max(p.z for p in tail)))
print(f"tail region: min={tuple(round(v, 3) for v in low)} max={tuple(round(v, 3) for v in high)}")
