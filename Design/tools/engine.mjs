// node Design/tools/engine.mjs [<XK ENGINE sounds folder>]     RetireX engine set -> Assets/sfx/
// node Design/tools/engine.mjs --synth                          synthesised stand-in -> Design/audio/engine_synth/
// The engine sounds of decision 20-6, in the PRD format (44.1 kHz, 16 bit, mono .wav). Usage rules:
// Assets/sfx/ENGINE.md. Sources and licence: Assets/sfx/LICENSES.md.
//
// RetireX Online plays the original WAVs of CYBOX's "XK ENGINE" add-on (folder LemonONE_RP) as
// lemon_*.ogg. This reads those original WAVs (lossless; the SHA-256 below are the ones RetireX's
// provenance record lists) instead of the OGG copies:
//   car_on.wav            -> engineIgnition.wav   (RetireX lemon_ignition)
//   car_move_start.wav    -> engineAccel.wav      (lemon_acceleration_start)
//   car_move_going.wav    -> engineLoop.wav       (lemon_engine_going / lemon_engine_loop, cut to a seamless loop)
//   car_move_end.wav      -> engineDecel.wav      (lemon_deceleration)
//   car_engine_waiting.wav-> engineIdle.wav       (not used by RetireX now; optional standstill hum)
// One gain for the whole set puts its loudest peak at -12 dBFS, so the clips keep the levels they
// were made with and the accel -> loop -> decel hand-offs do not jump.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const SR = 44100, PEAK_DB = -12;
const SYNTH = process.argv.includes("--synth");
const SRC = process.argv.slice(2).find((a) => !a.startsWith("--")) ||
  "C:/Users/minsi/AppData/Roaming/Minecraft Bedrock/Users/Shared/games/com.mojang/development_resource_packs/LemonONE_RP/sounds";
const OUT = SYNTH ? path.join(REPO, "Design/audio/engine_synth") : path.join(REPO, "Assets/sfx");
fs.mkdirSync(OUT, { recursive: true });

const SOURCES = {
  engineIgnition: ["car_on.wav", "9E735AAF055D89ED7E611ED257178E9DCF1676E40CF29C236581B81AB449495A"],
  engineAccel: ["car_move_start.wav", "9F0D88FB5378F2B54B6B2ED74C8A648BC6000C91B074F4C7731EB93CA4FF8F07"],
  engineLoop: ["car_move_going.wav", "51B894229D7E0B74C2A5B0A87A0A0092155D1CB6000803F8F1EA5AF09F30CE75"],
  engineDecel: ["car_move_end.wav", "CBC58D6A4EE9B55E14ED0571A52B921DDE838485EF2FA60FB3DA87AC903D6A25"],
  engineIdle: ["car_engine_waiting.wav", "BB647E966B1BC07F92ED32A6066E6DB52D04D0706B67B10C6105413814D2AB52"],
};

// ---- WAV in/out (16-bit PCM)
function readWavMono(file) {
  const b = fs.readFileSync(file);
  let p = 12, fmt = null, data = null;
  while (p + 8 <= b.length) {
    const id = b.toString("ascii", p, p + 4), len = b.readUInt32LE(p + 4);
    if (id === "fmt ") fmt = { tag: b.readUInt16LE(p + 8), ch: b.readUInt16LE(p + 10), sr: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
    if (id === "data") data = b.subarray(p + 8, p + 8 + len);
    p += 8 + len + (len & 1);
  }
  if (!fmt || fmt.tag !== 1 || fmt.bits !== 16 || fmt.sr !== SR) throw new Error(`${file}: need 16-bit PCM at ${SR} Hz`);
  const n = data.length / 2 / fmt.ch, out = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = 0; for (let c = 0; c < fmt.ch; c++) s += data.readInt16LE((i * fmt.ch + c) * 2); out[i] = s / fmt.ch / 32768; }
  return out;
}
function writeWav(file, x) {
  const data = Buffer.alloc(x.length * 2);
  for (let i = 0; i < x.length; i++) data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(x[i] * 32767))), i * 2);
  const h = Buffer.alloc(44);
  h.write("RIFF", 0); h.writeUInt32LE(36 + data.length, 4); h.write("WAVE", 8); h.write("fmt ", 12); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write("data", 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([h, data]));
}
const peak = (x) => x.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
const db = (v) => 20 * Math.log10(Math.max(v, 1e-12));
const rms = (x, a, b) => { let s = 0; for (let i = a; i < b; i++) s += x[i] * x[i]; return Math.sqrt(s / Math.max(1, b - a)); };

