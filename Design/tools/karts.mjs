// node Design/tools/karts.mjs [<RetireX resource pack>]
// Kart images for the five-kart roster (decision 20-1, 20-7), made from RetireX Online's own kart
// assets (decision 20-12: the designer's project; no Mojang material is involved):
//   Design/karts/kart_<id>_thumb.png       menu card picture: RetireX garage render, scaled by a whole
//                                          number (nearest) onto a 512 x 384 transparent canvas
//   Design/karts/kart_<id>_silhouette.svg  24 x 24 pixel side silhouette for HUD / minimap / small lists,
//                                          fill = currentColor (the code paints the kart colour)
//   Design/karts/_sheet.png                review sheet: thumbnails + silhouettes at 4x
// The silhouette is drawn from the kart's Bedrock geometry (models/entity/<id>.json): every cube is
// rotated with its bone chain, projected onto the side plane (front = -Z, drawn facing right) and the
// coverage is sampled onto the 24 px grid. Re-run after a kart model changes.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const RP = process.argv[2] || "D:/RetireX/RetireX_Online_Addon/development_resource_packs/RetireX_Online_RP";
const OUT = path.join(REPO, "Design/karts");
const ROSTER = ["arcrix", "bogubkart", "gospel", "razr", "sirius"];
// bones that only carry effects or anchors (flames, plumes, particles) are not part of the body outline
const SKIP_BONE = /plume|flame|particle|vfx|anchor|petal/i;
fs.mkdirSync(OUT, { recursive: true });

// ---- PNG in/out (RGBA, 8 bit, no dependencies)
function readPng(file) {
  const b = fs.readFileSync(file);
  let p = 8, w, h, ct, bd, pal = null, trns = null; const idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), type = b.toString("ascii", p + 4, p + 8), d = b.subarray(p + 8, p + 8 + len);
    if (type === "IHDR") { w = d.readUInt32BE(0); h = d.readUInt32BE(4); bd = d[8]; ct = d[9]; }
    else if (type === "PLTE") pal = d; else if (type === "tRNS") trns = d; else if (type === "IDAT") idat.push(d);
    p += 12 + len;
  }
  if (bd !== 8) throw new Error(`${file}: bit depth ${bd} not supported`);
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[ct], raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * ch;
  const out = Buffer.alloc(w * h * 4), prev = Buffer.alloc(stride), cur = Buffer.alloc(stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)]; raw.copy(cur, 0, y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? cur[x - ch] : 0, up = prev[x], c = x >= ch ? prev[x - ch] : 0;
      let v = cur[x];
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pp = a + up - c, pa = Math.abs(pp - a), pb = Math.abs(pp - up), pc = Math.abs(pp - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c; }
      cur[x] = v & 255;
    }
    for (let x = 0; x < w; x++) {
      const i = x * ch; let px;
      if (ct === 0) px = [cur[i], cur[i], cur[i], 255]; else if (ct === 4) px = [cur[i], cur[i], cur[i], cur[i + 1]];
      else if (ct === 2) px = [cur[i], cur[i + 1], cur[i + 2], 255]; else if (ct === 6) px = [cur[i], cur[i + 1], cur[i + 2], cur[i + 3]];
      else { const k = cur[i]; px = [pal[k * 3], pal[k * 3 + 1], pal[k * 3 + 2], trns && k < trns.length ? trns[k] : 255]; }
      out.set(px, (y * w + x) * 4);
    }
    cur.copy(prev);
  }
  return { w, h, data: out };
}
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc = (buf) => { let c = -1; for (const x of buf) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function writePng(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]));
}

// ---- thumbnail: whole-number nearest scale onto 512 x 320, centred
function thumb(src) {
  const W = 512, H = 384, s = Math.max(1, Math.floor(Math.min(W / src.w, H / src.h)));
  const out = Buffer.alloc(W * H * 4), ox = Math.floor((W - src.w * s) / 2), oy = Math.floor((H - src.h * s) / 2);
  for (let y = 0; y < src.h * s; y++) for (let x = 0; x < src.w * s; x++) {
    const tx = ox + x, ty = oy + y; if (tx < 0 || ty < 0 || tx >= W || ty >= H) continue;
    src.data.copy(out, (ty * W + tx) * 4, (Math.floor(y / s) * src.w + Math.floor(x / s)) * 4, (Math.floor(y / s) * src.w + Math.floor(x / s)) * 4 + 4);
  }
  return { w: W, h: H, data: out, scale: s };
}

