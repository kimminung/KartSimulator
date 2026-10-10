// node Design/tools/icons.mjs
// Pixel icons (design PRD 3, 24 x 24, 2 px strokes, square corners, currentColor), the onboarding
// gestures (PRD 9, 240 x 240, transparent, first-person back-of-hand, accent-blue pinch point,
// 48 x 48 top-view kart below), and the minimap's start flag / checkpoint labels (PRD 6).
// Everything is drawn from pixel masks so it stays on the grid. Previews (_sheet.png) need sharp.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const ICONS = path.join(REPO, "Design/icons"), ONB = path.join(REPO, "Design/onboarding");
for (const d of [ICONS, ONB]) fs.mkdirSync(d, { recursive: true });
// Design/style-guide.md: RetireX UI colours (ink, cyan, warn) and kart colours (kart = marker 1 red, white 15, black 0)
const PAL = { ink: "#F2F9FF", cyan: "#00F6F9", warn: "#FF3236", kart: "#EE4949", white: "#F1F2EE", dark: "#252934", night: "#000918" };

// mask rows: '#' = pixel; returns <rect>s merged per row run
function rects(mask, s = 1, ox = 0, oy = 0, fill = "currentColor") {
  let out = "";
  mask.forEach((row, y) => {
    for (let x = 0; x < row.length;) {
      if (row[x] !== "#") { x++; continue; }
      let x1 = x; while (x1 < row.length && row[x1] === "#") x1++;
      out += `<rect x="${ox + x * s}" y="${oy + y * s}" width="${(x1 - x) * s}" height="${s}" fill="${fill}"/>`;
      x = x1;
    }
  });
  return out;
}
const mirror = (mask) => mask.map((r) => [...r].reverse().join(""));
const svg24 = (body, title) => `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" shape-rendering="crispEdges"><title>${title}</title>${body}</svg>\n`;

// ---- hands (left hand, back of the hand, fingers up: the thumb is on the right) 24 x 24
const HAND_OPEN_L = [
  "........................",
  "..........##............",
  ".......##.##.##.........",
  ".......##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##...##....",
  "....##.##.##.##..###....",
  "....##.##.##.##.###.....",
  "....###########.##......",
  "....##########.##.......",
  "....#############.......",
  "....############........",
  "....############........",
  "....############........",
  ".....##########.........",
  ".....##########.........",
  "......########..........",
  "......########..........",
  "......##....##..........",
  "........................",
];
const HAND_PINCH_L = [
  "........................",
  "........................",
  "........................",
  "...........##...........",
  "...........###..........",
  "............###.........",
  "....##.##....##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.##.........",
  "....##.##.##.###........",
  "....##.##.##..###.......",
  "....##########.##.......",
  "....##########.##.......",
  "....###########.##......",
  "....############........",
  "....############........",
  "....############........",
  ".....##########.........",
  ".....##########.........",
  "......########..........",
  "......########..........",
  "......##....##..........",
  "........................",
];
const pinchDot = (x, y, fill = "currentColor") => `<rect x="${x}" y="${y}" width="3" height="3" fill="${fill}" opacity="0.9"/>`;

