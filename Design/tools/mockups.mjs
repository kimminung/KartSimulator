// node Design/tools/mockups.mjs   (needs sharp; run Design/tools/tiles.mjs and icons.mjs first)
// Screen mockups of design PRD 8 (menu window 600 x 480 pt at 2x = 1200 x 960 px) and the minimap
// mockup of PRD 6 (24 cm table seen from 45 degrees). Windows fonts stand in for SF Pro / Galmuri
// (the title uses a pixel-style lettering until Design/fonts/Galmuri is in place).
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const OUT = path.join(REPO, "Design/mockups");
fs.mkdirSync(OUT, { recursive: true });
const req = createRequire(import.meta.url);
let sharp; try { sharp = req("C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp"); } catch { sharp = req("sharp"); }
// Design/style-guide.md (RetireX colour system): UI 1-2, kart colours 1-3, minimap 1-4
const C = { magenta: "#FF5CD6", night: "#000918", panel: "#010B1A", well: "#0D1729", rim: "#223A60", cyan: "#00F6F9", sky: "#1DB8E6", gold: "#FEDA34", ink: "#F2F9FF", warn: "#FF3236",
  kart: "#EE4949", white: "#F1F2EE", mmRoad: "#F4F7EC", mmEdge: "#142737", finish: "#22B4DD" };
const W = 1200, H = 960; // 600 x 480 pt @2x
const FONT = "Segoe UI, Malgun Gothic, sans-serif", KR = "Malgun Gothic, Segoe UI, sans-serif";
const icon = (name, x, y, size, color) => {
  const s = fs.readFileSync(path.join(REPO, "Design/icons", `icon_${name}.svg`), "utf8").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, "");
  return `<g transform="translate(${x} ${y}) scale(${size / 24})" color="${color}" style="color:${color}">${s}</g>`;
};
const gesture = (name, x, y, size) => `<g transform="translate(${x} ${y}) scale(${size / 240})">${fs.readFileSync(path.join(REPO, "Design/onboarding", name + ".svg"), "utf8").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, "")}</g>`;
const glass = (x, y, w, h, r = 24, op = 0.72) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="#2a3340" fill-opacity="${op}" stroke="#ffffff" stroke-opacity="0.18"/>`;
const button = (x, y, w, label, primary) => `<rect x="${x}" y="${y}" width="${w}" height="64" rx="32" fill="${primary ? C.cyan : "#ffffff"}" fill-opacity="${primary ? 1 : 0.14}"/><text x="${x + w / 2}" y="${y + 41}" font-family="${KR}" font-size="26" font-weight="700" fill="${primary ? C.night : C.ink}" text-anchor="middle">${label}</text>`;
const text = (x, y, s, size, opts = {}) => `<text x="${x}" y="${y}" font-family="${opts.font || KR}" font-size="${size}" font-weight="${opts.weight || 400}" fill="${opts.fill || C.ink}" fill-opacity="${opts.op ?? 1}" text-anchor="${opts.anchor || "start"}" ${opts.mono ? 'font-variant-numeric="tabular-nums"' : ""}>${s}</text>`;
// pixel-style title until Galmuri is added: each glyph drawn with crisp squares
const pixelTitle = (x, y, s, size) => `<text x="${x}" y="${y}" font-family="${KR}" font-size="${size}" font-weight="800" fill="#fff" letter-spacing="4" style="paint-order:stroke" stroke="${C.night}" stroke-width="6" text-anchor="middle">${s}</text>`;
const bg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a4656"/><stop offset="1" stop-color="#1c232c"/></linearGradient></defs><rect width="${W}" height="${H}" fill="url(#bg)"/>${body}</svg>`;

