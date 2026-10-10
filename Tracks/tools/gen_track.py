#!/usr/bin/env python3
"""트랙 격자/중심선/체크포인트 JSON을 생성한다 (테크 PRD 7장).

단순 사각 루프를 기본으로 하고, 변의 일부를 바깥으로 밀어내는 "노치"를 추가해
복잡도를 올린다. 노치 1개를 넣으면 새 코너 2개(노치 양 끝)뿐 아니라 노치 양옆의
기존 직선 타일 2개도 커브로 바뀐다(진입/진출 방향이 꺾이므로) — 즉 노치 1개당
커브 +4. 그래서 "커브 개수"가 아니라 "노치 개수"로 난이도를 조절한다. 테크 PRD
7장의 "easy 4개/normal 6개/hard 8개 이상"은 대략적 가이드였고, 이 구현에서는
easy=4(노치 0), normal=8(노치 1), hard=12(노치 2)로 나온다 — hard의 "8개 이상"은
만족하지만 normal은 6이 아니라 8이 된다. 자세한 내용은 Docs/decisions.md 참고.

사용법:
    python3 gen_track.py --seed 20261010 --cols 8 --rows 6 --difficulty easy \
        --id track_01 --name "첫 바퀴" --out ../track_01.json

주의: `tiles`/`path`는 항상 이 스크립트로 생성한다. 수기 편집 금지(테크 PRD 7장).
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

DIFFICULTY_NOTCHES = {"easy": 0, "normal": 1, "hard": 2}

# 그리드 방향 벡터. 좌표계는 테크 PRD 7장 공식: center = (col*tileSize+half, 0, -(row*tileSize+half)).
# row가 커질수록 world -Z(PRD의 "북")로 이동하므로 row+1 = N, row-1 = S.
GRID_VECTOR = {"N": (0, 1), "S": (0, -1), "E": (1, 0), "W": (-1, 0)}
OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}

ROTATE_CW = {"N": "E", "E": "S", "S": "W", "W": "N"}


def _rotated(base: set[str], rot: int) -> set[str]:
    cur = set(base)
    for _ in range(rot // 90):
        cur = {ROTATE_CW[d] for d in cur}
    return cur


# 커브 타일 rot=0 캐노니컬 개구부(고정, 진행 방향과 무관): 입구 남쪽, 출구 동쪽 → {S, E}.
# (디자인 PRD 5장 / 테크 PRD 7장). 다른 rot은 이 집합을 시계 방향으로 돌려서 얻는다.
CURVE_OPENINGS_TO_ROT = {frozenset(_rotated({"S", "E"}, r)): r for r in (0, 90, 180, 270)}
# 직선 타일 rot=0 캐노니컬: 입구 남 → 출구 북, 즉 진행 방향 N. (개구부는 180도 대칭이라 rot 0/180,
# 90/270이 구조적으로는 같은 이웃을 연결한다 — 여기서는 생성 시 "진행 방향"을 그대로 rot으로 쓴다.)
STRAIGHT_ROT = {"N": 0, "E": 90, "S": 180, "W": 270}
# heading(rad): 0 = -Z(N). KartMotionState의 forward = (-sin(h), 0, -cos(h))와 일치.
HEADING_FOR_DIR = {"N": 0.0, "W": math.pi / 2, "S": math.pi, "E": 3 * math.pi / 2}


def build_rectangle(cols: int, rows: int, margin: int = 1) -> list[tuple[int, int]]:
    """그리드 중앙에 꽉 차는 사각 루프의 (col,row) 리스트를 반시계 방향으로 반환한다."""
    c0, c1 = margin, cols - 1 - margin
    r0, r1 = margin, rows - 1 - margin
    if c1 <= c0 or r1 <= r0:
        raise ValueError("그리드가 너무 작습니다 (cols, rows 모두 4 이상 필요)")

    cells: list[tuple[int, int]] = []
    for c in range(c0, c1 + 1):
        cells.append((c, r0))
    for r in range(r0 + 1, r1 + 1):
        cells.append((c1, r))
    for c in range(c1 - 1, c0 - 1, -1):
        cells.append((c, r1))
    for r in range(r1 - 1, r0, -1):
        cells.append((c0, r))
    return cells


def neighbors4(cell: tuple[int, int]) -> list[tuple[int, int]]:
    c, r = cell
    return [(c + dc, r + dr) for dc, dr in GRID_VECTOR.values()]


def try_add_notch(
    cells: list[tuple[int, int]], cols: int, rows: int, rng: random.Random
) -> list[tuple[int, int]] | None:
    """변의 내부 구간을 바깥으로 밀어내고, 양 끝에 연결용 코너 셀을 끼워 넣어 코너 2개를 추가한다.

    `before`/`after`(구간 양옆의 고정 셀)는 제자리에 두고, 그 사이를 새 코너 2개 + 밀어낸
    구간으로 잇는다. 예(가로 구간, 바깥쪽이 +row): before - (c_a-1,r+dr) - (c_a..c_b,r+dr) -
    (c_b+1,r+dr) - after. 이렇게 해야 밀어낸 구간이 대각선으로 끊기지 않고 이어진다.
    """
    n = len(cells)
    occupied = set(cells)

    for _ in range(60):
        span = rng.choice([1, 2])
        start = rng.randrange(n)
        # 구간과 양옆 고정 셀(before/after)이 모두 같은 변 위에 있어야 하므로 wrap-around는 제외.
        if start < 1 or start + span >= n - 1:
            continue
        idx = list(range(start, start + span))
        segment = [cells[i] for i in idx]

        cols_in_seg = {c for c, _ in segment}
        rows_in_seg = {r for _, r in segment}
        if len(cols_in_seg) > 1 and len(rows_in_seg) > 1:
            continue  # 모서리를 가로지르는 구간은 제외

        before = cells[idx[0] - 1]
        after = cells[idx[-1] + 1]
        # before/after가 구간과 같은 변(동일 row 또는 동일 col) 위에 있어야 코너가 아니다.
        horizontal = len(rows_in_seg) == 1
        row_or_col = next(iter(rows_in_seg)) if horizontal else next(iter(cols_in_seg))
        if horizontal and (before[1] != row_or_col or after[1] != row_or_col):
            continue
        if not horizontal and (before[0] != row_or_col or after[0] != row_or_col):
            continue

        outward_candidates = [(0, 1), (0, -1)] if horizontal else [(1, 0), (-1, 0)]
        rng.shuffle(outward_candidates)

        for dc, dr in outward_candidates:
            shifted = [(c + dc, r + dr) for c, r in segment]
            if horizontal:
                corner_a = (before[0], shifted[0][1])
                corner_b = (after[0], shifted[-1][1])
            else:
                corner_a = (shifted[0][0], before[1])
                corner_b = (shifted[-1][0], after[1])
            new_segment = [corner_a] + shifted + [corner_b]

            if any(not (0 <= c < cols and 0 <= r < rows) for c, r in new_segment):
                continue
            if len(set(new_segment)) != len(new_segment):
                continue  # 자기 자신과 겹침 (너무 좁은 그리드)

            new_occupied = (occupied - set(segment)) | set(new_segment)
            if len(new_occupied) != len(occupied) + 2:
                continue  # 다른 칸과 겹침

            allowed_extra = {before, after}
            ok = True
            for cell in new_segment:
                for nb in neighbors4(cell):
                    if nb in new_occupied and nb not in new_segment and nb not in allowed_extra:
                        ok = False
                        break
                if not ok:
                    break
            if not ok:
                continue

            return cells[: idx[0]] + new_segment + cells[idx[-1] + 1 :]
    return None


def generate_cycle(cols: int, rows: int, notches_needed: int, rng: random.Random) -> list[tuple[int, int]]:
    cells = build_rectangle(cols, rows)
    for _ in range(notches_needed):
        result = try_add_notch(cells, cols, rows, rng)
        if result is not None:
            cells = result
    return cells


def direction_between(a: tuple[int, int], b: tuple[int, int]) -> str:
    dc, dr = b[0] - a[0], b[1] - a[1]
    for name, vec in GRID_VECTOR.items():
        if vec == (dc, dr):
            return name
    raise ValueError(f"인접하지 않은 칸입니다: {a} -> {b}")


def rotation_for_turn(in_dir: str, out_dir: str) -> int:
    """타일의 물리적 개구부는 `{진입 쪽 반대편, 진출 쪽}`에 있다.

    예: 남쪽에서 북쪽으로 진행(in=N, out=N)하는 직선은 입구가 남쪽(=OPPOSITE[N])에 있다.
    커브도 같은 규칙이며, 좌회전은 같은 rot의 커브 타일을 반대 방향으로 지나가는 것으로 표현된다
    (개구부 집합이 travel 방향과 무관하게 고정되므로 좌/우회전이 자동으로 같은 룩업에 들어온다).
    """
    openings = frozenset({OPPOSITE[in_dir], out_dir})
    if in_dir == out_dir:
        return STRAIGHT_ROT[in_dir]
    return CURVE_OPENINGS_TO_ROT[openings]


def classify_tiles(cells: list[tuple[int, int]]) -> list[dict]:
    n = len(cells)
    tiles = []
    for i, (c, r) in enumerate(cells):
        in_dir = direction_between(cells[i - 1], (c, r))
        out_dir = direction_between((c, r), cells[(i + 1) % n])
        tile_type = "straight" if in_dir == out_dir else "curve"
        rot = rotation_for_turn(in_dir, out_dir)
        tiles.append({"col": c, "row": r, "type": tile_type, "rot": rot, "_dir": in_dir})
    return tiles


def pick_start_index(tiles: list[dict]) -> int:
    """가장 긴 직선 구간(동일 방향 연속 straight)의 가운데를 start로 고른다."""
    n = len(tiles)
    best_run: tuple[int, int] | None = None  # (start_idx, length)
    i = 0
    visited = 0
    # 원형 리스트이므로 모든 straight일 경우까지 대비해 최대 n바퀴만 훑는다.
    while visited < n:
        if tiles[i]["type"] != "straight":
            i = (i + 1) % n
            visited += 1
            continue
        run_start = i
        run_dir = tiles[i]["_dir"]
        length = 0
        j = i
        while tiles[j]["type"] == "straight" and tiles[j]["_dir"] == run_dir and length < n:
            length += 1
            j = (j + 1) % n
            if j == run_start:
                break
        if best_run is None or length > best_run[1]:
            best_run = (run_start, length)
        i = j if j != run_start else (i + 1) % n
        visited += length if length > 0 else 1
    assert best_run is not None, "직선 구간을 찾지 못했습니다"
    run_start, length = best_run
    return (run_start + length // 2) % n


def build_path(tiles: list[dict], tile_size: float) -> tuple[list[dict], list[int]]:
    """타일 중심을 1m 간격으로 잇는 닫힌 점열과, 각 점이 속한 타일 인덱스를 만든다."""
    n = len(tiles)
    centers = [
        (t["col"] * tile_size + tile_size / 2, -(t["row"] * tile_size + tile_size / 2)) for t in tiles
    ]
    samples_per_segment = max(1, round(tile_size))

    path: list[dict] = []
    point_tile_index: list[int] = []
    for i in range(n):
        x0, z0 = centers[i]
        x1, z1 = centers[(i + 1) % n]
        for s in range(samples_per_segment):
            t = s / samples_per_segment
            path.append({"x": round(x0 + (x1 - x0) * t, 4), "z": round(z0 + (z1 - z0) * t, 4)})
            point_tile_index.append(i)
    return path, point_tile_index


def build_checkpoints(path_length: int) -> list[int]:
    raw = [path_length // 4, path_length // 2, (3 * path_length) // 4]
    checkpoints = sorted(set(i for i in raw if 0 < i < path_length))
    return checkpoints


def generate_track(
    seed: int, cols: int, rows: int, difficulty: str, track_id: str, name: str,
    laps: int, tile_size: float, width: float,
) -> dict:
    rng = random.Random(seed)
    cells = generate_cycle(cols, rows, DIFFICULTY_NOTCHES[difficulty], rng)
    tiles = classify_tiles(cells)

    start_idx = pick_start_index(tiles)
    tiles[start_idx]["type"] = "start"

    path, point_tile_index = build_path(tiles, tile_size)
    start_path_index = point_tile_index.index(start_idx)
    start_heading = HEADING_FOR_DIR[tiles[start_idx]["_dir"]]
    checkpoints = build_checkpoints(len(path))

    for t in tiles:
        del t["_dir"]

    return {
        "schemaVersion": 1,
        "id": track_id,
        "name": name,
        "difficulty": difficulty,
        "seed": seed,
        "laps": laps,
        "tileSize": tile_size,
        "width": width,
        "grid": {"cols": cols, "rows": rows},
        "tiles": tiles,
        "path": path,
        "start": {"pathIndex": start_path_index, "heading": round(start_heading, 6)},
        "checkpoints": checkpoints,
        "walls": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--cols", type=int, required=True)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--difficulty", choices=sorted(DIFFICULTY_NOTCHES), required=True)
    parser.add_argument("--id", dest="track_id", required=True)
    parser.add_argument("--name", default=None)
    parser.add_argument("--laps", type=int, default=3)
    parser.add_argument("--tile-size", type=float, default=4.0)
    parser.add_argument("--width", type=float, default=3.0)
    parser.add_argument("--out", required=True, help="출력 JSON 경로")
    args = parser.parse_args()

    track = generate_track(
        seed=args.seed,
        cols=args.cols,
        rows=args.rows,
        difficulty=args.difficulty,
        track_id=args.track_id,
        name=args.name or args.track_id,
        laps=args.laps,
        tile_size=args.tile_size,
        width=args.width,
    )

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(track, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"썼습니다: {out_path} (타일 {len(track['tiles'])}개, path 점 {len(track['path'])}개)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