// ---- simple shapes on the 24 grid (2 px lines)
const R = (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="currentColor"/>`;
// filled pixel arrow heads (5 rows, 2 px tip widening by 2 per row) on the 24 grid
const HEAD_UP = (y) => [0, 1, 2, 3, 4].map((i) => R(11 - i, y + i, 2 + 2 * i, 1)).join("");
const HEAD_LEFT = (yc) => [0, 1, 2, 3, 4].map((i) => R(3 + i, yc + 1 - 1 - i, 1, 2 + 2 * i)).join("");
const HEAD_RIGHT = (yc) => [0, 1, 2, 3, 4].map((i) => R(20 - i, yc - i, 1, 2 + 2 * i)).join("");
const ICON = {
  hand_left_open: rects(HAND_OPEN_L),
  hand_left_pinch: rects(HAND_PINCH_L) + pinchDot(13, 3),
  hand_right_open: rects(mirror(HAND_OPEN_L)),
  hand_right_pinch: rects(mirror(HAND_PINCH_L)) + pinchDot(8, 3),
  arrow_forward: HEAD_UP(3) + R(11, 8, 2, 13),
  arrow_forward_full: HEAD_UP(2) + HEAD_UP(8) + R(11, 13, 2, 8),
  arrow_left: HEAD_LEFT(9) + R(8, 9, 8, 2) + R(14, 11, 2, 10),
  arrow_right: HEAD_RIGHT(9) + R(8, 9, 8, 2) + R(8, 11, 2, 10),
  spread: R(4, 11, 16, 2) + R(4, 9, 2, 6) + R(18, 9, 2, 6) + R(6, 7, 2, 2) + R(6, 15, 2, 2) + R(16, 7, 2, 2) + R(16, 15, 2, 2),
  stop: R(6, 6, 12, 12),
  flag_checkpoint: R(5, 3, 2, 18) + R(7, 3, 12, 2) + R(7, 5, 10, 2) + R(7, 7, 12, 2) + R(7, 9, 10, 2) + R(3, 19, 6, 2),
  flag_finish: R(5, 3, 2, 18) + R(7, 3, 3, 3) + R(13, 3, 3, 3) + R(10, 6, 3, 3) + R(16, 6, 3, 3) + R(7, 9, 3, 3) + R(13, 9, 3, 3) + `<rect x="7" y="3" width="12" height="9" fill="none" stroke="currentColor" stroke-width="1"/>` + R(3, 19, 6, 2),
  play: R(7, 5, 2, 14) + R(9, 7, 2, 10) + R(11, 8, 2, 8) + R(13, 9, 2, 6) + R(15, 10, 2, 4) + R(17, 11, 1, 2),
  pause: R(7, 5, 4, 14) + R(13, 5, 4, 14),
  restart: R(6, 6, 10, 2) + R(4, 8, 2, 8) + R(6, 16, 12, 2) + R(18, 8, 2, 8) + R(16, 6, 2, 2) + R(13, 2, 2, 2) + R(15, 4, 2, 2) + R(13, 8, 2, 2),
  hand_missing: [0, 1, 2, 3, 4, 5].map((i) => R(4 + i * 3, 4, 2, 2) + R(4 + i * 3, 18, 2, 2)).join("") + [0, 1, 2, 3, 4].map((i) => R(4, 6 + i * 3, 2, 2) + R(18, 6 + i * 3, 2, 2)).join("") + R(11, 7, 2, 6) + R(11, 14, 2, 2),
};
for (const [name, body] of Object.entries(ICON)) fs.writeFileSync(path.join(ICONS, `icon_${name}.svg`), svg24(body, name));

// ---- minimap marks (PRD 6): start flag (checker), checkpoint labels 1-3 (round, digit)
const DIGIT = { 1: [".##.", "###.", ".##.", ".##.", ".##.", ".##.", "####"], 2: ["###.", "...#", "...#", ".##.", "#...", "#...", "####"], 3: ["###.", "...#", "...#", ".##.", "...#", "...#", "###."] };
fs.writeFileSync(path.join(ICONS, "icon_minimap_start_flag.svg"), svg24(R(5, 3, 2, 18) + `<rect x="7" y="3" width="12" height="9" fill="${PAL.white}"/>` + [[7, 3], [13, 3], [10, 6], [16, 6], [7, 9], [13, 9]].map(([x, y]) => `<rect x="${x}" y="${y}" width="3" height="3" fill="${PAL.dark}"/>`).join("") + R(3, 19, 6, 2), "minimap_start_flag"));
for (const n of [1, 2, 3]) {
  const disc = ["........", "..####..", ".######.", "########", "########", "########", "########", ".######.", "..####..", "........"];
  const body = `<g class="label-bg" fill="currentColor">${rects(["....######....", "..##########..", ".############.", "##############", "##############", "##############", "##############", "##############", "##############", "##############", ".############.", "..##########..", "....######...."], 1.5, 1.5, 2.25)}</g>` + rects(DIGIT[n], 2, 8, 5, PAL.night);
  fs.writeFileSync(path.join(ICONS, `icon_minimap_checkpoint_${n}.svg`), svg24(body, `minimap_checkpoint_${n} (fill = currentColor: hud-ink 40 % before, accent-blue after passing)`));
}

// ---- onboarding gestures 240 x 240 (PRD 9)
const KART = [ // 16 x 16 top view, nose up (x3 = 48): R body, C cream stripe/spoiler, D wheels/cockpit
  "......RRRR......", ".....RRCCRR.....", ".DD.RRRCCRRR.DD.", ".DD.RRRCCRRR.DD.", ".DD.RRRCCRRR.DD.", "....RRRRRRRR....", "....RRDDDDRR....", "....RRDDDDRR....",
  "....RRDDDDRR....", "....RRRRRRRR....", ".DD.RRRRRRRR.DD.", ".DD.RRRRRRRR.DD.", ".DD.RRRRRRRR.DD.", "....RRRRRRRR....", "...CCCCCCCCCC...", "................",
];
const KART_COL = (x, y) => ({ R: PAL.kart, C: PAL.white, D: PAL.dark })[KART[y][x]] || null;
function kartSvg(ox, oy, rot = 0) {
  let s = `<g transform="rotate(${rot} ${ox + 24} ${oy + 24})">`;
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) { const c = KART_COL(x, y); if (c) s += `<rect x="${ox + x * 3}" y="${oy + y * 3}" width="3" height="3" fill="${c}"/>`; }
  return s + "</g>";
}
const hand = (mask, ox, oy, pinch) => `<g fill="${PAL.ink}">${rects(mask, 4, ox, oy, PAL.ink)}</g>` + (pinch ? `<circle cx="${ox + pinch[0] * 4 + 4}" cy="${oy + pinch[1] * 4 + 4}" r="7" fill="${PAL.cyan}"/>` : "");
const arrowH = (x, y, w, dir) => `<rect x="${x}" y="${y}" width="${w}" height="4" fill="${PAL.cyan}"/>` + (dir.includes("l") ? `<polygon points="${x - 8},${y + 2} ${x + 2},${y - 6} ${x + 2},${y + 10}" fill="${PAL.cyan}"/>` : "") + (dir.includes("r") ? `<polygon points="${x + w + 8},${y + 2} ${x + w - 2},${y - 6} ${x + w - 2},${y + 10}" fill="${PAL.cyan}"/>` : "");
const turnArrow = (x, y, dir) => dir === "l"
  ? `<path d="M${x + 14} ${y + 26} V${y + 8} H${x}" fill="none" stroke="${PAL.cyan}" stroke-width="4"/><polygon points="${x - 6},${y + 8} ${x + 2},${y} ${x + 2},${y + 16}" fill="${PAL.cyan}"/>`
  : `<path d="M${x} ${y + 26} V${y + 8} H${x + 14}" fill="none" stroke="${PAL.cyan}" stroke-width="4"/><polygon points="${x + 20},${y + 8} ${x + 12},${y} ${x + 12},${y + 16}" fill="${PAL.cyan}"/>`;
const G = {
  gesture_01_forward: hand(HAND_PINCH_L, 8, 20, [13, 3]) + hand(mirror(HAND_PINCH_L), 136, 20, [10, 3]) + arrowH(82, 70, 76, "lr") + kartSvg(96, 176, 0) + `<polygon points="120,160 112,172 128,172" fill="${PAL.cyan}"/>`,
  gesture_02_left: hand(HAND_PINCH_L, 8, 20, [13, 3]) + hand(mirror(HAND_OPEN_L), 136, 20) + kartSvg(96, 176, -30) + turnArrow(56, 150, "l"),
  gesture_03_right: hand(HAND_OPEN_L, 8, 20) + hand(mirror(HAND_PINCH_L), 136, 20, [10, 3]) + kartSvg(96, 176, 30) + turnArrow(166, 150, "r"),
  gesture_04_stop: hand(HAND_OPEN_L, 8, 20) + hand(mirror(HAND_OPEN_L), 136, 20) + kartSvg(96, 176, 0) + `<rect x="152" y="188" width="24" height="24" fill="${PAL.ink}"/>`,
};
for (const [name, body] of Object.entries(G)) fs.writeFileSync(path.join(ONB, `${name}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240" shape-rendering="crispEdges"><title>${name}</title>${body}</svg>\n`);

// ---- previews (need sharp)
let sharp = null;
try { sharp = createRequire(import.meta.url)("C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp"); } catch { try { sharp = createRequire(import.meta.url)("sharp"); } catch {} }
if (sharp) {
  const names = fs.readdirSync(ICONS).filter((f) => f.endsWith(".svg")).sort();
  const cols = 6, cell = 150, rows = Math.ceil(names.length / cols);
  let sheet = `<svg xmlns="http://www.w3.org/2000/svg" width="${cols * cell}" height="${rows * cell}"><rect width="100%" height="100%" fill="#010B1A"/>`;
  names.forEach((f, i) => {
    const x = (i % cols) * cell, y = Math.floor(i / cols) * cell;
    const inner = fs.readFileSync(path.join(ICONS, f), "utf8").replace(/<\?xml[^>]*>/, "").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, "");
    const col = /checkpoint_2/.test(f) ? PAL.cyan : /checkpoint/.test(f) ? "rgba(255,255,255,0.4)" : /pinch/.test(f) ? PAL.cyan : /missing/.test(f) ? PAL.warn : PAL.ink;
    sheet += `<g transform="translate(${x + 39} ${y + 22}) scale(3)" color="${col}" style="color:${col}">${inner}</g><text x="${x + cell / 2}" y="${y + 120}" font-family="Segoe UI" font-size="11" fill="#c8d2dc" text-anchor="middle">${f.replace("icon_", "").replace(".svg", "")}</text>`;
  });
  sheet += "</svg>";
  await sharp(Buffer.from(sheet)).png().toFile(path.join(ICONS, "_sheet.png"));
  const g = Object.keys(G);
  let gs = `<svg xmlns="http://www.w3.org/2000/svg" width="${g.length * 260}" height="300"><rect width="100%" height="100%" fill="#010B1A"/>`;
  const caption = ["양손을 핀치하고 벌리면 전진", "왼손만 핀치하면 좌회전", "오른손만 핀치하면 우회전", "양손을 떼면 멈춤"];
  g.forEach((n, i) => { const inner = fs.readFileSync(path.join(ONB, n + ".svg"), "utf8").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, ""); gs += `<g transform="translate(${i * 260 + 10} 10)">${inner}</g><text x="${i * 260 + 130}" y="280" font-family="Malgun Gothic" font-size="15" fill="#e6edf3" text-anchor="middle">${caption[i]}</text>`; });
  gs += "</svg>";
  await sharp(Buffer.from(gs)).png().toFile(path.join(ONB, "_sheet.png"));
}
console.log("icons", Object.keys(ICON).length + 4, "gestures", Object.keys(G).length, sharp ? "previews ok" : "no sharp: previews skipped");