// track thumbnails from the tech side's JSON (path, start, checkpoints)
const tracks = ["track_01", "track_02"].map((t) => { const f = path.join(REPO, "Tracks", t + ".json"); return fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : null; }).filter(Boolean);
function thumb(tr, x, y, size) {
  const xs = tr.path.map((p) => p.x), zs = tr.path.map((p) => p.z);
  const span = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...zs) - Math.min(...zs)) * 1.2;
  const cx = (Math.max(...xs) + Math.min(...xs)) / 2, cz = (Math.max(...zs) + Math.min(...zs)) / 2;
  const P = (p) => `${(x + size / 2 + (p.x - cx) / span * size).toFixed(1)},${(y + size / 2 + (p.z - cz) / span * size).toFixed(1)}`;
  const d = "M" + tr.path.map(P).join(" L") + " Z";
  const s = tr.path[tr.start?.pathIndex ?? 0];
  return `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="14" fill="${C.well}" fill-opacity="0.78"/><path d="${d}" fill="none" stroke="${C.mmEdge}" stroke-width="${size / 9}" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${C.mmRoad}" stroke-width="${size / 14}" stroke-linejoin="round"/><circle cx="${P(s).split(",")[0]}" cy="${P(s).split(",")[1]}" r="${size / 22}" fill="${C.finish}" stroke="${C.night}" stroke-width="2"/>`;
}
const dots = (x, y, n) => [0, 1, 2, 3, 4].map((i) => `<circle cx="${x + i * 20}" cy="${y}" r="7" fill="${i < n ? C.gold : "#ffffff"}" fill-opacity="${i < n ? 1 : 0.3}"/>`).join("");

const volume = fs.readFileSync(path.join(REPO, "Design/reference/tiles_preview_track01.png")).toString("base64");
const volBg = (dim = 1) => `<image href="data:image/png;base64,${volume}" x="0" y="80" width="${W}" height="${H * 0.82}" opacity="${dim}"/>`;

// pedal gauge (design PRD 7): vertical bar, centre = neutral, up = forward (ui-cyan), down = reverse (ui-magenta)
const pedalGauge = (x, y, v, h = 104) => `<rect x="${x}" y="${y}" width="16" height="${h}" rx="4" fill="#ffffff" fill-opacity="0.14"/><rect x="${x - 3}" y="${y + h / 2 - 1}" width="22" height="2" fill="${C.ink}" fill-opacity="0.7"/>` +
  (v >= 0 ? `<rect x="${x}" y="${y + h / 2 - v * h / 2}" width="16" height="${v * h / 2}" fill="${C.cyan}"/>` : `<rect x="${x}" y="${y + h / 2}" width="16" height="${-v * h / 2}" fill="${C.magenta}"/>`);
