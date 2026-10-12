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
const PAL = { ink: "#F2F9FF", cyan: "#00F6F9", magenta: "#FF5CD6", warn: "#FF3236", kart: "#EE4949", white: "#F1F2EE", dark: "#252934", night: "#000918" };

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
const HEAD_DOWN = (y) => [0, 1, 2, 3, 4].map((i) => R(11 - i, y - i, 2 + 2 * i, 1)).join("");
const HEAD_LEFT = (yc) => [0, 1, 2, 3, 4].map((i) => R(3 + i, yc + 1 - 1 - i, 1, 2 + 2 * i)).join("");
const HEAD_RIGHT = (yc) => [0, 1, 2, 3, 4].map((i) => R(20 - i, yc - i, 1, 2 + 2 * i)).join("");
const ICON = {
  hand_left_open: rects(HAND_OPEN_L),
  hand_left_pinch: rects(HAND_PINCH_L) + pinchDot(13, 3),
  hand_right_open: rects(mirror(HAND_OPEN_L)),
  hand_right_pinch: rects(mirror(HAND_PINCH_L)) + pinchDot(8, 3),
  arrow_forward: HEAD_UP(3) + R(11, 8, 2, 13),
  arrow_reverse: HEAD_DOWN(20) + R(11, 3, 2, 13), // pedal < 0 (decision 31: pinch out = reverse)
  arrow_left: HEAD_LEFT(9) + R(8, 9, 8, 2) + R(14, 11, 2, 10),
  arrow_right: HEAD_RIGHT(9) + R(8, 9, 8, 2) + R(8, 11, 2, 10),
  spread: R(4, 11, 16, 2) + R(4, 9, 2, 6) + R(18, 9, 2, 6) + R(6, 7, 2, 2) + R(6, 15, 2, 2) + R(16, 7, 2, 2) + R(16, 15, 2, 2), // pinch out: hands apart -> reverse
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
const kartUp = `<polygon points="120,160 112,172 128,172" fill="${PAL.cyan}"/>`, kartDown = `<polygon points="120,238 112,226 128,226" fill="${PAL.magenta}"/>`;
// dotted line joining the two pinch points: "keep the pinch where it started" (decision 39 diorama forward)
// (dashes are plain rects, not stroke-dasharray, so Xcode's SVG importer cannot drop them)
const holdLine = (x1, x2, y) => { let s = ""; for (let x = x1; x + 4 <= x2; x += 10) s += `<rect x="${x}" y="${y - 1}" width="4" height="3" fill="${PAL.cyan}" fill-opacity="0.7"/>`; return s; };
// "no reverse" badge (3rd person forward, PRD 9 / decision 39): small ui-magenta down arrow with a hud-ink slash
const noReverse = (x, y) => `<g transform="translate(${x} ${y}) scale(2)" color="${PAL.magenta}" style="color:${PAL.magenta}">${ICON.arrow_reverse}</g>` + `<line x1="${x + 6}" y1="${y + 42}" x2="${x + 42}" y2="${y + 6}" stroke="${PAL.ink}" stroke-width="5"/>`;
// gradual turn: dashed arc from the kart's nose bending to the side, arrow head along the tangent
const gentleArc = (dir) => {
  const m = dir === "r" ? 1 : -1, ex = 120 + m * 34, ey = 126, P0 = [120, 168], P1 = [120, 136], P2 = [ex, ey];
  const q = (t) => [0, 1].map((i) => (1 - t) ** 2 * P0[i] + 2 * (1 - t) * t * P1[i] + t * t * P2[i]);
  // the quadratic curve is sampled into short stroked pieces (dash 8 / gap 6 in parameter space ~ 56 px long)
  let s = "", n = 14;
  for (let k = 0; k < n; k += 2) { const a = q(k / n), b = q(Math.min((k + 1.15) / n, 1)); s += `<path d="M${a[0].toFixed(1)} ${a[1].toFixed(1)} L${b[0].toFixed(1)} ${b[1].toFixed(1)}" fill="none" stroke="${PAL.cyan}" stroke-width="4"/>`; }
  const ang = (Math.atan2(-10, m * 34) * 180) / Math.PI;
  return s + `<polygon transform="translate(${ex} ${ey}) rotate(${ang})" points="10,0 -2,-8 -2,8" fill="${PAL.cyan}"/>`;
};
// multi-colour pixel mask: each char maps to a fill
function pix(mask, map, s, ox, oy, opacity = 1) {
  let out = "";
  mask.forEach((row, y) => {
    for (let x = 0; x < row.length;) {
      const c = row[x]; if (!map[c]) { x++; continue; }
      let x1 = x; while (x1 < row.length && row[x1] === c) x1++;
      // the hairline stroke hides anti-aliasing seams between rows once the group is rotated
      out += `<rect x="${ox + x * s}" y="${oy + y * s}" width="${(x1 - x) * s}" height="${s}" fill="${map[c]}" stroke="${map[c]}" stroke-width="0.6"${opacity < 1 ? ` opacity="${opacity}"` : ""}/>`;
      x = x1;
    }
  });
  return out;
}
// head seen from above wearing the headset, nose up: H = head (hud-ink), V = visor + strap (black 0), 24 x 24
const HEAD_TOP = [
  "........................",
  "........................",
  "......VVVVVVVVVVVV......",
  ".....VVVVVVVVVVVVVV.....",
  ".....VVVVVVVVVVVVVV.....",
  ".....VVVVVVVVVVVVVV.....",
  ".....VVHHHHHHHHHHVV.....",
  "......VHHHHHHHHHHV......",
  "......VHHHHHHHHHHV......",
  "....HHHHHHHHHHHHHHHH....",
  "....HHHHHHHHHHHHHHHH....",
  "....HHHHHHHHHHHHHHHH....",
  "....HHHHHHHHHHHHHHHH....",
  "......HHHHHHHHHHHH......",
  "......HHHHHHHHHHHH......",
  "......HHHHHHHHHHHH......",
  ".......HHHHHHHHHH.......",
  "........HHHHHHHH........",
  ".........VVVVVV.........",
  "........................",
];
const HEAD_COL = { H: PAL.ink, V: PAL.dark };
// head group: head at scale 3 (72 px) + ui-cyan arrow out of the visor, the whole thing rotated by `rot` around the head centre
// the visor's front edge gets a ui-cyan glass line so the facing direction reads on dark and light backgrounds alike
const headSvg = (cx, cy, rot) => `<g transform="rotate(${rot} ${cx} ${cy})">${pix(HEAD_TOP, HEAD_COL, 3, cx - 36, cy - 30)}` +
  `<rect x="${cx - 18}" y="${cy - 24}" width="36" height="3" fill="${PAL.cyan}"/>` +
  `<rect x="${cx - 2}" y="${cy - 60}" width="4" height="36" fill="${PAL.cyan}"/><polygon points="${cx},${cy - 72} ${cx - 10},${cy - 58} ${cx + 10},${cy - 58}" fill="${PAL.cyan}"/></g>`;
// small vertical arrows for throttle (ui-cyan up = accelerate, hud-ink 40 % down = coast)
const arrowV = (x, y, h, dir, col, op = 1) => `<g fill-opacity="${op}"><rect x="${x - 2}" y="${y}" width="4" height="${h}" fill="${col}"/>` +
  (dir === "u" ? `<polygon points="${x},${y - 10} ${x - 9},${y + 2} ${x + 9},${y + 2}" fill="${col}"/>` : `<polygon points="${x},${y + h + 10} ${x - 9},${y + h - 2} ${x + 9},${y + h - 2}" fill="${col}"/>`) + "</g>";
const stopBlock = `<rect x="152" y="188" width="24" height="24" fill="${PAL.ink}"/>`;

// Three driving modes (decision 39). Hands sit at the same resting spots (x 8 / 136) in every card so the eye only
// has to read what changed: pinch dot, spacing, arrows.
const G = {
  // -- diorama: both hands pinched and held = forward; still pinched but spread apart = reverse; one hand only = turn
  gesture_01_forward: hand(HAND_PINCH_L, 8, 20, [13, 3]) + hand(mirror(HAND_PINCH_L), 136, 20, [10, 3]) + holdLine(76, 168, 36) + kartSvg(96, 176, 0) + kartUp,
  gesture_02_reverse: hand(HAND_PINCH_L, -12, 20, [13, 3]) + hand(mirror(HAND_PINCH_L), 156, 20, [10, 3]) + arrowH(76, 132, 30, "l").replaceAll(PAL.cyan, PAL.magenta) + arrowH(134, 132, 30, "r").replaceAll(PAL.cyan, PAL.magenta) + kartSvg(96, 172, 0) + kartDown,
  gesture_03_left: hand(HAND_PINCH_L, 8, 20, [13, 3]) + hand(mirror(HAND_OPEN_L), 136, 20) + kartSvg(96, 176, -30) + turnArrow(56, 150, "l"),
  gesture_04_right: hand(HAND_OPEN_L, 8, 20) + hand(mirror(HAND_PINCH_L), 136, 20, [10, 3]) + kartSvg(96, 176, 30) + turnArrow(166, 150, "r"),
  gesture_05_stop: hand(HAND_OPEN_L, 8, 20) + hand(mirror(HAND_OPEN_L), 136, 20) + kartSvg(96, 176, 0) + stopBlock,
};
const G_ROWS = [ // preview sheet rows: [names, captions] per mode (captions = ContentView OnboardingView, decision 39)
  [["gesture_01_forward", "gesture_02_reverse", "gesture_03_left", "gesture_04_right", "gesture_05_stop"], ["양손을 핀치한 채로 있으면 전진", "핀치한 채로 양손을 벌리면 후진", "오른손을 떼면(왼손만 핀치) 좌회전", "왼손을 떼면(오른손만 핀치) 우회전", "양손을 떼면 멈춤"], "디오라마·3인칭"],
];
for (const old of ["gesture_02_left", "gesture_03_right", "gesture_04_stop", "gesture_fp_01_steer", "gesture_fp_02_throttle", "gesture_tp_01_forward", "gesture_tp_02_left", "gesture_tp_03_right", "gesture_tp_04_stop"]) fs.rmSync(path.join(ONB, old + ".svg"), { force: true });
for (const old of ["icon_arrow_forward_full", "icon_pinch_in"]) fs.rmSync(path.join(ICONS, old + ".svg"), { force: true });
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
    const col = /checkpoint_2/.test(f) ? PAL.cyan : /checkpoint/.test(f) ? "rgba(255,255,255,0.4)" : /pinch/.test(f) ? PAL.cyan : /missing/.test(f) ? PAL.warn : /reverse|spread/.test(f) ? PAL.magenta : PAL.ink;
    sheet += `<g transform="translate(${x + 39} ${y + 22}) scale(3)" color="${col}" style="color:${col}">${inner}</g><text x="${x + cell / 2}" y="${y + 120}" font-family="Segoe UI" font-size="11" fill="#c8d2dc" text-anchor="middle">${f.replace("icon_", "").replace(".svg", "")}</text>`;
  });
  sheet += "</svg>";
  await sharp(Buffer.from(sheet)).png().toFile(path.join(ICONS, "_sheet.png"));
  // one row per driving mode, mode name on the left margin
  const rowH = 330, left = 120, gcols = Math.max(...G_ROWS.map(([n]) => n.length));
  let gs = `<svg xmlns="http://www.w3.org/2000/svg" width="${left + gcols * 260}" height="${G_ROWS.length * rowH}"><rect width="100%" height="100%" fill="#010B1A"/>`;
  G_ROWS.forEach(([names, caption, mode], r) => {
    const y0 = r * rowH + 20;
    gs += `<text x="24" y="${y0 + 130}" font-family="Malgun Gothic, Apple SD Gothic Neo, sans-serif" font-size="20" font-weight="700" fill="${PAL.cyan}">${mode}</text>`;
    if (r) gs += `<rect x="24" y="${r * rowH - 1}" width="${left + gcols * 260 - 48}" height="1" fill="#223A60"/>`;
    names.forEach((n, i) => {
      const inner = fs.readFileSync(path.join(ONB, n + ".svg"), "utf8").replace(/<svg[^>]*>/, "").replace("</svg>", "").replace(/<title>.*?<\/title>/, "");
      const x = left + i * 260;
      gs += `<g transform="translate(${x + 10} ${y0})">${inner}</g><text x="${x + 130}" y="${y0 + 272}" font-family="Malgun Gothic, Apple SD Gothic Neo, sans-serif" font-size="15" fill="#e6edf3" text-anchor="middle">${caption[i]}</text><text x="${x + 130}" y="${y0 + 294}" font-family="Consolas, Menlo, monospace" font-size="11" fill="#8a97a6" text-anchor="middle">${n}</text>`;
    });
  });
  gs += "</svg>";
  await sharp(Buffer.from(gs)).png().toFile(path.join(ONB, "_sheet.png"));
}
console.log("icons", Object.keys(ICON).length + 4, "gestures", Object.keys(G).length, sharp ? "previews ok" : "no sharp: previews skipped");
