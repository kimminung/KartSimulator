#!/usr/bin/env python3
"""서킷(스키마 2) 생성기 — 격자 타일 대신 **구간(segment) 목록**으로 3D 중심선을 만든다 (결정 58).

직선·호(뱅크 가능)·언덕(경사 직선)·360° 수직 루프·헬릭스(나선, 높이 변화가 있는 호)를 이어 붙이고,
마지막은 두빈스(Dubins) 경로로 출발 자세까지 자동으로 닫는다. 결과 JSON에는
  - `path`   : 평면(xz) 중심선 점열 — 미니맵·썸네일·랩 판정(인덱스)이 그대로 쓴다(스키마 1과 같은 뜻)
  - `frames` : 3D 프레임 [x, y, z, tx, ty, tz, ux, uy, uz, kyaw] — 위치, 진행 방향(단위), 노면 법선(단위),
               평면 yaw 곡률(좌회전 +, 1/m). 간격 약 0.5 m. `path[i]`와 `frames[i]`는 같은 점.
  - `model`  : Blender가 만드는 노면 USDZ 이름(`Tools/build_circuit.py`)
좌표계는 테크 PRD 7장/`KartMotionState`와 같다: y 위, heading h의 전진 = (−sin h, 0, −cos h), 좌회전 = h 증가.

사용법:
    python3 gen_circuit.py --preset circuit_01 --out ../circuit_01.json
    python3 gen_circuit.py --list
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass, field

DS = 0.5                      # 프레임 간격(m)
ROAD_WIDTH = 3.0
HALF_WIDTH_TOTAL = 2.125      # 중심선에서 벽 바깥면까지(디자인 타일 단면과 같음)
MIN_CLEARANCE_XZ = 4.5        # 같은 높이로 나란히 지나는 두 구간의 중심선 최소 간격(벽 바깥면 2.125×2 + 여유)
MIN_CLEARANCE_Y = 2.6         # 교차(입체) 시 최소 높이 차(카트 0.8 + 벽 0.5 + 슬래브 0.25 + 여유)
OVERLAP_XZ = 4.25             # 이보다 가까우면 벽이 겹친다 → 높이 차가 MIN_CLEARANCE_Y 이상이어야 함


@dataclass
class Frame:
    p: tuple[float, float, float]
    t: tuple[float, float, float]
    u: tuple[float, float, float]
    kyaw: float
    feature: str = ""


def norm(v):
    l = math.sqrt(sum(c * c for c in v))
    return tuple(c / l for c in v) if l > 1e-9 else v


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def mul(a, s): return tuple(x * s for x in a)
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def fwd(h): return (-math.sin(h), 0.0, -math.cos(h))
def right_of(h): return (math.cos(h), 0.0, -math.sin(h))  # forward × up(Y)


def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def ease(l):  # 0..1 → 0..1 코사인 완화
    return (1 - math.cos(math.pi * l)) / 2


def ease_d(l):  # d ease / d l
    return math.pi * math.sin(math.pi * l) / 2


class Builder:
    """거북이: 평면 위치(x, z)·heading h·높이 y. 각 구간이 프레임을 추가한다."""

    def __init__(self, trace=False):
        self.x = 0.0; self.z = 0.0; self.y = 0.0; self.h = 0.0
        self.frames: list[Frame] = []
        self.segments: list[dict] = []
        self.features: list[str] = []
        self.trace = trace

    def _log(self):
        if self.trace:
            seg = self.segments[-1]
            print(f"    {seg['type']:<8} → x {self.x:7.2f} z {self.z:7.2f} y {self.y:5.2f} h {math.degrees(wrap(self.h)):7.1f}°  frames {len(self.frames)}")

    def _feature(self, name):
        if name and name not in self.features:
            self.features.append(name)

    # ---- 직선(경사 가능) --------------------------------------------------------------------------
    def straight(self, length, dh=0.0, feature=""):
        self.segments.append({"type": "straight", "length": length, "dh": dh, "feature": feature})
        self._feature(feature)
        n = max(int(round(length / DS)), 1)
        f = fwd(self.h); y0 = self.y
        x0, z0 = self.x, self.z
        for i in range(n):
            l = i / n
            p = (x0 + f[0] * length * l, y0 + dh * ease(l), z0 + f[2] * length * l)
            dy = dh * ease_d(l) / length if length > 0 else 0.0
            t = norm((f[0], dy, f[2]))
            r = right_of(self.h)
            u = norm(cross(r, t))  # right × tangent = up (오른손: t × u = r)
            self.frames.append(Frame(p, t, u, 0.0, feature))
        self.x = x0 + f[0] * length; self.z = z0 + f[2] * length; self.y = y0 + dh
        self._log()

    # ---- 호(뱅크·높이 변화 가능; angle>0 좌회전) --------------------------------------------------
    def arc(self, radius, angle_deg, bank_deg=0.0, dh=0.0, feature=""):
        self.segments.append({"type": "arc", "radius": radius, "angle": angle_deg, "bank": bank_deg, "dh": dh, "feature": feature})
        self._feature(feature)
        a = math.radians(angle_deg); sgn = 1.0 if a > 0 else -1.0
        arc_len = abs(a) * radius
        n = max(int(round(arc_len / DS)), 2)
        # 회전 중심: 좌회전이면 왼쪽(−right) 반지름만큼.
        r0 = right_of(self.h)
        cx = self.x - sgn * r0[0] * radius; cz = self.z - sgn * r0[2] * radius
        h0, y0 = self.h, self.y
        k = sgn / radius
        for i in range(n):
            l = i / n
            h = h0 + a * l
            r = right_of(h)
            p = (cx + sgn * r[0] * radius, y0 + dh * (l if abs(dh) > 0 else 0), cz + sgn * r[2] * radius)
            f = fwd(h)
            dy = (dh / arc_len) if arc_len > 0 else 0.0
            t = norm((f[0], dy, f[2]))
            u = norm(cross(r, t))
            # 뱅크: 안쪽(좌회전이면 왼쪽 = −right)으로 노면을 기울인다. 양 끝 20 %는 완화.
            if bank_deg:
                ramp = min(l / 0.2, (1 - l) / 0.2, 1.0) if n > 1 else 1.0
                b = math.radians(bank_deg) * ramp
                inward = mul(r, -sgn)
                u = norm(add(mul(u, math.cos(b)), mul(inward, math.sin(b))))
            self.frames.append(Frame(p, t, u, k, feature))
        self.h = h0 + a; self.y = y0 + dh
        r = right_of(self.h)
        self.x = cx + sgn * r[0] * radius; self.z = cz + sgn * r[2] * radius
        self._log()

    # ---- 360° 수직 루프(진행 평면 안에서 한 바퀴, 옆으로 shift만큼 비켜 나옴) ---------------------
    def loop(self, radius, shift=5.5, feature="루프"):
        self.segments.append({"type": "loop", "radius": radius, "shift": shift, "feature": feature})
        self._feature(feature)
        circ = 2 * math.pi * radius
        n = max(int(round(circ / DS)), 8)
        f = fwd(self.h); r = right_of(self.h); up = (0.0, 1.0, 0.0)
        x0, y0, z0 = self.x, self.y, self.z
        for i in range(n):
            phi = 2 * math.pi * i / n
            along = radius * math.sin(phi)
            lift = radius * (1 - math.cos(phi))
            side = shift * (phi / (2 * math.pi))
            p = (x0 + f[0] * along + r[0] * side, y0 + lift, z0 + f[2] * along + r[2] * side)
            t = norm(add(add(mul(f, math.cos(phi)), mul(up, math.sin(phi))), mul(r, shift / circ)))
            # 노면 법선: 루프 안쪽(중심 쪽)을 향한다 — 바닥에서는 +Y, 꼭대기에서는 −Y(카트가 거꾸로 매달림).
            u = norm(add(mul(f, -math.sin(phi)), mul(up, math.cos(phi))))
            self.frames.append(Frame(p, t, u, 0.0, feature))
        self.x = x0 + r[0] * shift; self.z = z0 + r[2] * shift
        self._log()

    # ---- 두빈스 닫기: 현재 자세 → (0,0, heading 0) ------------------------------------------------
    def close(self, radius, feature=""):
        """CSC/CCC 여섯 후보 중 가장 짧은 것으로 출발 자세(원점, heading 0)까지 잇는다. 높이는 현재 y를 유지(0이어야 함)."""
        # 수학 좌표: X = x, Y = −z, θ = h + π/2 (북 = +Y = θ π/2, 좌회전 = θ 증가)
        sx, sy, sth = self.x, -self.z, self.h + math.pi / 2
        gx, gy, gth = 0.0, 0.0, math.pi / 2
        dx, dy = gx - sx, gy - sy
        D = math.hypot(dx, dy); d = D / radius
        phi = math.atan2(dy, dx)
        al = (sth - phi) % (2 * math.pi); be = (gth - phi) % (2 * math.pi)
        sa, ca, sb, cb = math.sin(al), math.cos(al), math.sin(be), math.cos(be)
        m = lambda a: a % (2 * math.pi)
        cands = []
        # LSL
        tmp = d + sa - sb; p2 = 2 + d * d - 2 * math.cos(al - be) + 2 * d * (sa - sb)
        if p2 >= 0:
            th = math.atan2(cb - ca, tmp); cands.append(("LSL", m(-al + th), math.sqrt(p2), m(be - th)))
        # RSR
        tmp = d - sa + sb; p2 = 2 + d * d - 2 * math.cos(al - be) + 2 * d * (sb - sa)
        if p2 >= 0:
            th = math.atan2(ca - cb, tmp); cands.append(("RSR", m(al - th), math.sqrt(p2), m(-be + th)))
        # LSR
        p2 = -2 + d * d + 2 * math.cos(al - be) + 2 * d * (sa + sb)
        if p2 >= 0:
            p = math.sqrt(p2); th = math.atan2(-ca - cb, d + sa + sb) - math.atan2(-2.0, p)
            cands.append(("LSR", m(-al + th), p, m(-m(be) + th)))
        # RSL
        p2 = d * d - 2 + 2 * math.cos(al - be) - 2 * d * (sa + sb)
        if p2 >= 0:
            p = math.sqrt(p2); th = math.atan2(ca + cb, d - sa - sb) - math.atan2(2.0, p)
            cands.append(("RSL", m(al - th), p, m(be - th)))
        # RLR
        tmp = (6 - d * d + 2 * math.cos(al - be) + 2 * d * (sa - sb)) / 8
        if abs(tmp) <= 1:
            p = m(2 * math.pi - math.acos(tmp)); t = m(al - math.atan2(ca - cb, d - sa + sb) + p / 2)
            cands.append(("RLR", t, p, m(al - be - t + p)))
        # LRL
        tmp = (6 - d * d + 2 * math.cos(al - be) + 2 * d * (-sa + sb)) / 8
        if abs(tmp) <= 1:
            p = m(2 * math.pi - math.acos(tmp)); t = m(-al + math.atan2(-ca + cb, d + sa - sb) + p / 2)
            cands.append(("LRL", t, p, m(m(be) - al - t + p)))
        if not cands:
            raise ValueError("두빈스 경로를 찾지 못했습니다")
        def length(c):
            kind, t, p, q = c
            return (t + q + (p if kind[1] == "S" else p)) * radius if kind[1] != "S" else (t + q) * radius + p * radius
        best = min(cands, key=length)
        kind, t, p, q = best
        self.segments.append({"type": "close", "dubins": kind, "radius": radius, "feature": feature})
        self._log()
        for part, amount in zip(kind, (t, p, q)):
            if amount < 1e-6:
                continue
            if part == "S":
                self.straight(amount * radius, feature=feature)
            else:
                self.arc(radius, math.degrees(amount) * (1 if part == "L" else -1), feature=feature)
        return kind


# ---- 검사 -------------------------------------------------------------------------------------------
def seg_intersect(p1, p2, p3, p4):
    def o(a, b, c):
        return (b[1] - a[1]) * (c[0] - b[0]) - (b[0] - a[0]) * (c[1] - b[1])
    d1, d2, d3, d4 = o(p3, p4, p1), o(p3, p4, p2), o(p1, p2, p3), o(p1, p2, p4)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def analyze(frames: list[Frame]):
    n = len(frames)
    pts = [(f.p[0], f.p[2]) for f in frames]
    # 닫힘 오차
    last = frames[-1]; first = frames[0]
    close_err = math.dist(last.p, first.p)
    heading_err = math.degrees(math.acos(max(-1, min(1, dot(last.t, first.t)))))
    # 교차(입체) 검사: 인접하지 않은 세그먼트끼리
    crossings = []
    for i in range(n):
        a1, a2 = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if (j + 1) % n == i:
                continue
            b1, b2 = pts[j], pts[(j + 1) % n]
            if seg_intersect(a1, a2, b1, b2):
                dy = abs(frames[i].p[1] - frames[j].p[1])
                crossings.append((i, j, dy))
    # 평면 근접(벽끼리 닿음) 검사: 중심선 거리 < MIN_CLEARANCE_XZ 이고 높이 차 < MIN_CLEARANCE_Y 이며 경로상 멀리 떨어진 점
    min_clear = (1e9, -1, -1)
    violations = []
    window = int(8 / DS)  # 경로상 8 m 안쪽 이웃은 제외
    for i in range(n):
        for j in range(i + window, n):
            if n - j + i < window:
                continue
            dxz = math.dist(pts[i], pts[j]); dy = abs(frames[i].p[1] - frames[j].p[1])
            if dy < MIN_CLEARANCE_Y and dxz < min_clear[0]:
                min_clear = (dxz, i, j)
            # 같은 높이(0.6 m 안)로 나란히: 벽 사이 여유까지 요구. 높이가 다르면 벽이 겹치지만 않으면 된다(입체 교차).
            if (dy < 0.6 and dxz < MIN_CLEARANCE_XZ) or (dy < MIN_CLEARANCE_Y and dxz < OVERLAP_XZ):
                violations.append((i, j, dxz, dy))
    length = sum(math.dist(frames[i].p, frames[(i + 1) % n].p) for i in range(n))
    return {
        "closeError": close_err, "headingError": heading_err, "crossings": crossings,
        "minClearance": min_clear, "violations": violations, "length": length,
        "maxY": max(f.p[1] for f in frames), "minY": min(f.p[1] for f in frames),
    }


# ---- 프리셋 -----------------------------------------------------------------------------------------
def preset_circuit_01(b: Builder):
    """루키 오벌(easy): 긴 직선 → 12° 뱅크 커브 → 언덕 → 커브. 처음 타는 사람용."""
    b.straight(36, feature="직선")
    b.arc(9, 180, bank_deg=12, feature="뱅크 커브")
    b.straight(8)
    b.straight(10, dh=2.0, feature="언덕")
    b.straight(4)
    b.straight(10, dh=-2.0)
    b.straight(4)
    b.arc(9, 180)
    return b.close(9)


def preset_circuit_02(b: Builder):
    """리본 루프(normal): 360° 수직 루프 → 시케인 → 헤어핀."""
    b.straight(14, feature="직선")
    b.loop(3.0, shift=5.5, feature="360° 루프")
    b.straight(12)
    b.arc(7, -90)
    b.straight(6)
    b.arc(7, 40, feature="시케인"); b.arc(7, -40, feature="시케인")
    b.arc(7, -40, feature="시케인"); b.arc(7, 40, feature="시케인")
    b.straight(8)
    b.arc(3.5, -180, feature="헤어핀")
    b.straight(10)
    return b.close(7)


def preset_circuit_03(b: Builder):
    """스카이 스파이럴(hard): 오르막 → 다리 → 헬릭스(360° 나선 하강, 다리 끝 아래로) → 더블 시케인 → 뱅크 스위퍼 → 백 스트레이트."""
    b.straight(12, feature="직선")
    b.straight(12, dh=3.5, feature="오르막")
    b.straight(10, feature="브리지")
    b.arc(6.5, 360, dh=-3.5, bank_deg=10, feature="헬릭스")
    b.straight(10)
    b.arc(6, -90)
    b.straight(6)
    b.arc(6, 45, feature="시케인"); b.arc(6, -45, feature="시케인")
    b.arc(6, -45, feature="시케인"); b.arc(6, 45, feature="시케인")
    b.straight(4)
    b.arc(7, -180, bank_deg=15, feature="뱅크 스위퍼")
    b.straight(14)
    b.arc(7, 90)
    b.straight(17, feature="백 스트레이트")
    return b.close(6)


# 테마(컨셉): 노면 메시 팔레트·소품(`Tools/build_circuit.py`)과 미니맵 색(`MinimapBuilder`)이 읽는다. 색은 스타일 가이드
# 팔레트를 기본으로 하되 맵마다 배경·벽·연석을 바꿔 "공원 / 네온 나이트 / 사막 협곡" 세 분위기로 나눈다.
THEMES = {
    "park": {  # 낮의 잔디 공원: 밝은 잔디, 흰·빨간 연석, 밝은 가드레일, 나무
        "ground": "546D33", "wall": "A5A6AB", "wallPost": "F9C628", "curb": "C9453F", "curbAlt": "EAECED",
        "edgeLine": "F9C628", "road": "15151A", "roadAlt": "08090E", "props": "trees",
        "minimap": {"road": "F4F7EC", "edge": "142737", "disc": "010B1A", "accent": "56E27A"},
    },
    "neon": {  # 밤의 네온 서킷: 검은 바닥, 시안·마젠타 연석, 네온 가장자리 선, 가로등
        "ground": "0B0F1A", "wall": "223A60", "wallPost": "FF5CD6", "curb": "00F6F9", "curbAlt": "0D1729",
        "edgeLine": "00F6F9", "road": "15151A", "roadAlt": "08090E", "props": "lamps",
        "minimap": {"road": "F4F7EC", "edge": "FF5CD6", "disc": "000918", "accent": "00F6F9"},
    },
    "canyon": {  # 사막 협곡: 모래 바닥, 붉은 바위 벽, 주황·흰 연석, 바위 더미
        "ground": "C9A66B", "wall": "8C4A3A", "wallPost": "F9C628", "curb": "E8783A", "curbAlt": "F7EBD0",
        "edgeLine": "F7EBD0", "road": "3A3038", "roadAlt": "2A2228", "props": "rocks",
        "minimap": {"road": "F7EBD0", "edge": "5A2E22", "disc": "2A1A14", "accent": "E8783A"},
    },
}

PRESETS = {
    "circuit_01": {"name": "루키 오벌", "difficulty": "easy", "dots": 1, "build": preset_circuit_01, "theme": {"id": "park", **THEMES["park"]},
                   "desc": "뱅크 커브와 언덕 하나. 레이싱 라인과 스로틀 유지 연습."},
    "circuit_02": {"name": "리본 루프", "difficulty": "normal", "dots": 3, "build": preset_circuit_02, "theme": {"id": "neon", **THEMES["neon"]},
                   "desc": "360° 수직 루프(풀 스로틀로 진입, 안에서 핸들 금지) → 시케인 리듬 → 헤어핀 브레이킹."},
    "circuit_03": {"name": "스카이 스파이럴", "difficulty": "hard", "dots": 5, "build": preset_circuit_03, "theme": {"id": "canyon", **THEMES["canyon"]},
                   "desc": "오르막 다리 → 360° 나선 하강으로 다리 아래 통과 → 더블 시케인 → 15° 뱅크 스위퍼 → 백 스트레이트."},
}


def sections_of(frames: list[Frame]) -> list[dict]:
    """같은 feature가 이어지는 프레임 구간(미니맵 라벨·기둥 등에 쓴다)."""
    out = []
    for i, f in enumerate(frames):
        if out and out[-1]["feature"] == f.feature:
            out[-1]["to"] = i
        else:
            out.append({"feature": f.feature, "from": i, "to": i})
    return [s for s in out if s["feature"]]


def build(preset_id: str, laps: int, trace=False) -> tuple[dict, dict]:
    spec = PRESETS[preset_id]
    b = Builder(trace=trace)
    kind = spec["build"](b)
    frames = b.frames
    report = analyze(frames)
    report["endPose"] = (b.x, b.z, b.y, math.degrees(wrap(b.h)))
    n = len(frames)
    heading0 = math.atan2(-frames[0].t[0], -frames[0].t[2])
    checkpoints = [n // 4, n // 2, (3 * n) // 4]
    data = {
        "schemaVersion": 2,
        "id": preset_id,
        "name": spec["name"],
        "difficulty": spec["difficulty"],
        "difficultyDots": spec["dots"],
        "description": spec["desc"],
        "features": b.features,
        "seed": 0,
        "laps": laps,
        "tileSize": 4.0,
        "width": ROAD_WIDTH,
        "length": round(report["length"], 3),
        "model": preset_id,
        "path": [{"x": round(f.p[0], 4), "z": round(f.p[2], 4)} for f in frames],
        "frames": [[round(c, 4) for c in (*f.p, *f.t, *f.u, f.kyaw)] for f in frames],
        "start": {"pathIndex": 0, "heading": round(heading0, 6)},
        "checkpoints": checkpoints,
        "walls": True,
        "tuning": {"gravity": 4.5},
        "theme": spec["theme"],
        "sections": sections_of(frames),
        "segments": b.segments,
        "closedWith": kind,
    }
    return data, report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", choices=sorted(PRESETS))
    ap.add_argument("--laps", type=int, default=3)
    ap.add_argument("--out")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--trace", action="store_true", help="구간마다 거북이 자세 출력")
    args = ap.parse_args()
    if args.list:
        for k, v in PRESETS.items():
            print(k, v["name"], v["difficulty"], "-", v["desc"])
        return 0
    if not args.preset:
        ap.error("--preset 필요")
    data, rep = build(args.preset, args.laps, trace=args.trace)
    print(f"[{args.preset}] {data['name']} 길이 {rep['length']:.1f} m, 프레임 {len(data['frames'])}, 높이 {rep['minY']:.2f}~{rep['maxY']:.2f} m, 닫기 {data['closedWith']}")
    ex, ez, ey, eh = rep["endPose"]
    pose_err = math.hypot(ex, ez)
    print(f"  끝 자세 오차 위치 {pose_err:.3f} m 높이 {ey:.3f} m 방향 {eh:.2f}° (마지막 프레임→출발점 간격 {rep['closeError']:.2f} m)")
    ok = pose_err < 0.05 and abs(ey) < 0.01 and abs(eh) < 0.5 and rep["closeError"] < 1.0
    for i, j, dy in rep["crossings"]:
        flag = "OK" if dy >= MIN_CLEARANCE_Y else "충돌!"
        print(f"  교차 {i}×{j} 높이차 {dy:.2f} m {flag}")
        ok = ok and dy >= MIN_CLEARANCE_Y
    print(f"  최소 평면 간격 {rep['minClearance'][0]:.2f} m (프레임 {rep['minClearance'][1]}·{rep['minClearance'][2]})")
    if rep["violations"]:
        v = rep["violations"][0]
        print(f"  간격 위반 {len(rep['violations'])}건 (예: {v[0]}·{v[1]} {v[2]:.2f} m, 높이차 {v[3]:.2f})")
        ok = False
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        print("  썼습니다:", args.out)
    print("  결과:", "통과" if ok else "실패")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