// short fades against clicks at the file edges of one-shots
function edgeFades(x, inSec = 0.003, outSec = 0.02) {
  const y = Float64Array.from(x), fi = Math.round(inSec * SR), fo = Math.round(outSec * SR);
  for (let i = 0; i < fi; i++) y[i] *= i / fi;
  for (let i = 0; i < fo; i++) y[y.length - 1 - i] *= i / fo;
  return y;
}

// Seamless loop of about `len` seconds starting near `start`: the start (within +-150 ms, 5 ms
// steps) and the end (within one 30 Hz period of start + len) go where the waveforms match best,
// then the last `xf` seconds are crossfaded with the audio just before the start, so sample N-1
// runs straight into sample 0.
function makeLoop(x, start, len, xf) {
  const X = Math.round(xf * SR), W = Math.round(0.03 * SR), span = Math.round(SR / 30), L = Math.round(len * SR), LW = Math.round(0.05 * SR);
  const ncc = (i, j) => { let s = 0, p = 0, q = 0; for (let k = 0; k < W; k++) { s += x[i + k] * x[j + k]; p += x[i + k] ** 2; q += x[j + k] ** 2; } return s / Math.sqrt(p * q + 1e-18); };
  const lvl = (i) => db(rms(x, i, i + LW));
  // a start inside a level step would make every pass of the loop pulse: penalise the level change
  // across the start, and between the start and the audio the crossfade leaves (just before e)
  let a = Math.round(start * SR), e = a + L, best = -Infinity, bestMatch = 0;
  for (let s0 = Math.max(X + LW, Math.round((start - 0.15) * SR)); s0 <= Math.round((start + 0.15) * SR); s0 += Math.round(0.005 * SR)) {
    const stepAtStart = Math.abs(lvl(s0) - lvl(s0 - LW));
    for (let c = s0 + L - span; c <= Math.min(x.length - W, s0 + L + span); c++) {
      const m = ncc(s0, c), v = m - 0.25 * (stepAtStart + Math.abs(lvl(c - X - LW) - lvl(s0 - X - LW)));
      if (v > best) { best = v; bestMatch = m; a = s0; e = c; }
    }
  }
  best = bestMatch;
  const N = e - a, y = new Float64Array(N);
  for (let i = 0; i < N; i++) y[i] = x[a + i];
  const linear = best > 0.7; // well-aligned material: linear keeps the level; otherwise equal power
  for (let i = 0; i < X; i++) {
    const t = (i + 0.5) / X, fin = linear ? t : Math.sin(t * Math.PI / 2), fout = linear ? 1 - t : Math.cos(t * Math.PI / 2);
    y[N - X + i] = x[e - X + i] * fout + x[a - X + i] * fin;
  }
  return { y, match: best, crossfade: linear ? "linear" : "equal-power", from: a / SR, to: e / SR, xf };
}
// how the wrap point N-1 -> 0 sounds: the jump against a typical step, and the level either side
function seamReport(y) {
  const N = y.length, steps = []; for (let i = 1; i < N; i++) steps.push(Math.abs(y[i] - y[i - 1]));
  steps.sort((p, q) => p - q);
  const typical = steps[Math.floor(steps.length * 0.99)], jump = Math.abs(y[0] - y[N - 1]), W = Math.round(0.05 * SR);
  // the level change across the wrap, ranked among the changes between neighbouring 50 ms
  // windows (hop 10 ms) inside the loop: the engine's own flutter is the yardstick
  const H = Math.round(0.01 * SR), deltas = [];
  for (let i = 0; i + 2 * W <= N; i += H) deltas.push(Math.abs(db(rms(y, i + W, i + 2 * W)) - db(rms(y, i, i + W))));
  const wrap = Math.abs(db(rms(y, 0, W)) - db(rms(y, N - W, N))), rank = deltas.filter((d) => d < wrap).length / deltas.length;
  return `wrap step ${(jump / typical).toFixed(2)}x of the 99th-percentile step, level change ${wrap.toFixed(1)} dB (${Math.round(rank * 100)}th percentile of the loop's own 50 ms changes)`;
}