// ---- silhouette from geometry
const rad = (d) => (d * Math.PI) / 180;
// Bedrock JSON rotations: X and Z turn the other way from a right-handed rotation, Y as written;
// applied x, then y, then z (the format's order — the other order flings tilted parts metres away)
function rotate(p, rot, pivot) {
  if (!rot) return p;
  let [x, y, z] = [p[0] - pivot[0], p[1] - pivot[1], p[2] - pivot[2]];
  const [ax, ay, az] = [rad(-rot[0]), rad(rot[1]), rad(-rot[2])];
  [y, z] = [y * Math.cos(ax) - z * Math.sin(ax), y * Math.sin(ax) + z * Math.cos(ax)];
  [x, z] = [x * Math.cos(ay) + z * Math.sin(ay), -x * Math.sin(ay) + z * Math.cos(ay)];
  [x, y] = [x * Math.cos(az) - y * Math.sin(az), x * Math.sin(az) + y * Math.cos(az)];
  return [x + pivot[0], y + pivot[1], z + pivot[2]];
}
function sidePolys(geo) {
  const bones = Object.fromEntries(geo.bones.map((b) => [b.name, b]));
  const skipped = (b) => { for (let c = b; c; c = bones[c.parent]) if (SKIP_BONE.test(c.name)) return true; return false; };
  const polys = [];
  for (const b of geo.bones) {
    if (skipped(b)) continue;
    for (const c of b.cubes || []) {
      const inf = c.inflate || 0, o = c.origin.map((v) => v - inf), s = c.size.map((v) => v + 2 * inf);
      let pts = [];
      for (let i = 0; i < 8; i++) pts.push([o[0] + (i & 1 ? s[0] : 0), o[1] + (i & 2 ? s[1] : 0), o[2] + (i & 4 ? s[2] : 0)]);
      if (c.rotation) pts = pts.map((p) => rotate(p, c.rotation, c.pivot || [0, 0, 0]));
      for (let bb = b; bb; bb = bones[bb.parent]) if (bb.rotation) pts = pts.map((p) => rotate(p, bb.rotation, bb.pivot || [0, 0, 0]));
      polys.push(hull(pts.map((p) => [-p[2], -p[1]]))); // front (-Z) to the right, up = -y on screen
    }
  }
  return polys;
}
function hull(pts) {
  pts = pts.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lo = [], up = [];
  for (const p of pts) { while (lo.length >= 2 && cross(lo.at(-2), lo.at(-1), p) <= 0) lo.pop(); lo.push(p); }
  for (const p of pts.reverse()) { while (up.length >= 2 && cross(up.at(-2), up.at(-1), p) <= 0) up.pop(); up.push(p); }
  return lo.slice(0, -1).concat(up.slice(0, -1));
}
const inside = (poly, x, y) => { let r = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) r = !r; } return r; };
function silhouette(polys, N = 24, margin = 1, SS = 8) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of polys) for (const [x, y] of p) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const span = Math.max(x1 - x0, y1 - y0), u = span / (N - 2 * margin); // model units per pixel
  const offX = margin + ((N - 2 * margin) - (x1 - x0) / u) / 2, offY = N - margin - (y1 - y0) / u; // sit on the bottom edge
  const cov = new Float64Array(N * N);
  for (let py = 0; py < N; py++) for (let px = 0; px < N; px++) {
    let hit = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const mx = x0 + (px - offX + (sx + 0.5) / SS) * u, my = y0 + (py - offY + (sy + 0.5) / SS) * u;
      if (polys.some((p) => inside(p, mx, my))) hit++;
    }
    cov[py * N + px] = hit / (SS * SS);
  }
  const on = Array.from(cov, (c) => c >= 0.3); // 0.3 keeps seat backs and steering posts; 0.4 loses them
  // drop single pixels with no 4-neighbour (antenna tips, slivers): they flicker at HUD size
  const keep = on.map((v, i) => v && [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => { const x = (i % N) + dx, y = Math.floor(i / N) + dy; return x >= 0 && y >= 0 && x < N && y < N && on[y * N + x]; }));
  return { N, on: keep };
}
function svg({ N, on }) {
  const rects = [];
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    if (!on[y * N + x] || (x > 0 && on[y * N + x - 1])) continue;
    let w = 1; while (x + w < N && on[y * N + x + w]) w++;
    rects.push(`<rect x="${x}" y="${y}" width="${w}" height="1"/>`);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${N}" height="${N}" viewBox="0 0 ${N} ${N}" shape-rendering="crispEdges" fill="currentColor">\n${rects.join("\n")}\n</svg>\n`;
}

// ---- run
const sheetItems = [];
for (const id of ROSTER) {
  const src = readPng(path.join(RP, "textures/ui/rxo/kart", `${id}.png`));
  const t = thumb(src);
  writePng(path.join(OUT, `kart_${id}_thumb.png`), t.w, t.h, t.data);
  const geo = JSON.parse(fs.readFileSync(path.join(RP, "models/entity", `${id}.json`), "utf8").replace(/^\uFEFF/, ""))["minecraft:geometry"][0];
  const sil = silhouette(sidePolys(geo));
  fs.writeFileSync(path.join(OUT, `kart_${id}_silhouette.svg`), svg(sil));
  sheetItems.push({ id, t, sil });
  console.log(`${id}: thumb ${src.w}x${src.h} x${t.scale}, silhouette ${sil.on.filter(Boolean).length} px`);
}
// review sheet: per kart a 256 x 192 thumbnail and the silhouette at 4x (96 px) on light and dark cards
const CW = 256 + 16 + 96 + 16 + 96 + 16, CH = 192 + 16, SW = CW, SH = CH * ROSTER.length + 16;
const sheet = Buffer.alloc(SW * SH * 4);
const fill = (x, y, w, h, c) => { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) sheet.set(c, (j * SW + i) * 4); };
fill(0, 0, SW, SH, [240, 242, 238, 255]);
sheetItems.forEach(({ t, sil }, k) => {
  const y = 8 + k * CH;
  for (let j = 0; j < 192; j++) for (let i = 0; i < 256; i++) { const s = ((j * 2) * t.w + i * 2) * 4, a = t.data[s + 3] / 255; const d = ((y + j) * SW + 8 + i) * 4; for (let ch = 0; ch < 3; ch++) sheet[d + ch] = Math.round(t.data[s + ch] * a + sheet[d + ch] * (1 - a)); }
  [[256 + 24, [255, 255, 255, 255], [37, 41, 52, 255]], [256 + 24 + 112, [1, 11, 26, 255], [0, 246, 249, 255]]].forEach(([x, bg, fg]) => {
    fill(x, y + 48, 96, 96, bg);
    for (let py = 0; py < sil.N; py++) for (let px = 0; px < sil.N; px++) if (sil.on[py * sil.N + px]) fill(x + px * 4, y + 48 + py * 4, 4, 4, fg);
  });
});
writePng(path.join(OUT, "_sheet.png"), SW, SH, sheet);
