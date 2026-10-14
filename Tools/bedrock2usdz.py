"""Bedrock 엔티티 지오메트리(`*.geo.json`) → RealityKit USDZ 변환기 (결정 65, Issue #61 풍차).

Blockbench 없이 헤드리스 Blender로 Bedrock 큐브 모델을 읽는다. 본 계층은 빈 오브젝트(Empty)로, 큐브는 면별 UV(per-face
`uv`/`uv_size`, 또는 박스 UV `[u, v]`)를 가진 메시로 만든다. 본 이름을 그대로 두어 앱이 `sails`·`fantail` 같은 노드를 찾아
런타임에 돌릴 수 있다(Molang 애니메이션은 옮기지 않는다 — 각속도는 앱 코드에서).

좌표: Bedrock은 +X가 **왼쪽**, −Z가 앞, 16유닛 = 1 m. RealityKit(+X 오른쪽, −Z 앞)에 맞추려면 X를 뒤집어야 하는데, 텍스처가
거울상이 되지 않도록 여기서는 **Bedrock의 X를 그대로 두고 Y축 180° 회전**과 같은 결과가 되게 Z도 함께 뒤집는다
(x→−x, z→−z = Y축 180° 회전, 거울상 아님). 풍차처럼 정면이 중요하지 않은 소품에는 충분하고, 앞뒤가 중요하면 앱에서 yaw를 준다.
출력 단위는 **미터(1/16)**. 원본 client entity의 `scale: 2`는 굽지 않는다(앱에서 적용, 결정 65).

사용법:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python Tools/bedrock2usdz.py -- \
    <geo.json> <texture.png> <out.usdz> [render.png]
"""
import json
import math
import sys

import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
geo_path, tex_path, out_path = argv[0], argv[1], argv[2]
render_path = argv[3] if len(argv) > 3 else None

with open(geo_path, encoding="utf-8") as f:
    geo = json.load(f)["minecraft:geometry"][0]
TW, TH = geo["description"]["texture_width"], geo["description"]["texture_height"]
U = 1.0 / 16.0  # 유닛 → m


def bl(v):
    """Bedrock (x 왼쪽, y 위, z 뒤) → Blender(Z-up) 좌표. x→−x, z→−z 뒤에 Y-up→Z-up: (x, y, z) → (−x, z, y)."""
    return Vector((-v[0] * U, v[2] * U, v[1] * U))


bpy.ops.wm.read_factory_settings(use_empty=True)

# 재질: 픽셀 텍스처, 최근접 필터, 알파 컷
mat = bpy.data.materials.new("bedrock")
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get("Principled BSDF")
tex = nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(tex_path)
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value = 0.9
mat.blend_method = "CLIP" if hasattr(mat, "blend_method") else None

bones = {b["name"]: b for b in geo["bones"]}
empties = {}
for b in geo["bones"]:
    e = bpy.data.objects.new(b["name"], None)
    e.empty_display_size = 0.05
    bpy.context.scene.collection.objects.link(e)
    empties[b["name"]] = e
# 부모 연결 + 피벗(월드 위치) + 본 회전(Bedrock 도, X·Y 부호 뒤집힘 주의)
for b in geo["bones"]:
    e = empties[b["name"]]
    if b.get("parent"):
        e.parent = empties[b["parent"]]
    pivot = bl(b.get("pivot", [0, 0, 0]))
    rot = b.get("rotation", [0, 0, 0])
    # Bedrock 회전(도): X·Y는 부호 반대, Z 그대로(Blockbench ↔ glTF 관례). 우리 좌표 변환(x,z 뒤집기 + Z-up)에 맞춰
    # Blender 오일러(XYZ, 라디안)로 옮긴다: Bedrock X → Blender X(부호 반대), Bedrock Y → Blender Z(부호 반대), Bedrock Z → Blender Y
    eul = Euler((math.radians(-rot[0]), math.radians(rot[2]), math.radians(-rot[1])), "XYZ")
    e.matrix_world = Matrix.Translation(pivot) @ eul.to_matrix().to_4x4()

FACES = {  # 면 이름 → (법선, 꼭짓점 4개 인덱스 순서) ; 박스 꼭짓점은 (x0/x1, y0/y1, z0/z1) 조합
    "north": (0, 0, -1), "south": (0, 0, 1), "east": (1, 0, 0), "west": (-1, 0, 0), "up": (0, 1, 0), "down": (0, -1, 0),
}

