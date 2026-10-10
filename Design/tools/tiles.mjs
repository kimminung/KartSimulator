// node Design/tools/tiles.mjs
// Track tiles of design PRD 5 (straight, curve, start, grass) from code, so every seam is exact:
//   Assets/blockbench/tiles/tile_<type>.bbmodel  (Blockbench "Generic Model", 16 units = 1 m)
//   Assets/blockbench/tiles/tiles.png            (128 x 128 shared palette texture, no alpha)
//   Assets/export/glb/tile_<type>.glb            (binary glTF, metres, texture embedded, NEAREST)
//   Design/reference/tiles_preview.png           (2 x 2 loop of curves: the seams)
//   Design/reference/tiles_preview_track01.png   (Tracks/track_01.json laid with these tiles)
// No dependencies (own PNG writer and rasteriser). Re-run after changing a number below.
//
// Section (units, from the tile centre line out): road +-24 (edge line in its outer 1 unit; the
// surface in two dark tones, 8 units each along the road, as RetireX lays its roads), curb 24..28
// (height 1), wall 28..30 (height 8, rails with a yellow post every 8), grass margin 30..32. Base 64 x 64 x 2 under everything. The road surface is
// 2 thick on the base, so it stands 2 above the grass, the curb 3, the wall 8.
// Rotation follows Tracks/tools/gen_track.py: rot turns the openings clockwise seen from above
// (N -> E -> S -> W), N = -Z, curve rot 0 opens S and E.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const BB = path.join(REPO, "Assets/blockbench/tiles"), GLB = path.join(REPO, "Assets/export/glb"), REF = path.join(REPO, "Design/reference");
for (const d of [BB, GLB, REF]) fs.mkdirSync(d, { recursive: true });

// ---- palette (Design/style-guide.md 1-1, RetireX track colours) and the texture: 16 px swatches on an 8 x 8 grid
const PAL = { grass: "#546D33", road: "#15151A", "road-alt": "#08090E", "edge-line": "#F9C628", curb: "#6C6D67", rail: "#A5A6AB", "lane-line": "#EAECED" };
const STRIPE = 8; // units per road tone along the road
const SW = Object.fromEntries(Object.keys(PAL).map((k, i) => [k, { u: (i % 8) * 16, v: Math.floor(i / 8) * 16 }]));
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));

