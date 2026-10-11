"""glTF(.glb) 트랙 타일/카트 에셋을 RealityKit용 USDZ로 변환한다.
디자인이 Blockbench로 만들어 `Assets/export/glb/`에 내보낸 .glb를 받으면, 이 스크립트로
헤드리스 Blender를 돌려 Y-up/-Z-forward USDZ를 만든다(결정 37번 — 이 Mac의 Model I/O는
.glb import/.usdz export를 모두 지원하지 않아 Blender를 거친다).

사용법:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python Tools/glb2usdz.py -- <input.glb> <output.usdz>
"""
import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path, output_path = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

bpy.ops.wm.usd_export(
    filepath=output_path,
    export_materials=True,
    export_animation=False,
    # "PRESERVE"(기본값)는 임베드된 텍스처를 외부 상대경로로만 참조해 깨진다 — 새로 풀어서 같이 묶는다.
    export_textures_mode="NEW",
    convert_orientation=True,
    export_global_forward_selection="NEGATIVE_Z",
    export_global_up_selection="Y",
)
print("CONVERTED:", output_path)

for obj in bpy.data.objects:
    if obj.type == "MESH":
        dims = obj.dimensions
        print("DIMENSIONS", obj.name, dims.x, dims.y, dims.z)
