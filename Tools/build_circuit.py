"""서킷 JSON(스키마 2, `Tracks/circuit_XX.json`)의 3D 프레임을 따라 노면 메시를 만들어 USDZ로 내보내고,
확인용 렌더(PNG)를 찍는다 (결정 58). 디자인 타일 단면(`Design/tools/tiles.mjs`)과 같은 치수·팔레트를 쓴다:
노면 폭 3 m·두께 0.25 m, 가장자리 선 1유닛, 연석 4유닛(높이 1), 벽은 중심선 2.0~2.125 m·높이 0.5 m.

사용법:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python Tools/build_circuit.py -- Tracks/circuit_01.json KartSimulator/Resources/Tracks/circuit_01.usdz Docs/review/circuit_01
(마지막 인자는 렌더 PNG 접두사. `_top.png`·`_persp.png` 두 장을 만든다. 생략하면 렌더 안 함)
"""
import json
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
json_path, usdz_path = argv[0], argv[1]
render_prefix = argv[2] if len(argv) > 2 else None

UNIT = 0.0625  # 1 유닛 = 1/16 m (디자인 타일 격자)
PALETTE = {  # Design/style-guide.md 1-1
    "road": "15151A", "road_alt": "08090E", "edge_line": "F9C628", "curb": "6C6D67", "curb_alt": "EAECED",
    "rail": "A5A6AB", "grass": "546D33", "pillar": "6C6D67", "start_dark": "08090E", "start_light": "EAECED",
}