// ---- PNG writer (RGB or RGBA, 8 bit)
function png(w, h, data, channels = 3) {
  const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
  const crc = (b) => { let c = -1; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const raw = Buffer.alloc((w * channels + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * channels + 1)] = 0; data.copy(raw, y * (w * channels + 1) + 1, y * w * channels, (y + 1) * w * channels); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = channels === 4 ? 6 : 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
const tex = Buffer.alloc(128 * 128 * 3, 0);
for (let y = 0; y < 128; y++) for (let x = 0; x < 128; x++) { const c = rgb(PAL.grass); tex.set(c, (y * 128 + x) * 3); }
for (const [k, s] of Object.entries(SW)) { const c = rgb(PAL[k]); for (let y = s.v; y < s.v + 16; y++) for (let x = s.u; x < s.u + 16; x++) tex.set(c, (y * 128 + x) * 3); }
const TEX_PNG = png(128, 128, tex);
fs.writeFileSync(path.join(BB, "tiles.png"), TEX_PNG);

// ---- cubes: { from:[x,y,z], to:[x,y,z], mat, name } in units, tile centre at the origin
const T = 32;
function wallRuns(axisLen) { // posts every 8 (centred on multiples of 8, halves at the edges), rails between
  const runs = [];
  for (let a = -T; a < T;) {
    const k = Math.round(a / 8) * 8;
    const inPost = a >= k - 1 && a < k + 1;
    const end = inPost ? Math.min(T, k + 1) : Math.min(T, (Math.floor((a + 1) / 8) + 1) * 8 - 1);
    runs.push({ a0: a, a1: end, post: inPost });
    a = end;
  }
  return runs;
}
function straightCubes(withStart) {
  const c = [{ name: "base", from: [-T, 0, -T], to: [T, 2, T], mat: "grass" }];
  const zSpans = withStart ? [[-T, -2], [2, T]] : [[-T, T]];
  for (const [z0, z1] of zSpans) {
    for (let z = z0; z < z1;) {
      const k = Math.floor((z + T) / STRIPE), z2 = Math.min(z1, -T + (k + 1) * STRIPE);
      c.push({ name: `road_${k}`, from: [-23, 2, z], to: [23, 4, z2], mat: k % 2 ? "road-alt" : "road" });
      z = z2;
    }
    c.push({ name: "line_l", from: [-24, 2, z0], to: [-23, 4, z1], mat: "edge-line" }, { name: "line_r", from: [23, 2, z0], to: [24, 4, z1], mat: "edge-line" });
  }
  if (withStart) for (let i = 0; i < 24; i++) for (let j = 0; j < 2; j++) {
    c.push({ name: `checker_${i}_${j}`, from: [-24 + i * 2, 2, -2 + j * 2], to: [-22 + i * 2, 4, j * 2], mat: (i + j) % 2 ? "road-alt" : "lane-line" });
  }
  c.push({ name: "curb_l", from: [-28, 2, -T], to: [-24, 5, T], mat: "curb" }, { name: "curb_r", from: [24, 2, -T], to: [28, 5, T], mat: "curb" });
  for (const r of wallRuns()) for (const [x0, x1, side] of [[-30, -28, "l"], [28, 30, "r"]]) {
    c.push({ name: `wall_${side}_${r.post ? "post" : "rail"}`, from: [x0, 2, r.a0], to: [x1, r.post ? 10 : 9, r.a1], mat: r.post ? "edge-line" : "rail" });
  }
  return c;
}
function curveCubes() {
  // rot 0: openings S (+z) and E (+x); arc centre at the SE corner (32, 32), centre line radius 32
  const C = [T, T];
  const cells = new Map(); // "x,z" -> { mat, top }
  for (let x = -T; x < T; x++) for (let z = -T; z < T; z++) {
    const r = Math.hypot(x + 0.5 - C[0], z + 0.5 - C[1]);
    const theta = Math.atan2(C[1] - (z + 0.5), C[0] - (x + 0.5)); // 0 along the south edge side .. pi/2 along the east edge side
    let cell = null;
    // road tones by angle: 6 bands, about STRIPE long on the centre line (pi/2 * 32 / 6 = 8.4)
    if (r >= 9 && r < 55) cell = { mat: Math.min(5, Math.floor(theta / (Math.PI / 2) * 6)) % 2 ? "road-alt" : "road", top: 4 };
    else if ((r >= 8 && r < 9) || (r >= 55 && r < 56)) cell = { mat: "edge-line", top: 4 };
    else if ((r >= 4 && r < 8) || (r >= 56 && r < 60)) cell = { mat: "curb", top: 5 };
    // outer wall: an L along the NW corner, outside the outer curb
    const onWallX = x >= -30 && x < -28 && z >= -30, onWallZ = z >= -30 && z < -28 && x >= -30;
    if (!cell && r >= 60 && (onWallX || onWallZ)) {
      const along = onWallX && !onWallZ ? z : x;
      const k = Math.round(along / 8) * 8;
      const post = along >= k - 1 && along < k + 1 || (onWallX && onWallZ);
      cell = { mat: post ? "edge-line" : "rail", top: post ? 10 : 9, wall: true };
    }
    if (cell) cells.set(x + "," + z, cell);
  }
  // merge cells into boxes: runs along x per row, then equal runs down the rows
  const key = (c) => c.mat + "/" + c.top;
  const runs = [];
  for (let z = -T; z < T; z++) {
    for (let x = -T; x < T;) {
      const c = cells.get(x + "," + z);
      if (!c) { x++; continue; }
      let x1 = x + 1;
      while (x1 < T && cells.get(x1 + "," + z) && key(cells.get(x1 + "," + z)) === key(c)) x1++;
      runs.push({ x0: x, x1, z0: z, z1: z + 1, c });
      x = x1;
    }
  }
  const merged = [];
  for (const r of runs) {
    const prev = merged.find((m) => m.x0 === r.x0 && m.x1 === r.x1 && m.z1 === r.z0 && key(m.c) === key(r.c));
    if (prev) prev.z1 = r.z1; else merged.push({ ...r });
  }
  const out = [{ name: "base", from: [-T, 0, -T], to: [T, 2, T], mat: "grass" }];
  for (const m of merged) out.push({ name: m.c.wall ? "wall" : m.c.mat.startsWith("road") ? "road" : m.c.top === 5 ? "curb" : "line", from: [m.x0, 2, m.z0], to: [m.x1, m.c.top, m.z1], mat: m.c.mat });
  return out;
}
const TILES = { straight: straightCubes(false), start: straightCubes(true), curve: curveCubes(), grass: [{ name: "base", from: [-T, 0, -T], to: [T, 2, T], mat: "grass" }] };

// ---- Blockbench project
const uid = () => crypto.randomUUID();
const swatchUV = (mat) => { const s = SW[mat]; return [s.u + 4, s.v + 4, s.u + 12, s.v + 12]; };
function bbmodel(type, cubes) {
  const elements = cubes.map((c) => {
    const uv = swatchUV(c.mat);
    const faces = Object.fromEntries(["north", "east", "south", "west", "up", "down"].map((f) => [f, { uv, texture: 0 }]));
    return { name: c.name, box_uv: false, rescale: false, locked: false, render_order: "default", allow_mirror_modeling: true, from: c.from, to: c.to, autouv: 0, color: 0, origin: [0, 0, 0], faces, type: "cube", uuid: uid() };
  });
  return {
    meta: { format_version: "4.10", model_format: "free", box_uv: false },
    name: "tile_" + type, model_identifier: "", visible_box: [1, 1, 0], variable_placeholders: "", variable_placeholder_buttons: [], timeline_setups: [], unhandled_root_fields: {},
    resolution: { width: 128, height: 128 },
    elements,
    outliner: [{ name: "tile_" + type, origin: [0, 0, 0], color: 0, uuid: uid(), export: true, mirror_uv: false, isOpen: true, locked: false, visibility: true, autouv: 0, children: elements.map((e) => e.uuid) }],
    textures: [{ path: "", name: "tiles.png", folder: "", namespace: "", id: "0", width: 128, height: 128, uv_width: 128, uv_height: 128, particle: false, use_as_default: false, layers_enabled: false, sync_to_project: "", render_mode: "default", render_sides: "auto", frame_time: 1, frame_order_type: "loop", frame_order: "", frame_interpolate: false, visible: true, internal: true, saved: true, uuid: uid(), relative_path: "tiles.png", source: "data:image/png;base64," + TEX_PNG.toString("base64") }],
  };
}

// ---- binary glTF (metres)
const FACES = [ // [normal, 4 corners as (x?from:to) picks]
  [[0, 0, -1], [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]]], [[0, 0, 1], [[1, 0, 1], [1, 1, 1], [0, 1, 1], [0, 0, 1]]],
  [[-1, 0, 0], [[0, 0, 1], [0, 1, 1], [0, 1, 0], [0, 0, 0]]], [[1, 0, 0], [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]]],
  [[0, 1, 0], [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]]], [[0, -1, 0], [[0, 0, 1], [0, 0, 0], [1, 0, 0], [1, 0, 1]]],
];
function glb(type, cubes) {
  const pos = [], nor = [], uv = [], idx = [];
  for (const c of cubes) {
    const [u0, v0, u1, v1] = swatchUV(c.mat).map((v) => v / 128);
    for (const [n, corners] of FACES) {
      const base = pos.length / 3;
      corners.forEach(([ix, iy, iz], k) => {
        pos.push((ix ? c.to[0] : c.from[0]) / 16, (iy ? c.to[1] : c.from[1]) / 16, (iz ? c.to[2] : c.from[2]) / 16);
        nor.push(...n);
        uv.push(k === 0 || k === 1 ? u0 : u1, k === 1 || k === 2 ? v0 : v1);
      });
      idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
  }
  const f32 = (a) => Buffer.from(new Float32Array(a).buffer), u32 = Buffer.from(new Uint32Array(idx).buffer);
  const parts = [f32(pos), f32(nor), f32(uv), u32, TEX_PNG];
  const views = [], offsets = [];
  let off = 0;
  const bin = [];
  for (const p of parts) { const pad = (4 - (p.length % 4)) % 4; offsets.push(off); bin.push(p, Buffer.alloc(pad)); views.push({ buffer: 0, byteOffset: off, byteLength: p.length }); off += p.length + pad; }
  views[0].target = views[1].target = views[2].target = 34962; views[3].target = 34963;
  const mins = [0, 1, 2].map((a) => Math.min(...pos.filter((_, i) => i % 3 === a))), maxs = [0, 1, 2].map((a) => Math.max(...pos.filter((_, i) => i % 3 === a)));
  const json = {
    asset: { version: "2.0", generator: "Design/tools/tiles.mjs" }, scene: 0, scenes: [{ nodes: [0] }],
    nodes: [{ name: "tile_" + type, mesh: 0 }],
    meshes: [{ name: "tile_" + type, primitives: [{ attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2 }, indices: 3, material: 0 }] }],
    materials: [{ name: "tiles", pbrMetallicRoughness: { baseColorTexture: { index: 0 }, metallicFactor: 0, roughnessFactor: 1 } }],
    textures: [{ sampler: 0, source: 0 }], samplers: [{ magFilter: 9728, minFilter: 9728, wrapS: 33071, wrapT: 33071 }],
    images: [{ bufferView: 4, mimeType: "image/png", name: "tiles" }],
    accessors: [
      { bufferView: 0, componentType: 5126, count: pos.length / 3, type: "VEC3", min: mins, max: maxs },
      { bufferView: 1, componentType: 5126, count: nor.length / 3, type: "VEC3" },
      { bufferView: 2, componentType: 5126, count: uv.length / 2, type: "VEC2" },
      { bufferView: 3, componentType: 5125, count: idx.length, type: "SCALAR" },
    ],
    bufferViews: views, buffers: [{ byteLength: off }],
  };
  let js = Buffer.from(JSON.stringify(json));
  js = Buffer.concat([js, Buffer.alloc((4 - (js.length % 4)) % 4, 0x20)]);
  const binBuf = Buffer.concat(bin);
  const header = Buffer.alloc(12); header.writeUInt32LE(0x46546c67, 0); header.writeUInt32LE(2, 4); header.writeUInt32LE(12 + 8 + js.length + 8 + binBuf.length, 8);
  const c0 = Buffer.alloc(8); c0.writeUInt32LE(js.length, 0); c0.writeUInt32LE(0x4e4f534a, 4);
  const c1 = Buffer.alloc(8); c1.writeUInt32LE(binBuf.length, 0); c1.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([header, c0, js, c1, binBuf]);
}

