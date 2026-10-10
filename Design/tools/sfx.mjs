// node Design/tools/sfx.mjs
// The seven race sounds of design PRD 10 (Assets/sfx/<RaceEvent>.wav: 44.1 kHz, 16 bit, mono, peak
// -12 dBFS, chiptune, no sharp highs), synthesised from scratch: no samples, no third-party
// material, so the team owns them outright (Assets/sfx/LICENSES.md). Re-run to regenerate.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const OUT = path.join(REPO, "Assets/sfx");
fs.mkdirSync(OUT, { recursive: true });
const SR = 44100, PEAK = Math.pow(10, -12 / 20); // -12 dBFS
const NOTE = (n) => 440 * Math.pow(2, (n - 69) / 12); // MIDI note -> Hz

// oscillators: pulse with duty, triangle; a gentle one-pole low-pass keeps the highs soft
const pulse = (ph, duty = 0.5) => (ph % 1 < duty ? 1 : -1);
const tri = (ph) => 4 * Math.abs((ph % 1) - 0.5) - 1;
function render(dur, voices, { lp = 0.25, noise = null } = {}) {
  const n = Math.round(dur * SR), out = new Float64Array(n);
  for (const v of voices) {
    let ph = 0;
    const s0 = Math.round(v.t * SR), len = Math.round(v.d * SR);
    for (let i = 0; i < len && s0 + i < n; i++) {
      const t = i / SR, f = v.f * (v.bend ? Math.pow(2, v.bend * t / v.d) : 1);
      ph += f / SR;
      const a = Math.min(1, t / (v.attack ?? 0.004)) * Math.exp(-t * (v.decay ?? 6)) * (i > len - 220 ? (len - i) / 220 : 1);
      out[s0 + i] += a * (v.wave === "tri" ? tri(ph) : pulse(ph, v.duty ?? 0.5)) * (v.gain ?? 1);
    }
  }
  if (noise) { let seed = 7; for (let i = 0; i < Math.round(noise.d * SR) && i < n; i++) { seed = (seed * 1103515245 + 12345) & 0x7fffffff; out[i] += (seed / 0x7fffffff * 2 - 1) * noise.gain * Math.exp(-i / SR * noise.decay); } }
  // low-pass + DC removal, then normalise to the peak
  let y = 0, prevX = 0, prevY = 0;
  for (let i = 0; i < n; i++) { y += lp * (out[i] - y); const hp = y - prevX + 0.995 * prevY; prevX = y; prevY = hp; out[i] = hp; }
  const max = Math.max(...out.map(Math.abs)) || 1;
  return out.map((x) => x / max * PEAK);
}
function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((x, i) => data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(x * 32767))), i * 2));
  const h = Buffer.alloc(44);
  h.write("RIFF", 0); h.writeUInt32LE(36 + data.length, 4); h.write("WAVE", 8); h.write("fmt ", 12); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write("data", 36); h.writeUInt32LE(data.length, 40);
  return Buffer.concat([h, data]);
}
const SOUNDS = {
  // a short electronic "beep", the same for 3, 2, 1
  countdownTick: render(0.15, [{ t: 0, d: 0.15, f: NOTE(81), duty: 0.5, decay: 14 }]),
  // two notes going up
  go: render(0.4, [{ t: 0, d: 0.16, f: NOTE(81), duty: 0.25, decay: 4 }, { t: 0.16, d: 0.24, f: NOTE(88), duty: 0.25, decay: 5 }]),
  // one clear "ding"
  checkpoint: render(0.3, [{ t: 0, d: 0.3, f: NOTE(88), wave: "tri", decay: 9 }, { t: 0, d: 0.3, f: NOTE(100), wave: "tri", decay: 14, gain: 0.25 }], { lp: 0.35 }),
  // a short rising arpeggio of three
  lapComplete: render(0.5, [76, 80, 83].map((m, i) => ({ t: i * 0.11, d: i === 2 ? 0.28 : 0.11, f: NOTE(m), duty: 0.5, decay: i === 2 ? 5 : 3 }))),
  // a five-note fanfare
  finish: render(1.2, [[72, 0, 0.12], [76, 0.12, 0.12], [79, 0.24, 0.12], [84, 0.36, 0.24], [79, 0.6, 0.1], [84, 0.7, 0.5]].map(([m, t, d], i) => ({ t, d, f: NOTE(m), duty: i === 5 ? 0.5 : 0.25, decay: i === 5 ? 2.5 : 3 })).concat([{ t: 0.7, d: 0.5, f: NOTE(72), wave: "tri", decay: 2.5, gain: 0.6 }])),
  // a dull wooden "thud"
  wallBump: render(0.2, [{ t: 0, d: 0.2, f: 140, wave: "tri", decay: 18, bend: -1 }], { lp: 0.08, noise: { d: 0.05, gain: 0.5, decay: 60 } }),
  // two notes going down
  respawn: render(0.4, [{ t: 0, d: 0.16, f: NOTE(84), duty: 0.25, decay: 4 }, { t: 0.16, d: 0.24, f: NOTE(77), duty: 0.25, decay: 6 }]),
};
for (const [name, s] of Object.entries(SOUNDS)) fs.writeFileSync(path.join(OUT, `${name}.wav`), wav(s));
console.log(Object.entries(SOUNDS).map(([n, s]) => `${n} ${(s.length / SR).toFixed(2)} s peak ${(20 * Math.log10(Math.max(...s.map(Math.abs)))).toFixed(1)} dBFS`).join("\n"));