verts_all, faces_all, uvs_all, face_owner = [], [], [], []
cube_index = 0
for b in geo["bones"]:
    parent = empties[b["name"]]
    for c in b.get("cubes", []):
        ox, oy, oz = c["origin"]
        sx, sy, sz = c["size"]
        inflate = c.get("inflate", 0)
        x0, y0, z0 = ox - inflate, oy - inflate, oz - inflate
        x1, y1, z1 = ox + sx + inflate, oy + sy + inflate, oz + sz + inflate
        # Bedrock 좌표 꼭짓점(뒤집기 전) — 면 UV를 Bedrock 규칙으로 매긴 뒤 변환 행렬로 옮긴다
        P = {
            (0, 0, 0): (x0, y0, z0), (1, 0, 0): (x1, y0, z0), (1, 1, 0): (x1, y1, z0), (0, 1, 0): (x0, y1, z0),
            (0, 0, 1): (x0, y0, z1), (1, 0, 1): (x1, y0, z1), (1, 1, 1): (x1, y1, z1), (0, 1, 1): (x0, y1, z1),
        }
        # 각 면의 꼭짓점을 "텍스처 왼쪽 위 → 오른쪽 위 → 오른쪽 아래 → 왼쪽 아래" 순으로. Bedrock에서 north(−Z)를 볼 때
        # 텍스처 왼쪽이 +X(모델의 왼쪽)이다(그래서 +X가 왼쪽). east 면은 +X 쪽에서 본 면.
        quads = {
            "north": [(1, 1, 0), (0, 1, 0), (0, 0, 0), (1, 0, 0)],
            "south": [(0, 1, 1), (1, 1, 1), (1, 0, 1), (0, 0, 1)],
            "east": [(1, 1, 1), (1, 1, 0), (1, 0, 0), (1, 0, 1)],
            "west": [(0, 1, 0), (0, 1, 1), (0, 0, 1), (0, 0, 0)],
            "up": [(1, 1, 1), (0, 1, 1), (0, 1, 0), (1, 1, 0)],
            "down": [(1, 0, 0), (0, 0, 0), (0, 0, 1), (1, 0, 1)],
        }
        uv = c.get("uv", [0, 0])
        if isinstance(uv, list):  # 박스 UV
            u, v = uv
            w, h, d = sx, sy, sz
            box = {
                "east": (u, v + d, d, h), "north": (u + d, v + d, w, h), "west": (u + d + w, v + d, d, h),
                "south": (u + d + w + d, v + d, w, h), "up": (u + d, v, w, d), "down": (u + d + w, v, w, d),
            }
            face_uv = {k: {"uv": [a, bb], "uv_size": [ww, hh]} for k, (a, bb, ww, hh) in box.items()}
        else:
            face_uv = uv
        # 큐브 자체 회전(피벗 기준)
        crot = c.get("rotation", [0, 0, 0])
        cpiv = c.get("pivot", [0, 0, 0])
        ceul = Euler((math.radians(-crot[0]), math.radians(crot[2]), math.radians(-crot[1])), "XYZ")
        cube_m = Matrix.Translation(bl(cpiv)) @ ceul.to_matrix().to_4x4() @ Matrix.Translation(-bl(cpiv))
        for name, corners in quads.items():
            fu = face_uv.get(name)
            if not fu or fu.get("uv_size", [1, 1])[0] == 0 or fu.get("uv_size", [1, 1])[1] == 0:
                continue
            if name in ("east", "west") and sx == 0:
                pass  # 두께 0 평면(깃발)도 그린다
            base = len(verts_all)
            for corner in corners:
                verts_all.append(cube_m @ bl(P[corner]))
            faces_all.append((base, base + 1, base + 2, base + 3))
            a, bb = fu["uv"]; ww, hh = fu["uv_size"]
            # 텍스처 좌표: Bedrock은 왼쪽 위 원점, Blender는 왼쪽 아래 원점
            uvq = [(a / TW, 1 - bb / TH), ((a + ww) / TW, 1 - bb / TH), ((a + ww) / TW, 1 - (bb + hh) / TH), (a / TW, 1 - (bb + hh) / TH)]
            if c.get("mirror"):
                uvq = [uvq[1], uvq[0], uvq[3], uvq[2]]
            uvs_all.append(uvq)
            face_owner.append(b["name"])
        cube_index += 1

# 본마다 메시 오브젝트 하나(본 Empty의 자식, 월드 좌표 그대로 → parent inverse로 보정)
by_bone = {}
for i, owner in enumerate(face_owner):
    by_bone.setdefault(owner, []).append(i)
for bone_name, idxs in by_bone.items():
    verts, faces, uvs = [], [], []
    for i in idxs:
        f = faces_all[i]
        base = len(verts)
        verts.extend(verts_all[j] for j in f)
        faces.append((base, base + 1, base + 2, base + 3))
        uvs.append(uvs_all[i])
    mesh = bpy.data.meshes.new(bone_name + "_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for pi, poly in enumerate(mesh.polygons):
        for k, li in enumerate(poly.loop_indices):
            layer.data[li].uv = uvs[pi][k]
        poly.use_smooth = False
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(bone_name + "_geo", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = empties[bone_name]
    obj.matrix_parent_inverse = empties[bone_name].matrix_world.inverted()
    # 법선 일관화 + 양면(두께 0 평면 대비)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
mat.use_backface_culling = False

print("BEDROCK", geo["description"]["identifier"], "bones", len(bones), "cubes", cube_index, "faces", len(faces_all))
bpy.ops.wm.usd_export(
    filepath=out_path, export_materials=True, export_animation=False, export_textures_mode="NEW",
    convert_orientation=True, export_global_forward_selection="NEGATIVE_Z", export_global_up_selection="Y",
)
print("CONVERTED:", out_path)

if render_path:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 800, 1000
    world = bpy.data.worlds.new("w"); scene.world = world; world.color = (0.2, 0.25, 0.3)
    zs = [v.z for v in verts_all]; h = max(zs)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam)
    cam.location = (h * 1.1, -h * 1.6, h * 0.7)
    direction = Vector((0, 0, h * 0.5)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    scene.camera = cam
    scene.render.filepath = render_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED:", render_path)