// ---- checks: no overlapping cubes, everything inside the tile, at most 7 colours per tile (style guide 1-1)
function check(type, cubes) {
  for (const c of cubes) for (let a = 0; a < 3; a++) if (c.from[a] >= c.to[a] || (a !== 1 && (c.from[a] < -T || c.to[a] > T))) throw Error(`${type}: bad cube ${c.name}`);
  for (let i = 0; i < cubes.length; i++) for (let j = i + 1; j < cubes.length; j++) {
    const a = cubes[i], b = cubes[j];
    if ([0, 1, 2].every((k) => a.from[k] < b.to[k] && b.from[k] < a.to[k])) throw Error(`${type}: ${a.name} overlaps ${b.name}`);
  }
  const colours = new Set(cubes.map((c) => c.mat));
  if (colours.size > 7) throw Error(`${type}: ${colours.size} colours`);
  return { cubes: cubes.length, colours: [...colours] };
}

// ---- rasteriser for the previews (orthographic, z-buffer, flat shading)
function render(placed, file, { W = 1400, H = 1000, yaw = 45, pitch = 35, pad = 40 } = {}) {
  const cy = Math.cos(yaw * Math.PI / 180), sy = Math.sin(yaw * Math.PI / 180), cp = Math.cos(pitch * Math.PI / 180), sp = Math.sin(pitch * Math.PI / 180);
  const view = ([x, y, z]) => { const xr = x * cy - z * sy, zr = x * sy + z * cy; return [xr, y * cp - zr * sp, y * sp + zr * cp]; };
  const quads = [];
  for (const { cubes, ox, oz, rot } of placed) for (const c of cubes) for (const [n, corners] of FACES) {
    const pts = corners.map(([ix, iy, iz]) => { let x = ix ? c.to[0] : c.from[0], y = iy ? c.to[1] : c.from[1], z = iz ? c.to[2] : c.from[2]; for (let k = 0; k < rot / 90; k++) [x, z] = [-z, x]; return view([x + ox, y, z + oz]); });
    let [nx, ny, nz] = n; for (let k = 0; k < rot / 90; k++) [nx, nz] = [-nz, nx];
    const shade = ny > 0 ? 1 : ny < 0 ? 0.45 : 0.62 + 0.2 * Math.abs(nx * cy - nz * sy);
    quads.push({ pts, col: rgb(PAL[c.mat]).map((v) => Math.min(255, Math.round(v * shade))) });
  }
  const xs = quads.flatMap((q) => q.pts.map((p) => p[0])), ys = quads.flatMap((q) => q.pts.map((p) => p[1]));
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
  const s = Math.min((W - 2 * pad) / (maxX - minX), (H - 2 * pad) / (maxY - minY));
  const img = Buffer.alloc(W * H * 3); const bg = rgb("#20242c");
  for (let i = 0; i < W * H; i++) img.set(bg, i * 3);
  const depth = new Float32Array(W * H).fill(-Infinity);
  const px = (p) => [pad + (p[0] - minX) * s + ((W - 2 * pad) - (maxX - minX) * s) / 2, H - pad - (p[1] - minY) * s - ((H - 2 * pad) - (maxY - minY) * s) / 2, p[2]];
  for (const q of quads) {
    const P = q.pts.map(px);
    for (const tri of [[P[0], P[1], P[2]], [P[0], P[2], P[3]]]) {
      const [a, b, c] = tri;
      const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]))), x1 = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
      const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]))), y1 = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
      const area = (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1]);
      if (Math.abs(area) < 1e-9) continue;
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
        const w0 = ((b[0] - x - 0.5) * (c[1] - y - 0.5) - (c[0] - x - 0.5) * (b[1] - y - 0.5)) / area;
        const w1 = ((c[0] - x - 0.5) * (a[1] - y - 0.5) - (a[0] - x - 0.5) * (c[1] - y - 0.5)) / area;
        const w2 = 1 - w0 - w1;
        if (w0 < -1e-6 || w1 < -1e-6 || w2 < -1e-6) continue;
        const d = w0 * a[2] + w1 * b[2] + w2 * c[2];
        const i = y * W + x;
        if (d <= depth[i]) continue;
        depth[i] = d; img.set(q.col, i * 3);
      }
    }
  }
  fs.writeFileSync(file, png(W, H, img));
}