const SCREENS = {
  "01_start": bg(
    pixelTitle(W / 2, 140, "핀치 카트", 92) + text(W / 2, 192, "책상 위 복셀 트랙 타임어택", 26, { anchor: "middle", op: 0.75 }) +
    ["첫 바퀴|1|0:31.42", "노치 하나|2|0:36.10", "두 번 꺾기|4|—"].map((s, i) => {
      const [name, diff, best] = s.split("|"), x = 60 + i * 370;
      return glass(x, 250, 340, 470) + (tracks[i % tracks.length] ? thumb(tracks[i % tracks.length], x + 40, 280, 260) : "") + text(x + 40, 600, name, 34, { weight: 700 }) + dots(x + 48, 640, +diff) + text(x + 40, 690, "최고 " + best, 24, { font: FONT, op: 0.8 });
    }).join("") + `<rect x="60" y="250" width="340" height="470" rx="24" fill="none" stroke="${C.cyan}" stroke-width="5"/>` +
    button(360, 790, 300, "시작", true) + button(690, 790, 200, "조작법", false)),
  "02_howto": bg(
    text(W / 2, 110, "조작법", 48, { anchor: "middle", weight: 800 }) +
    [["gesture_01_forward", "양손을 모을수록 빨리 전진"], ["gesture_02_reverse", "양손을 벌릴수록 빨리 후진"], ["gesture_03_left", "왼손만 핀치하면 좌회전"], ["gesture_04_right", "오른손만 핀치하면 우회전"], ["gesture_05_stop", "양손을 떼면 멈춤"]].map(([g, cap], i) => {
      const row = i < 3 ? 0 : 1, col = row ? i - 3 : i, x = (row ? 232 : 45) + col * 375, y = 140 + row * 320;
      return glass(x, y, 360, 300) + gesture(g, x + 80, y + 14, 200) + text(x + 180, y + 270, cap, 24, { anchor: "middle", weight: 600 });
    }).join("") + text(W / 2, 800, "양손 사이 약 40 cm에서는 제자리(중립)", 22, { anchor: "middle", op: 0.7 }) + button(450, 830, 300, "알겠어요", true) + text(W / 2, 930, "앉아서 플레이하면 편해요", 22, { anchor: "middle", op: 0.6 })),
  "03_ready": bg(volBg(0.95) + glass(300, 40, 600, 150) + icon("hand_left_pinch", 360, 70, 72, C.cyan) + icon("hand_right_open", 768, 70, 72, C.warn) +
    `<rect x="764" y="66" width="80" height="80" rx="8" fill="none" stroke="${C.warn}" stroke-width="3" stroke-dasharray="8 6"/>` +
    text(W / 2, 112, "양손을 핀치하면 출발합니다", 30, { anchor: "middle", weight: 700 }) + text(W / 2, 156, "오른손이 보이지 않아요", 22, { anchor: "middle", fill: C.warn })),
  "04_countdown": bg(volBg(0.85) + ["3", "2", "1", "GO"].map((s, i) => glass(60 + i * 280, 300, 250, 300) + text(185 + i * 280, 500, s, i === 3 ? 120 : 150, { anchor: "middle", weight: 800, fill: i === 3 ? C.cyan : C.ink, font: FONT })).join("") +
    text(W / 2, 680, "숫자 1.2배 → 1.0배, 각 1초 · GO 0.8배 → 1.0배 후 0.5초 페이드", 22, { anchor: "middle", op: 0.7 })),
  "05_racing": bg(volBg(1) +
    glass(300, 30, 600, 130, 24) + text(340, 80, "LAP", 20, { op: 0.7, font: FONT }) + text(340, 130, "2 / 3", 56, { weight: 700, font: FONT }) +
    text(560, 80, "TIME", 20, { op: 0.7, font: FONT }) + text(560, 130, "0:12.48", 68, { weight: 700, font: FONT, mono: true }) + icon("flag_checkpoint", 832, 96, 36, C.cyan) +
    text(560, 152, "총 0:38.20 · BEST 0:12.10", 20, { op: 0.8, font: FONT }) + glass(910, 30, 200, 130, 24) + text(1010, 108, "18", 60, { anchor: "middle", weight: 700, font: FONT }) + text(1010, 144, "km/h", 20, { anchor: "middle", op: 0.7, font: FONT }) +
    glass(40, 770, 330, 150) + icon("hand_left_pinch", 70, 800, 72, C.cyan) + icon("arrow_forward", 156, 808, 56, C.cyan) + pedalGauge(226, 790, 0.7, 84) + icon("hand_right_pinch", 266, 800, 72, C.cyan) + text(205, 905, "전진 70 %", 20, { anchor: "middle", op: 0.8 }) +
    `<image href="minimap.png" x="900" y="660" width="280" height="280"/>`),
  "06_pause": bg(volBg(0.45) + `<rect width="${W}" height="${H}" fill="#000" fill-opacity="0.35"/>` + glass(350, 220, 500, 540) + text(W / 2, 300, "일시정지", 42, { anchor: "middle", weight: 800 }) +
    button(420, 350, 360, "재개", true) + button(420, 440, 360, "다시 시작", false) + button(420, 530, 360, "트랙 선택", false) + button(420, 620, 360, "종료", false)),
  "07_result": bg(glass(250, 80, 700, 800) + text(W / 2, 170, "완주!", 44, { anchor: "middle", weight: 800 }) + text(W / 2, 320, "1:34.62", 120, { anchor: "middle", weight: 800, font: FONT, mono: true }) +
    `<rect x="525" y="352" width="150" height="54" rx="27" fill="${C.gold}"/>` + text(600, 389, "신기록!", 26, { anchor: "middle", weight: 800, fill: C.night }) +
    [["1랩", "0:32.10", ""], ["2랩", "0:31.08", "BEST"], ["3랩", "0:31.44", ""]].map(([l, t, b], i) => text(400, 470 + i * 64, l, 30, { op: 0.75 }) + text(800, 470 + i * 64, t, 34, { anchor: "end", weight: 600, font: FONT, mono: true }) + (b ? text(820, 468 + i * 64, b, 20, { fill: C.gold, weight: 700, font: FONT }) : "")).join("") +
    button(330, 700, 260, "다시 하기", true) + button(610, 700, 260, "트랙 선택", false)),
};

