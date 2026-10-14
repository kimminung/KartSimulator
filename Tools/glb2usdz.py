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
# 선택: 세 번째 인자로 클립 이름을 주면(예: animation.kart_idle) 그 클립의 **첫 프레임 자세를 정적으로** 굽는다(결정 65, 운전자 #63).
# Blender의 USD 변환 애니메이션(시간 샘플)은 RealityKit `availableAnimations`에 잡히지 않았고(클립 0개), RealityKit USDZ는
# 프림당 타임라인 하나뿐이라 7개 클립을 한 파일에 담지도 못한다. 지금은 착석 자세(kart_idle)만 필요하므로 자세를 굽고,
# 클립 재생이 필요해지면 UsdSkel 스키닝 경로(Reality Composer Pro 또는 usdcat)로 별도 작업한다.
clip_name = argv[2] if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

frame_start, frame_end = None, None
if clip_name:
    for obj in bpy.data.objects:
        ad = obj.animation_data
        if not ad:
            continue
        chosen = None
        for track in ad.nla_tracks:
            is_target = track.name == clip_name or any(s.action and s.action.name.startswith(clip_name) for s in track.strips)
            track.mute = not is_target
            if is_target and track.strips:
                chosen = track.strips[0]
        if chosen:
            ad.action = chosen.action
            frame_start = chosen.frame_start if frame_start is None else min(frame_start, chosen.frame_start)
            frame_end = chosen.frame_end if frame_end is None else max(frame_end, chosen.frame_end)
        elif ad.action and ad.action.name.startswith(clip_name):
            frame_start = ad.action.frame_range[0] if frame_start is None else min(frame_start, ad.action.frame_range[0])
            frame_end = ad.action.frame_range[1] if frame_end is None else max(frame_end, ad.action.frame_range[1])
    if frame_start is not None:
        bpy.context.scene.frame_start = int(frame_start)
        bpy.context.scene.frame_end = int(round(frame_end))
        bpy.context.scene.frame_set(int(frame_start))  # 이 프레임의 자세로 정적 내보내기
    print("CLIP", clip_name, "frames", bpy.context.scene.frame_start, bpy.context.scene.frame_end, "fps", bpy.context.scene.render.fps, "— 첫 프레임 자세를 정적으로 굽는다")

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
