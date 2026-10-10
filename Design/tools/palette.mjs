// node Design/tools/palette.mjs   (needs sharp, like mockups.mjs)
// Design/palette.png from the RetireX colour system of Design/style-guide.md 1 (decision 20-11).
// Keep this table and the style guide in step: the other tools (tiles, icons, mockups) copy these hex values.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const req = createRequire(import.meta.url);
let sharp; try { sharp = req("C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp"); } catch { sharp = req("sharp"); }

export const GROUPS = [
  ["1-1 트랙", [["grass", "#546D33"], ["road", "#15151A"], ["road-alt", "#08090E"], ["edge-line", "#F9C628"], ["curb", "#6C6D67"], ["rail", "#A5A6AB"], ["lane-line", "#EAECED"]]],
  ["1-2 UI", [["ui-night", "#000918"], ["ui-panel", "#010B1A"], ["ui-well", "#0D1729"], ["ui-rim", "#223A60"], ["ui-cyan", "#00F6F9"], ["ui-sky", "#1DB8E6"], ["ui-gold", "#FEDA34"], ["ui-ink", "#F2F9FF"], ["ui-warn", "#FF3236"], ["ui-green", "#56E27A"], ["ui-magenta", "#FF5CD6"]]],
  // swatch order = hue order (decision 20-2); the number is RetireX's colour index (minimap markers)
  ["1-3 카트 도색 (색상환 순)", [["red 1", "#EE4949"], ["orange 14", "#F28C28"], ["yellow 11", "#F7D439"], ["lime 10", "#7BB82A"], ["green 2", "#478143"], ["cyan 6", "#27A5A8"], ["light_blue 12", "#55B9E7"], ["blue 4", "#345CDC"], ["purple 5", "#884BC3"], ["magenta 13", "#C853D5"], ["pink 9", "#EF88AD"], ["brown 3", "#825637"], ["white 15", "#F1F2EE"], ["undyed 16", "#D5DCE5"], ["silver 7", "#A5ADB2"], ["gray 8", "#484D58"], ["black 0", "#252934"]]],
  ["1-4 미니맵", [["mm-road", "#F4F7EC"], ["mm-edge", "#142737"], ["mm-finish", "#22B4DD"]]],
];

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const CW = 120, CH = 104, COLS = 9, PAD = 24;
  let y = PAD, body = "";
  const lum = (h) => { const [r, g, b] = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
  for (const [title, cols] of GROUPS) {
    body += `<text x="${PAD}" y="${y + 22}" font-family="Malgun Gothic" font-size="20" font-weight="700" fill="#F2F9FF">${title}</text>`;
    y += 36;
    cols.forEach(([name, hex], i) => {
      const x = PAD + (i % COLS) * CW, yy = y + Math.floor(i / COLS) * CH, ink = lum(hex) > 0.5 ? "#000918" : "#F2F9FF";
      body += `<rect x="${x}" y="${yy}" width="${CW - 8}" height="${CH - 8}" rx="10" fill="${hex}" stroke="#223A60" stroke-width="2"/>` +
        `<text x="${x + 10}" y="${yy + 28}" font-family="Segoe UI" font-size="15" font-weight="600" fill="${ink}">${name}</text>` +
        `<text x="${x + 10}" y="${yy + CH - 22}" font-family="Consolas, monospace" font-size="14" fill="${ink}" fill-opacity="0.85">${hex}</text>`;
    });
    y += Math.ceil(cols.length / COLS) * CH + 16;
  }
  const W = PAD * 2 + COLS * CW - 8, H = y + PAD - 16;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}"><rect width="100%" height="100%" fill="#010B1A"/>${body}</svg>`;
  await sharp(Buffer.from(svg)).png().toFile(path.join(REPO, "Design/palette.png"));
  console.log("palette", GROUPS.reduce((n, [, c]) => n + c.length, 0), "colours", `${W}x${H}`);
}