// minimap mockup: 24 cm table, 45 degrees from above, track_01
async function minimap(inset = false) {
  const tr = tracks[0];
  const S = 1000, cx = 500, cy = 470, R = 360, k = Math.cos(Math.PI / 4); // ellipse squash at 45 degrees
  const xs = tr.path.map((p) => p.x), zs = tr.path.map((p) => p.z);
  const span = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...zs) - Math.min(...zs)) * 1.25;
  const mx = (Math.max(...xs) + Math.min(...xs)) / 2, mz = (Math.max(...zs) + Math.min(...zs)) / 2;
  const P = (p) => [cx + (p.x - mx) / span * 2 * R * 0.95, cy + (p.z - mz) / span * 2 * R * 0.95 * k];
  const d = "M" + tr.path.map((p) => P(p).map((v) => v.toFixed(1)).join(",")).join(" L") + " Z";
  const cp = tr.checkpoints.map((i) => P(tr.path[i]));
  const st = P(tr.path[tr.start.pathIndex]);
  const kp = P(tr.path[(tr.checkpoints[0] + 6) % tr.path.length]);
  const label = (n, [x, y], on) => `<g transform="translate(${x - 20} ${y - 66})"><rect x="0" y="0" width="40" height="40" rx="20" fill="${on ? C.cyan : "#ffffff"}" fill-opacity="${on ? 1 : 0.4}"/><text x="20" y="29" font-family="${FONT}" font-size="24" font-weight="700" fill="${C.night}" text-anchor="middle">${n}</text><rect x="19" y="40" width="2" height="22" fill="#fff" fill-opacity="0.7"/></g>`;
  const body = (inset ? "" : `<rect width="${S}" height="${S}" fill="#20262e"/>`) +
    `<ellipse cx="${cx}" cy="${cy + 70}" rx="${R + 10}" ry="${(R + 10) * k}" fill="${C.rim}"/>` + // rim / legs side
    `<rect x="${cx - 40}" y="${cy + 70}" width="80" height="230" fill="${C.rim}" opacity="0.85"/><ellipse cx="${cx}" cy="${cy + 300}" rx="140" ry="40" fill="${C.rim}" opacity="0.85"/>` +
    `<ellipse cx="${cx}" cy="${cy}" rx="${R + 10}" ry="${(R + 10) * k}" fill="${C.well}"/>` +
    `<ellipse cx="${cx}" cy="${cy}" rx="${R - 14}" ry="${(R - 14) * k}" fill="${C.panel}" fill-opacity="0.78"/>` + // HUD well at 78 %, as RetireX's minimap frame
    `<path d="${d}" fill="none" stroke="${C.mmEdge}" stroke-width="44" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${C.mmRoad}" stroke-width="30" stroke-linejoin="round"/>` +
    `<path d="${d}" fill="none" stroke="${C.sky}" stroke-opacity="0.4" stroke-width="10" stroke-linejoin="round"/>` +
    `<g transform="translate(${st[0] - 18} ${st[1] - 80})">${fs.readFileSync(path.join(REPO, "Design/icons/icon_minimap_start_flag.svg"), "utf8").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, "").replace(/currentColor/g, "#ffffff")}</g>`.replace(`translate(${st[0] - 18} ${st[1] - 80})`, `translate(${st[0] - 15} ${st[1] - 63}) scale(3)`) +
    label(1, cp[0], true) + label(2, cp[1], false) + label(3, cp[2], false) +
    `<ellipse cx="${kp[0]}" cy="${kp[1] + 6}" rx="20" ry="${20 * k}" fill="${C.cyan}" fill-opacity="0.6"/><rect x="${kp[0] - 12}" y="${kp[1] - 16}" width="24" height="30" rx="4" fill="${C.kart}" stroke="${C.night}" stroke-width="2"/><rect x="${kp[0] - 3}" y="${kp[1] - 16}" width="6" height="12" fill="${C.white}"/>` +
    text(cx, cy + R * k + 52, "2 / 3", 28, { anchor: "middle", weight: 700, font: FONT, fill: C.ink }) +
    (inset ? "" : text(40, 930, "미니맵 목업 · 지름 24 cm 테이블, 위에서 45° · 노면 mm-road, 테두리 mm-edge, 궤적 ui-sky 40 %", 20, { op: 0.75 }) + text(40, 962, "체크포인트 1 통과(ui-cyan) · 2·3 미통과(흰 40 %) · 카트 마커 = 도색 색 + ui-cyan 그림자", 20, { op: 0.75 }));
  await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}">${body}</svg>`)).png().toFile(path.join(OUT, inset ? "_minimap_inset.png" : "minimap.png"));
}
await minimap();
await minimap(true);
for (const [name, svg] of Object.entries(SCREENS)) {
  const withMini = svg.replace('href="minimap.png"', `href="data:image/png;base64,${fs.readFileSync(path.join(OUT, "_minimap_inset.png")).toString("base64")}"`);
  fs.writeFileSync(path.join(OUT, `${name}.svg`), withMini);
  await sharp(Buffer.from(withMini)).png().toFile(path.join(OUT, `${name}.png`));
}
console.log("mockups", Object.keys(SCREENS).length + 1);