const report = {};
for (const [type, cubes] of Object.entries(TILES)) {
  report[type] = check(type, cubes);
  fs.writeFileSync(path.join(BB, `tile_${type}.bbmodel`), JSON.stringify(bbmodel(type, cubes)));
  fs.writeFileSync(path.join(GLB, `tile_${type}.glb`), glb(type, cubes));
}
// 2 x 2 loop of curves: openings S+E (rot 0) top-left, W+S (90) top-right, N+W (180) bottom-right, E+N (270) bottom-left
const at = (col, row) => ({ ox: col * 64 + 32, oz: -(row * 64 + 32) });
render([{ cubes: TILES.curve, rot: 0, ...at(0, 1) }, { cubes: TILES.curve, rot: 90, ...at(1, 1) }, { cubes: TILES.curve, rot: 180, ...at(1, 0) }, { cubes: TILES.curve, rot: 270, ...at(0, 0) }], path.join(REF, "tiles_preview.png"));
// the tech side's track_01.json, empty cells filled with grass tiles
const trackFile = path.join(REPO, "Tracks/track_01.json");
if (fs.existsSync(trackFile)) {
  const tr = JSON.parse(fs.readFileSync(trackFile, "utf8"));
  const used = new Set(tr.tiles.map((t) => t.col + "," + t.row));
  const placed = tr.tiles.map((t) => ({ cubes: TILES[t.type], rot: t.rot, ...at(t.col, t.row) }));
  for (let c = 0; c < tr.grid.cols; c++) for (let r = 0; r < tr.grid.rows; r++) if (!used.has(c + "," + r)) placed.push({ cubes: TILES.grass, rot: 0, ...at(c, r) });
  render(placed, path.join(REF, "tiles_preview_track01.png"), { W: 1600, H: 1100 });
}
console.log(JSON.stringify(report));
