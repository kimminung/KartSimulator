// node Design/tools/textures.mjs   (sharp only for the labelled preview)
// 16 x 16 stand-in voxel textures (decision 21: no Mojang textures in this app, not even for a while).
// Drawn here from seeded noise and simple patterns in Design/style-guide.md colours — no file of
// anyone else is read. They cover what the RetireX tracks show most (Design/reference/retirex/
// textures/TEXTURES.md 4): grass, soil, stone, walls, water, wood, leaves, glass, metal, roofs.
//   Design/textures/tex_<name>.png   16 x 16 (RGBA; only glass has alpha)
//   Design/textures/_sheet.png        8x preview with names
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const OUT = path.join(REPO, "Design/textures");
fs.mkdirSync(OUT, { recursive: true });

const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc = (buf) => { let c = -1; for (const x of buf) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}
const hex = (h, a = 255) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)).concat(a);
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32); }

// each painter gets (x, y, r) and returns a colour; r() is a seeded random per texture
const N = 16;
const speckle = (base, light, dark, pl = 0.18, pd = 0.18) => (x, y, r) => { const v = r(); return v < pl ? light : v < pl + pd ? dark : base; };
const TEX = {
  grass_top: speckle(hex("#546D33"), hex("#647F3C"), hex("#47602B"), 0.22, 0.2),
  grass_side: (x, y, r) => { const edge = 3 + ((x * 7 + 3) % 3 === 0 ? 1 : 0); return y < edge ? speckle(hex("#546D33"), hex("#647F3C"), hex("#47602B"))(x, y, r) : speckle(hex("#7A5A3A"), hex("#8A6944"), hex("#664A30"))(x, y, r); },
  dirt: speckle(hex("#7A5A3A"), hex("#8A6944"), hex("#664A30"), 0.2, 0.2),
  stone: (x, y, r) => { const b = (Math.sin(x * 0.9 + y * 0.4) + Math.sin(y * 1.3 - x * 0.5)) > 1.1; return b ? hex("#8A8B86") : speckle(hex("#7B7C77"), hex("#858681"), hex("#6E6F6A"), 0.12, 0.12)(x, y, r); },
  stone_bricks: (x, y, r) => { const row = Math.floor(y / 4), off = row % 2 ? 4 : 0; return y % 4 === 3 || (x + off) % 8 === 7 ? hex("#5E5F5B") : speckle(hex("#8A8B86"), hex("#93948F"), hex("#80817C"), 0.1, 0.1)(x, y, r); },
  plaster_white: speckle(hex("#ECEAE2"), hex("#F4F2EB"), hex("#DFDCD2"), 0.1, 0.12),
  sandstone: (x, y, r) => (y % 5 === 4 ? hex("#C7B27A") : speckle(hex("#D9C690"), hex("#E0CF9C"), hex("#CFBB85"), 0.12, 0.12)(x, y, r)),
  brick: (x, y, r) => { const row = Math.floor(y / 4), off = row % 2 ? 4 : 0; return y % 4 === 3 || (x + off) % 8 === 7 ? hex("#CBBCAB") : speckle(hex("#9C4B3A"), hex("#A85646"), hex("#8C4031"), 0.12, 0.1)(x, y, r); },
  roof_tile: (x, y, r) => { const row = Math.floor(y / 4), dx = ((x + (row % 2 ? 2 : 0)) % 4) - 1.5, dy = (y % 4); return dy === 3 || (dy >= 2 && Math.abs(dx) > 1) ? hex("#9E4A24") : speckle(hex("#C8642E"), hex("#D27238"), hex("#B85A28"), 0.1, 0.1)(x, y, r); },
  planks: (x, y, r) => { const row = Math.floor(y / 4), seam = (row * 5 + 3) % 16; return y % 4 === 3 || x === seam ? hex("#7E5C36") : speckle(hex("#A47A4A"), hex("#AE8452"), hex("#966E41"), 0.1, 0.14)(x, y, r); },
  log_side: (x, y, r) => (x % 4 === 0 || (x % 4 === 2 && r() < 0.35) ? hex("#4E3A27") : speckle(hex("#6A5036"), hex("#75593C"), hex("#5E4630"), 0.1, 0.15)(x, y, r)),
  leaves: (x, y, r) => { const v = r(); return v < 0.28 ? hex("#2F5226") : v < 0.5 ? hex("#4F7F38") : hex("#3F6A2E"); },
  water: (x, y, r) => { const w = (x + Math.round(2 * Math.sin(y * 0.8))) % 8; return w < 3 && y % 4 === 1 ? hex("#5C9BEA") : speckle(hex("#3577D6"), hex("#3F82DE"), hex("#2E6BC6"), 0.08, 0.08)(x, y, r); },
  glass: (x, y) => (x === 0 || y === 0 || x === N - 1 || y === N - 1 ? hex("#E6F4F7", 230) : x - y === 4 || x - y === 6 ? hex("#FFFFFF", 150) : hex("#BFE0E8", 70)),
  metal: (x, y) => ((x === 1 || x === 14) && (y === 1 || y === 14) ? hex("#8C939B") : x === 0 || y === 0 ? hex("#CDD2D7") : x === N - 1 || y === N - 1 ? hex("#9AA1A8") : hex("#B6BBC1")),
};
// the mortar / seam colour of tiling textures repeats across tile edges: draw on a wrap-around grid
const names = Object.keys(TEX);
names.forEach((name, k) => {
  const r = rng(1009 * (k + 1)), buf = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) buf.set(TEX[name](x, y, r), (y * N + x) * 4);
  fs.writeFileSync(path.join(OUT, `tex_${name}.png`), png(N, N, buf));
});

// preview: each texture 2 x 2 tiled at 4x (shows the seams) with its name
let sharp = null;
try { sharp = createRequire(import.meta.url)("C:/Users/minsi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp"); } catch { try { sharp = createRequire(import.meta.url)("sharp"); } catch {} }
if (sharp) {
  const cols = 5, cell = 160, rows = Math.ceil(names.length / cols);
  let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${cols * cell}" height="${rows * (cell + 24)}"><rect width="100%" height="100%" fill="#010B1A"/>`;
  names.forEach((n, i) => {
    const x = (i % cols) * cell + 16, y = Math.floor(i / cols) * (cell + 24) + 12, b64 = fs.readFileSync(path.join(OUT, `tex_${n}.png`)).toString("base64");
    for (const [dx, dy] of [[0, 0], [64, 0], [0, 64], [64, 64]]) svg += `<image href="data:image/png;base64,${b64}" x="${x + dx}" y="${y + dy}" width="64" height="64" style="image-rendering:pixelated" preserveAspectRatio="none"/>`;
    svg += `<text x="${x}" y="${y + 150}" font-family="Segoe UI" font-size="14" fill="#F2F9FF">tex_${n}</text>`;
  });
  svg += "</svg>";
  await sharp(Buffer.from(svg)).png().toFile(path.join(OUT, "_sheet.png"));
}
console.log("textures", names.length, sharp ? "sheet ok" : "no sharp: sheet skipped");