// ---- synthesised stand-in: a small single-cylinder engine, firing frequency f0(t) in Hz
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32) * 2 - 1; }
function engineVoice(dur, f0, amp, seed = 1) {
  const n = Math.round(dur * SR), y = new Float64Array(n), r = rng(seed);
  let ph = 0, lp1 = 0, lp2 = 0, nz = 0, jit = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    jit += (r() * 0.002 - jit * 0.0005);                       // slow wander of the revs
    ph += f0(t) * (1 + jit) / SR;
    const frac = ph % 1, cyc = Math.floor(ph);
    const kick = Math.exp(-frac * 9) * (cyc % 2 ? 0.8 : 1);    // one firing pulse per cycle, alternate strokes
    nz = 0.97 * nz + 0.03 * r();                              // dark noise rides on each firing
    let s = kick * (0.8 + 2.5 * nz) + 0.35 * Math.sin(2 * Math.PI * ph) + 0.18 * Math.sin(Math.PI * ph);
    s = Math.tanh(1.6 * s);
    lp1 += 0.18 * (s - lp1); lp2 += 0.18 * (lp1 - lp2);      // two one-pole low-passes: no sharp highs
    y[i] = lp2 * amp(t);
  }
  let m = 0; for (let i = 0; i < n; i++) m += y[i] / n; for (let i = 0; i < n; i++) y[i] -= m; // DC
  return y;
}
const ramp = (a, b, d) => (t) => a + (b - a) * Math.min(1, t / d);
function synthSet() {
  const LOOP_F = 55, IDLE_F = 24;
  const starter = (() => { const n = Math.round(0.7 * SR), y = new Float64Array(n), r = rng(9); let ph = 0;
    for (let i = 0; i < n; i++) { const t = i / SR; ph += (190 + 60 * t) / SR; y[i] = (Math.sign(Math.sin(2 * Math.PI * ph)) * 0.25 + 0.1 * r()) * (0.6 + 0.4 * Math.sin(2 * Math.PI * 9 * t)) * Math.min(1, t / 0.03); }
    let lp = 0; for (let i = 0; i < n; i++) { lp += 0.12 * (y[i] - lp); y[i] = lp; } return y; })();
  const run = engineVoice(1.9, (t) => (t < 0.25 ? 18 + 60 * t : IDLE_F + 8 * Math.exp(-(t - 0.25) * 3)), (t) => (t < 0.25 ? t / 0.25 : 0.75) * Math.min(1, (1.9 - t) / 0.5), 3);
  const ign = new Float64Array(Math.round(2.55 * SR));
  ign.set(starter.map((v, i) => v * Math.min(1, (starter.length - i) / (0.08 * SR))), 0);
  run.forEach((v, i) => { const k = Math.round(0.6 * SR) + i; if (k < ign.length) ign[k] += v; });
  const accel = engineVoice(2.73, (t) => IDLE_F + (LOOP_F - IDLE_F) * (1 - Math.exp(-t * 1.4)) / (1 - Math.exp(-2.73 * 1.4)), (t) => 0.35 + 0.65 * Math.min(1, t / 1.2), 4);
  const loopSrc = engineVoice(4.5, () => LOOP_F, () => 1, 5);
  const decel = engineVoice(2.54, (t) => 18 + (LOOP_F - 18) * Math.exp(-t * 1.3), (t) => Math.exp(-t * 1.4), 6);
  const idleSrc = engineVoice(2.0, () => IDLE_F, () => 0.45, 7);
  return { engineIgnition: ign, engineAccel: accel, engineLoop: makeLoop(loopSrc, 1.0, 3.0, 0.1), engineDecel: decel, engineIdle: makeLoop(idleSrc, 0.5, 1.0, 0.08) };
}

// ---- --preview: one 25 s listening file that strings the clips together by the rules of
// Assets/sfx/ENGINE.md 3-3 (pitch 0.70 + 0.30 r, loop gain -6 dB x (1 - r), accel hand-off at
// 2.6 clip-seconds): ignition, idle, full throttle, cruise, release, idle, half throttle, release.
if (process.argv.includes("--preview")) {
  const dir = SYNTH ? OUT : path.join(REPO, "Assets/sfx");
  const clip = Object.fromEntries(["engineIgnition", "engineIdle", "engineAccel", "engineLoop", "engineDecel"].map((n) => [n, readWavMono(path.join(dir, `${n}.wav`))]));
  const mix = new Float64Array(Math.round(25 * SR));
  // add `name` from `t0` for `dur` s at playback `rate` and `gainDb`, fading in/out; loops wrap
  const add = (name, t0, dur, rate, gainDb, fin = 0.01, fout = 0.02, loop = false) => {
    const x = clip[name], g = Math.pow(10, gainDb / 20), n = Math.round(dur * SR), s0 = Math.round(t0 * SR);
    for (let i = 0; i < n && s0 + i < mix.length; i++) {
      let p = i * rate; if (!loop && p >= x.length - 1) break; p %= x.length;
      const k = Math.floor(p), v = x[k] + (x[(k + 1) % x.length] - x[k]) * (p - k);
      const env = Math.min(1, i / Math.max(1, fin * SR), (n - i) / Math.max(1, fout * SR));
      mix[s0 + i] += v * g * env;
    }
  };
  const rate = (r) => 0.7 + 0.3 * r, gain = (r) => -6 * (1 - r), one = (n) => clip[n].length / SR;
  add("engineIgnition", 0, one("engineIgnition"), 1, 0, 0.001);
  add("engineIdle", 2.2, 1.9, 1, 0, 0.3, 0.3, true);                        // countdown hum
  add("engineAccel", 4.0, one("engineAccel"), rate(1), 0);                  // forwardFull
  add("engineLoop", 4.0 + 2.6, 4.0, rate(1), gain(1), 0.13, 0.08, true);    // cruise
  add("engineDecel", 10.6, one("engineDecel"), rate(1), gain(1), 0.02);     // release (stopped)
  add("engineIdle", 12.8, 1.9, 1, 0, 0.3, 0.3, true);
  const h = 14.6 + 2.6 / rate(0.5);
  add("engineAccel", 14.6, one("engineAccel") / rate(0.5), rate(0.5), gain(0.5));   // forwardHalf
  add("engineLoop", h, 3.0, rate(0.5), gain(0.5), 0.13, 0.08, true);
  add("engineDecel", h + 3.0, one("engineDecel") / rate(0.5), rate(0.5), gain(0.5), 0.02);
  add("engineIdle", h + 3.0 + 2.2 / rate(0.5), 25 - (h + 3.0 + 2.2 / rate(0.5)), 1, 0, 0.3, 0.5, true);
  const file = SYNTH ? path.join(OUT, "_preview.wav") : path.join(REPO, "Design/audio/engine_preview.wav");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  writeWav(file, mix);
  console.log(`preview ${path.relative(REPO, file)}: 25 s, peak ${db(peak(mix)).toFixed(1)} dBFS (0 ignition, 2.2 idle, 4.0 full, 6.6 cruise, 10.6 release, 12.8 idle, 14.6 half, ${h.toFixed(2)} cruise, ${(h + 3).toFixed(2)} release)`);
  process.exit(0);
}