def hex_to_rgb(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    # sRGB → linear
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


def make_material(name, hex_color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_to_rgb(hex_color)
    bsdf.inputs["Roughness"].default_value = 0.9
    mat.diffuse_color = hex_to_rgb(hex_color)
    return mat


with open(json_path, encoding="utf-8") as f:
    track = json.load(f)
frames = track["frames"]
N = len(frames)

# 테마(컨셉) 팔레트 덮어쓰기 — `gen_circuit.py` THEMES: 공원 / 네온 나이트 / 사막 협곡
theme = track.get("theme", {})
for key_json, key_pal in (("ground", "grass"), ("wall", "rail"), ("wallPost", "wall_post"), ("curb", "curb"), ("curbAlt", "curb_alt"),
                          ("edgeLine", "edge_line"), ("road", "road"), ("roadAlt", "road_alt")):
    if key_json in theme:
        PALETTE[key_pal] = theme[key_json]
PALETTE.setdefault("wall_post", PALETTE["edge_line"])
PALETTE["pillar"] = PALETTE["rail"]
PALETTE["prop_a"] = {"trees": "3E7A3A", "lamps": "223A60", "rocks": "8C4A3A"}.get(theme.get("props", ""), "6C6D67")
PALETTE["prop_b"] = {"trees": "6B4A2B", "lamps": "00F6F9", "rocks": "A86A4A"}.get(theme.get("props", ""), "A5A6AB")


def to_blender(p):
    # RealityKit (x, y up, z) → Blender (x, −z, y up→Z)
    return Vector((p[0], -p[2], p[1]))


P = [to_blender(fr[0:3]) for fr in frames]
T = [to_blender(fr[3:6]) for fr in frames]
U = [to_blender(fr[6:9]) for fr in frames]
R = [t.cross(u).normalized() for t, u in zip(T, U)]  # tangent × up = right (RealityKit 관례와 같음)
S = [0.0]
for i in range(1, N):
    S.append(S[-1] + (P[i] - P[i - 1]).length)
S.append(S[-1] + (P[0] - P[-1]).length)
LENGTH = S[-1]

bpy.ops.wm.read_factory_settings(use_empty=True)
materials = {k: make_material(k, v) for k, v in PALETTE.items()}

verts, faces, face_mats = [], [], []


def add_quad(a, b, c, d, mat):
    base = len(verts)
    verts.extend([a, b, c, d])
    faces.append((base, base + 1, base + 2, base + 3))
    face_mats.append(mat)


def point(i, r, u):
    i %= N
    return P[i] + R[i] * r + U[i] * u


def sweep_box(r0, r1, u0, u1, mat_fn, top=True, bottom=True, sides=True, step_from=0, step_to=None):
    """단면 사각형 (r0..r1, u0..u1)을 프레임을 따라 쓸어 닫힌 튜브를 만든다. mat_fn(i) → 재질 이름."""
    step_to = N if step_to is None else step_to
    for i in range(step_from, step_to):
        j = i + 1
        m = mat_fn(i)
        a00, a10, a01, a11 = point(i, r0, u1), point(i, r1, u1), point(j, r0, u1), point(j, r1, u1)
        b00, b10, b01, b11 = point(i, r0, u0), point(i, r1, u0), point(j, r0, u0), point(j, r1, u0)
        if top:
            add_quad(a00, a10, a11, a01, m)
        if bottom:
            add_quad(b10, b00, b01, b11, m)
        if sides:
            add_quad(a10, b10, b11, a11, m)  # 오른쪽 면
            add_quad(b00, a00, a01, b01, m)  # 왼쪽 면


def stripe(i, period_m, a, b):
    return a if int(S[i] // period_m) % 2 == 0 else b


# 1. 노면 슬래브(두께 4유닛): 윗면은 road/road-alt 0.5 m 줄무늬(스타일 가이드 1-1), 옆·아래는 road.
sweep_box(-1.5, 1.5, -4 * UNIT, 0.0, lambda i: stripe(i, 0.5, "road", "road_alt"), sides=True)
# 2. 가장자리 선 1유닛(노면 위 얇게)
for sgn in (-1, 1):
    r_in, r_out = sorted((sgn * (1.5 - UNIT), sgn * 1.5))
    sweep_box(r_in, r_out, 0.0, 0.004, lambda i: "edge_line", bottom=False, sides=False)
# 3. 연석 4유닛 폭·1유닛 높이, 0.5 m마다 curb/흰색 교대
for sgn in (-1, 1):
    r_in, r_out = sorted((sgn * 1.5, sgn * 1.75))
    sweep_box(r_in, r_out, -4 * UNIT, UNIT, lambda i: stripe(i, 0.5, "curb", "curb_alt"))
# 4. 어깨(연석~벽) 잔디색 띠
for sgn in (-1, 1):
    r_in, r_out = sorted((sgn * 1.75, sgn * 2.0))
    sweep_box(r_in, r_out, -4 * UNIT, 0.0, lambda i: "grass")
# 5. 벽: 2유닛 두께, 높이 8유닛. 2 m마다 기둥(edge-line 노랑) 모양으로 색만 바꾼다.
for sgn in (-1, 1):
    r_in, r_out = sorted((sgn * 2.0, sgn * 2.125))
    sweep_box(r_in, r_out, -4 * UNIT, 8 * UNIT, lambda i: ("wall_post" if (S[i] % 2.0) < 0.25 else "rail"))

# 6. 출발선: 체커 2줄 × 12칸(0.25 m) — 출발 프레임 앞 0.5 m
start_i = track["start"]["pathIndex"]
for row in range(2):
    i = (start_i + row) % N
    for k in range(12):
        r0 = -1.5 + k * 0.25
        m = "start_light" if (k + row) % 2 == 0 else "start_dark"
        add_quad(point(i, r0, 0.005), point(i, r0 + 0.25, 0.005), point(i + 1, r0 + 0.25, 0.005), point(i, r0, 0.005) + (point(i + 1, r0, 0.005) - point(i, r0, 0.005)), m)

# 7. 기둥: 노면이 0.6 m 이상 떠 있는 곳에 4 m마다 (양쪽 r = ±1.0), 바닥(0)까지.
mesh_pillars = []
last_pillar_s = -10
for i in range(N):
    if P[i].z > 0.6 and S[i] - last_pillar_s >= 4.0 and U[i].z > 0.5:  # 루프(거꾸로)에는 기둥 없음
        last_pillar_s = S[i]
        for sgn in (-1, 1):
            c = P[i] + R[i] * (sgn * 1.0)
            top_z = c.z - 4 * UNIT
            half = 0.25
            z0 = -0.26
            x0, y0 = c.x - half, c.y - half
            x1, y1 = c.x + half, c.y + half
            b = [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)), Vector((x0, y1, z0))]
            t = [Vector((x0, y0, top_z)), Vector((x1, y0, top_z)), Vector((x1, y1, top_z)), Vector((x0, y1, top_z))]
            for k in range(4):
                add_quad(b[k], b[(k + 1) % 4], t[(k + 1) % 4], t[k], "pillar")

# 7b. 소품(테마별): 트랙에서 5 m 이상 떨어진 곳에 결정적 의사난수로 흩뿌린다. 나무(공원) / 가로등(네온) / 바위(협곡)
import random
rng = random.Random(len(frames))
xs_all = [p.x for p in P]; ys_all = [p.y for p in P]
px0, px1, py0, py1 = min(xs_all) - 5.5, max(xs_all) + 5.5, min(ys_all) - 5.5, max(ys_all) + 5.5
plan = [(p.x, p.y) for p in P]


def box(cx, cy, z0, sx, sy, h, mat):
    x0, x1, y0, y1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2
    b = [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)), Vector((x0, y1, z0))]
    t = [Vector((x0, y0, z0 + h)), Vector((x1, y0, z0 + h)), Vector((x1, y1, z0 + h)), Vector((x0, y1, z0 + h))]
    add_quad(t[0], t[1], t[2], t[3], mat)
    for k in range(4):
        add_quad(b[k], b[(k + 1) % 4], t[(k + 1) % 4], t[k], mat)


