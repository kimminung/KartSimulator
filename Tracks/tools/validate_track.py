#!/usr/bin/env python3
"""트랙 JSON이 테크 PRD 7장의 구조적 규칙을 지키는지 검사한다.

검사 항목:
  1. 타일이 단일 순환을 이루는지 (모든 타일이 정확히 이웃 2개, 전체가 하나로 연결)
  2. 모든 연결 변이 맞물리는지 (타일 rot의 개구부가 실제 이웃 위치와 일치)
  3. path가 닫혀 있고 자기 교차가 없는지
  4. start.pathIndex가 start 타일 중심과 일치하는지
  5. checkpoints가 3개 이상이고 오름차순인지
  6. 한 바퀴 길이(path 점 수)가 60~140 사이인지

하나라도 실패하면 0이 아닌 코드로 종료한다 (CI에서 PR을 막는 용도).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROT_TO_DIR = {0: "N", 90: "E", 180: "S", 270: "W"}
OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}
GRID_VECTOR = {"N": (0, 1), "S": (0, -1), "E": (1, 0), "W": (-1, 0)}
ROTATE_CW = {"N": "E", "E": "S", "S": "W", "W": "N"}


def _rotated(base: set[str], rot: int) -> set[str]:
    cur = set(base)
    for _ in range(rot // 90):
        cur = {ROTATE_CW[d] for d in cur}
    return cur


# 커브 rot=0 캐노니컬 개구부(고정): 입구 남쪽, 출구 동쪽 → {S, E}. gen_track.py와 동일한 정의.
ROT_TO_CURVE_OPENINGS = {r: _rotated({"S", "E"}, r) for r in (0, 90, 180, 270)}

MIN_LAP_LENGTH = 60
MAX_LAP_LENGTH = 140


class Check:
    def __init__(self, name: str):
        self.name = name
        self.ok = True
        self.messages: list[str] = []

    def fail(self, message: str) -> None:
        self.ok = False
        self.messages.append(message)


def opening_set(tile: dict) -> set[str]:
    if tile["type"] == "curve":
        return set(ROT_TO_CURVE_OPENINGS[tile["rot"]])
    d = ROT_TO_DIR[tile["rot"]]
    return {d, OPPOSITE[d]}


def check_single_cycle(tiles: list[dict]) -> Check:
    check = Check("단일 순환 + 연결 변 일치")
    by_pos = {(t["col"], t["row"]): t for t in tiles}
    if len(by_pos) != len(tiles):
        check.fail("같은 칸에 타일이 중복됩니다")
        return check

    adjacency: dict[tuple[int, int], set[tuple[int, int]]] = {pos: set() for pos in by_pos}
    for (col, row), tile in by_pos.items():
        openings = opening_set(tile)
        if len(openings) != 2:
            check.fail(f"({col},{row}) 개구부 개수가 2가 아닙니다: {openings}")
            continue
        for d in openings:
            dc, dr = GRID_VECTOR[d]
            neighbor = (col + dc, row + dr)
            if neighbor not in by_pos:
                check.fail(f"({col},{row})의 {d}쪽 이웃 {neighbor}이 타일 집합에 없습니다")
                continue
            neighbor_openings = opening_set(by_pos[neighbor])
            if OPPOSITE[d] not in neighbor_openings:
                check.fail(f"({col},{row})->{neighbor} 연결이 상대편과 맞물리지 않습니다")
                continue
            adjacency[(col, row)].add(neighbor)

    if not check.ok:
        return check

    for pos, neighbors in adjacency.items():
        if len(neighbors) != 2:
            check.fail(f"{pos}의 이웃 수가 2가 아닙니다: {len(neighbors)}")

    if not check.ok:
        return check

    start = tiles[0]["col"], tiles[0]["row"]
    visited = {start}
    frontier = [start]
    while frontier:
        current = frontier.pop()
        for nb in adjacency[current]:
            if nb not in visited:
                visited.add(nb)
                frontier.append(nb)

    if len(visited) != len(tiles):
        check.fail(f"하나의 순환으로 연결되지 않습니다 (연결된 타일 {len(visited)}/{len(tiles)})")

    return check


def segments_intersect(p1, p2, p3, p4) -> bool:
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    d1 = cross(p3, p4, p1)
    d2 = cross(p3, p4, p2)
    d3 = cross(p1, p2, p3)
    d4 = cross(p1, p2, p4)
    if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
        return True
    return False


def check_path(path: list[dict]) -> Check:
    check = Check("path 닫힘 + 자기교차 없음")
    n = len(path)
    if n < 4:
        check.fail("path 점이 너무 적습니다")
        return check

    points = [(p["x"], p["z"]) for p in path]
    seg_lengths = []
    for i in range(n):
        x0, z0 = points[i]
        x1, z1 = points[(i + 1) % n]
        seg_lengths.append(((x1 - x0) ** 2 + (z1 - z0) ** 2) ** 0.5)

    avg_len = sum(seg_lengths[:-1]) / max(1, n - 1)
    closing_len = seg_lengths[-1]
    if avg_len > 0 and not (avg_len * 0.25 <= closing_len <= avg_len * 2.5):
        check.fail(f"닫는 구간 길이가 비정상입니다 (평균 {avg_len:.2f}m, 닫는 구간 {closing_len:.2f}m)")

    segments = [(points[i], points[(i + 1) % n]) for i in range(n)]
    for i in range(len(segments)):
        for j in range(i + 1, len(segments)):
            if j == i or (j + 1) % n == i or (i + 1) % n == j:
                continue  # 인접한 구간은 끝점을 공유하므로 제외
            if segments_intersect(*segments[i], *segments[j]):
                check.fail(f"path 자기교차 발견 (구간 {i} x {j})")
                return check

    return check


def check_start(track: dict) -> Check:
    check = Check("출발선 위치 일치")
    start_tiles = [t for t in track["tiles"] if t["type"] == "start"]
    if len(start_tiles) != 1:
        check.fail(f"start 타일은 정확히 1개여야 합니다 (현재 {len(start_tiles)}개)")
        return check

    start_tile = start_tiles[0]
    tile_size = track["tileSize"]
    center_x = start_tile["col"] * tile_size + tile_size / 2
    center_z = -(start_tile["row"] * tile_size + tile_size / 2)

    path_index = track["start"]["pathIndex"]
    if not (0 <= path_index < len(track["path"])):
        check.fail("start.pathIndex가 path 범위를 벗어났습니다")
        return check

    point = track["path"][path_index]
    if abs(point["x"] - center_x) > 1e-2 or abs(point["z"] - center_z) > 1e-2:
        check.fail(
            f"start.pathIndex 위치({point})가 start 타일 중심({center_x},{center_z})과 다릅니다"
        )
    return check


def check_checkpoints(track: dict) -> Check:
    check = Check("체크포인트 개수/순서")
    checkpoints = track["checkpoints"]
    if len(checkpoints) < 3:
        check.fail(f"체크포인트가 3개 미만입니다 ({len(checkpoints)}개)")
    if checkpoints != sorted(checkpoints) or len(set(checkpoints)) != len(checkpoints):
        check.fail("체크포인트가 오름차순이 아니거나 중복이 있습니다")
    path_len = len(track["path"])
    for idx in checkpoints:
        if not (0 <= idx < path_len):
            check.fail(f"체크포인트 인덱스 {idx}가 path 범위를 벗어났습니다")
    return check


def check_lap_length(track: dict) -> Check:
    check = Check(f"한 바퀴 길이 {MIN_LAP_LENGTH}~{MAX_LAP_LENGTH}m")
    length = len(track["path"])
    if not (MIN_LAP_LENGTH <= length <= MAX_LAP_LENGTH):
        check.fail(f"path 점 수가 {length}개로 범위를 벗어났습니다")
    return check


def validate(track: dict) -> list[Check]:
    return [
        check_single_cycle(track["tiles"]),
        check_path(track["path"]),
        check_start(track),
        check_checkpoints(track),
        check_lap_length(track),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--in", dest="in_path", required=True, help="검사할 트랙 JSON 경로")
    args = parser.parse_args()

    track = json.loads(Path(args.in_path).read_text(encoding="utf-8"))
    checks = validate(track)

    all_ok = True
    for check in checks:
        status = "OK" if check.ok else "FAIL"
        print(f"[{status}] {check.name}")
        for message in check.messages:
            print(f"  - {message}")
        all_ok = all_ok and check.ok

    if all_ok:
        print("모든 검사를 통과했습니다.")
        return 0
    print("검증 실패.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