// ---- build
let set;
if (SYNTH) set = synthSet();
else {
  const raw = {};
  for (const [name, [file, sha]] of Object.entries(SOURCES)) {
    const f = path.join(SRC, file), got = crypto.createHash("sha256").update(fs.readFileSync(f)).digest("hex").toUpperCase();
    if (got !== sha) throw new Error(`${file}: SHA-256 ${got} is not the recorded source ${sha}`);
    raw[name] = readWavMono(f);
  }
  // going is steady from 0.5 s to 5.5 s; RetireX's old loop used 2.0-3.1 s (1 s, heard as artificial),
  // so take 3 s from 1.5 s. waiting is one even hum: drop its first 0.1 s and loop the rest.
  set = { engineIgnition: raw.engineIgnition, engineAccel: raw.engineAccel, engineLoop: makeLoop(raw.engineLoop, 1.5, 3.0, 0.1), engineDecel: raw.engineDecel, engineIdle: makeLoop(raw.engineIdle, 0.12, 0.85, 0.08) };
}
const loops = new Set(["engineLoop", "engineIdle"]);
const clips = Object.fromEntries(Object.entries(set).map(([k, v]) => [k, loops.has(k) ? v : { y: edgeFades(v) }]));
// the stand-in keeps the original set's balance (RMS against the loop, measured on the XK ENGINE
// files), so swapping it in changes the sound, not the mix
const XK_LEVEL_VS_LOOP = { engineIgnition: -8.8, engineAccel: -3.6, engineDecel: -6.5, engineIdle: -14.5 };
if (SYNTH) {
  const loopRms = rms(clips.engineLoop.y, 0, clips.engineLoop.y.length);
  for (const [name, want] of Object.entries(XK_LEVEL_VS_LOOP)) {
    const c = clips[name], k = Math.pow(10, (want - db(rms(c.y, 0, c.y.length) / loopRms)) / 20);
    c.y = c.y.map((v) => v * k);
  }
}
const gain = Math.pow(10, PEAK_DB / 20) / Math.max(...Object.values(clips).map((c) => peak(c.y)));
console.log(`${SYNTH ? "synth" : "XK ENGINE"} set, common gain ${db(gain).toFixed(1)} dB -> ${path.relative(REPO, OUT)}`);
for (const [name, c] of Object.entries(clips)) {
  const y = c.y.map((v) => v * gain);
  writeWav(path.join(OUT, `${name}.wav`), y);
  console.log(`${name.padEnd(15)} ${(y.length / SR).toFixed(3)} s  peak ${db(peak(y)).toFixed(1)} dBFS  rms ${db(rms(y, 0, y.length)).toFixed(1)} dB` +
    (loops.has(name) ? `
${" ".repeat(17)}loop = source ${c.from.toFixed(4)}-${c.to.toFixed(4)} s, last ${c.xf} s crossfaded (${c.crossfade}) with ${(c.from - c.xf).toFixed(4)}-${c.from.toFixed(4)} s; match ${c.match.toFixed(3)}
${" ".repeat(17)}${seamReport(y)}` : ""));
}