kind = theme.get("props", "")
placed = 0; tries = 0
while placed < 28 and tries < 4000:
    tries += 1
    cx, cy = rng.uniform(px0, px1), rng.uniform(py0, py1)
    if min(math.hypot(cx - a, cy - b) for a, b in plan) < 5.0:
        continue
    g = -4 * UNIT
    if kind == "trees":
        h = rng.uniform(1.6, 2.6)
        box(cx, cy, g, 0.4, 0.4, h * 0.45, "prop_b")                   # 줄기
        box(cx, cy, g + h * 0.45, 1.6, 1.6, h * 0.55, "prop_a")        # 잎(블록)
        box(cx, cy, g + h, 1.0, 1.0, 0.5, "prop_a")
    elif kind == "lamps":
        h = rng.uniform(3.0, 4.0)
        box(cx, cy, g, 0.25, 0.25, h, "prop_a")                         # 기둥
        box(cx, cy, g + h, 0.9, 0.9, 0.25, "prop_b")                    # 시안 등
    elif kind == "rocks":
        w = rng.uniform(1.2, 2.6)
        box(cx, cy, g, w, w * rng.uniform(0.6, 1.0), w * 0.6, "prop_a")
        box(cx + w * 0.3, cy - w * 0.2, g, w * 0.6, w * 0.5, w * 0.95, "prop_b")
    placed += 1

# 8. 잔디 바닥: 트랙 평면 바운딩 박스 + 6 m 여백, 두께 4유닛(윗면이 슬래브 아랫면과 같은 높이 −0.25 … 위로 0.01 겹침 방지)
xs = [p.x for p in P]; ys = [p.y for p in P]
mx0, mx1, my0, my1 = min(xs) - 6, max(xs) + 6, min(ys) - 6, max(ys) + 6
gz1, gz0 = -4 * UNIT - 0.002, -4 * UNIT - 0.25
g_b = [Vector((mx0, my0, gz0)), Vector((mx1, my0, gz0)), Vector((mx1, my1, gz0)), Vector((mx0, my1, gz0))]
g_t = [Vector((mx0, my0, gz1)), Vector((mx1, my0, gz1)), Vector((mx1, my1, gz1)), Vector((mx0, my1, gz1))]
add_quad(g_t[0], g_t[1], g_t[2], g_t[3], "grass")
add_quad(g_b[3], g_b[2], g_b[1], g_b[0], "grass")
for k in range(4):
    add_quad(g_b[k], g_b[(k + 1) % 4], g_t[(k + 1) % 4], g_t[k], "grass")

# ---- 메시 조립 -----------------------------------------------------------------------------------
mesh = bpy.data.meshes.new(track["id"])
mesh.from_pydata([tuple(v) for v in verts], [], faces)
mesh.update()
mat_index = {}
for name, mat in materials.items():
    mat_index[name] = len(mesh.materials)
    mesh.materials.append(mat)
for poly, m in zip(mesh.polygons, face_mats):
    poly.material_index = mat_index[m]
    poly.use_smooth = False
obj = bpy.data.objects.new(track["id"], mesh)
bpy.context.scene.collection.objects.link(obj)

# 법선 정리(이중 면 문제 방지): 닫힌 튜브라 일관되게 밖을 향하도록 재계산
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

print(f"MESH {track['id']}: verts {len(verts)} faces {len(faces)} length {LENGTH:.1f} m bbox x {min(xs):.1f}..{max(xs):.1f} y {min(ys):.1f}..{max(ys):.1f} z {min(p.z for p in P):.2f}..{max(p.z for p in P):.2f}")

# ---- USDZ 내보내기(Y-up / −Z-forward → RealityKit 좌표 그대로) -------------------------------------
bpy.ops.wm.usd_export(
    filepath=usdz_path, export_materials=True, export_animation=False, export_textures_mode="NEW",
    convert_orientation=True, export_global_forward_selection="NEGATIVE_Z", export_global_up_selection="Y",
    selected_objects_only=False,
)
print("CONVERTED:", usdz_path)

# ---- 확인 렌더 ------------------------------------------------------------------------------------
if render_prefix:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 960
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w"); scene.world = world
    world.color = (0.05, 0.07, 0.1)
    cx, cy = (mx0 + mx1) / 2, (my0 + my1) / 2
    span = max(mx1 - mx0, (my1 - my0) * 1280 / 960)

    cam_data = bpy.data.cameras.new("top"); cam_data.type = "ORTHO"; cam_data.ortho_scale = span * 1.02
    cam = bpy.data.objects.new("top", cam_data); scene.collection.objects.link(cam)
    cam.location = (cx, cy, 80); cam.rotation_euler = (0, 0, 0)
    scene.camera = cam
    scene.render.filepath = render_prefix + "_top.png"
    bpy.ops.render.render(write_still=True)

    cam2_data = bpy.data.cameras.new("persp"); cam2_data.lens = 35
    cam2 = bpy.data.objects.new("persp", cam2_data); scene.collection.objects.link(cam2)
    dist = span * 0.9
    cam2.location = (cx, cy - dist, dist * 0.75)
    direction = Vector((cx, cy, 1.0)) - cam2.location
    cam2.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam2
    scene.render.filepath = render_prefix + "_persp.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED:", render_prefix)
